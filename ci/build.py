import hashlib
import json
import os
import re
import shutil
import tarfile
import urllib.request
import uuid
from pathlib import Path
from common import aws_json, env, identity, run, scan, validate_release
import security_gate as gate
from security_contract import verify_security


def download(url):
    import http.client
    import time
    import urllib.error

    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                return response.read()
        except (http.client.IncompleteRead, urllib.error.URLError,
                TimeoutError, ConnectionError) as error:
            if attempt == 2:
                raise
            print(
                f'Download interrupted ({type(error).__name__}); '
                f'retrying attempt {attempt + 2}/3.',
                flush=True
            )
            time.sleep(5 * (attempt + 1))


def tools():
    dest = Path('release-artifact/tools'); dest.mkdir(parents=True, exist_ok=True)
    helm_version, kubectl_version = env('HELM_VERSION'), env('KUBECTL_VERSION')
    if not re.fullmatch(r'v3\.\d+\.\d+', helm_version) or not re.fullmatch(r'v1\.\d+\.\d+', kubectl_version):
        raise RuntimeError('Invalid pinned tool versions')
    for tool, url in [
        ('helm', f'https://get.helm.sh/helm-{helm_version}-linux-amd64.tar.gz'),
        ('kubectl', f'https://dl.k8s.io/release/{kubectl_version}/bin/linux/amd64/kubectl')]:
        blob = download(url)
        checksum_url = url + ('.sha256sum' if tool == 'helm' else '.sha256')
        expected = download(checksum_url).decode().split()[0]
        if hashlib.sha256(blob).hexdigest() != expected:
            raise RuntimeError(f'{tool} upstream checksum mismatch')
        if tool == 'helm':
            import io
            with tarfile.open(fileobj=io.BytesIO(blob), mode='r:gz') as archive:
                blob = archive.extractfile('linux-amd64/helm').read()
        path = dest / tool; path.write_bytes(blob); path.chmod(0o755)
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in dest.iterdir()}


def source_check():
    for p in Path('.').rglob('*'):
        if not p.is_file():
            continue
        if p.name == '.env' or (p.name.startswith('.env.') and p.name != '.env.example') or p.name in ('terraform.tfvars', 'backend.hcl') or p.suffix in ('.tfstate', '.tfplan', '.tfvars') or p.name.endswith(('.tfstate.backup', '.tfvars.json')) or '.terraform' in p.parts:
            raise RuntimeError(f'Private/generated source path found: {p}; remove it from Git before CI')
        if any(re.fullmatch(r'\.phase\d+', x) for x in p.parts) and p.name != '.gitignore':
            raise RuntimeError('Runtime phase files must not be in the source artifact')


def main():
    identity(); source_check()
    commit = env('GIT_COMMIT')
    if not re.fullmatch(r'[a-f0-9]{40}', commit):
        raise RuntimeError('Expected source action full Git commit SHA')
    for app in ('backend', 'frontend'):
        repo = env(app.upper() + '_REPOSITORY')
        prefix = f"{env('EXPECTED_ACCOUNT')}.dkr.ecr.{env('AWS_REGION')}.amazonaws.com/"
        if not repo.startswith(prefix) or not re.fullmatch(r'[a-z0-9/_-]+', repo[len(prefix):]):
            raise RuntimeError('Repository account/region/name mismatch before any image push')
    root = Path('release-artifact')
    if root.exists():
        raise RuntimeError('Fresh build workspace required; artifact directory already exists')
    gate.REPORTS.mkdir(parents=True)
    pins = gate.install_tools()
    accepted = gate.exceptions()
    gate.secret_scan(accepted)
    gate.dependency_scan(accepted)
    for app in ('backend', 'frontend'):
        if not (Path(app) / 'package-lock.json').is_file() or not (Path(app) / 'Dockerfile').is_file():
            raise RuntimeError(f'{app} requires reviewed package-lock.json and Dockerfile')
        run(['npm', 'ci'], cwd=app)
    run(['npm', 'run', 'lint', '--', '--deny-warnings'], cwd='frontend')
    run(['frontend/node_modules/.bin/oxlint', '--deny-warnings', '--config',
         'security/backend-oxlint.json', 'backend/src', 'backend/tests'])
    tests = {}
    for app in ('backend', 'frontend'):
        package = json.loads((Path(app) / 'package.json').read_text())
        if 'test:ci' in package.get('scripts', {}):
            run(['npm', 'run', 'test:ci'], cwd=app)
            tests[app] = 'Declared test:ci passed; inspect actual test scope'
        else:
            tests[app] = 'NOT RUN: no declared test:ci script; approval must review this gap'
            print(tests[app], flush=True)
    if not any('passed' in result for result in tests.values()):
        raise RuntimeError('At least one meaningful declared test:ci must run')
    run(['npm', 'run', 'build'], cwd='frontend')
    roots = gate.terraform_checks()
    tool_checksums = tools()
    gate.iac_scan(accepted, str(root / 'tools/helm'))
    tag = 'r' + commit[:12] + '-' + uuid.uuid4().hex[:16]
    built = {}
    # Both container gates precede any push. Run serially to limit build memory pressure.
    for app in ('backend', 'frontend'):
        image = env(app.upper() + '_REPOSITORY') + ':' + tag
        run(['docker', 'build', '--pull', '--platform', 'linux/amd64', '--label',
             f'org.opencontainers.image.revision={commit}', '-t', image, app])
        image_id = run(['docker', 'image', 'inspect', '--format', '{{.Id}}', image], capture=True)
        if not re.fullmatch(r'sha256:[a-f0-9]{64}', image_id):
            raise RuntimeError('Unexpected local image ID')
        gate.scan('image-' + app, ['image', '--image-src', 'docker', '--scanners', 'vuln,secret', '--image-config-scanners', 'secret', image],
                  accepted, localImageId=image_id, image=image, imageScope=app)
        built[app] = {'tag': image, 'id': image_id}
    registry = env('BACKEND_REPOSITORY').split('/')[0]
    token = run(['aws', 'ecr', 'get-login-password'], capture=True)
    run(['docker', 'login', '--username', 'AWS', '--password-stdin', registry], capture=True, data=token + '\n')
    del token
    images, ecr_findings = {}, {}
    for app in ('backend', 'frontend'):
        if run(['docker', 'image', 'inspect', '--format', '{{.Id}}', built[app]['tag']], capture=True) != built[app]['id']:
            raise RuntimeError('Local image changed after scan')
        run(['docker', 'push', built[app]['tag']])
        repo = env(app.upper() + '_REPOSITORY')
        detail = aws_json(['ecr', 'describe-images', '--repository-name', repo.split('/', 1)[1],
                           '--image-ids', f'imageTag={tag}'])
        images[app] = repo + '@' + detail['imageDetails'][0]['imageDigest']
        ecr_findings[app] = scan(images[app], wait=True)
        report_path = gate.REPORTS / ('image-' + app + '.json')
        report = json.loads(report_path.read_text())
        report['image'] = images[app]
        report_path.write_text(json.dumps(report, indent=2))
    db_path = gate.RUNTIME / 'trivy-cache/db/metadata.json'
    if not db_path.is_file():
        raise RuntimeError('Trivy vulnerability database metadata missing')
    security = {'schemaVersion': 1, 'status': 'PASSED', 'commit': commit,
                'stages': {
                    **{name: 'PASSED' for name in ('secrets', 'lint', 'tests', 'dependencies', 'images')},
                    'iac': 'PASSED'
                },
                'toolPins': pins, 'database': json.loads(db_path.read_text()),
                'terraformRoots': roots, 'reports': gate.report_manifest(),
                'testStageMeaning': 'Declared tests passed; missing scripts are NOT RUN, not covered'}
    record = {'formatVersion': 1, 'commit': commit, 'releaseTag': tag, 'buildId': env('CODEBUILD_BUILD_ID'),
              'account': env('EXPECTED_ACCOUNT'), 'region': env('AWS_REGION'),
              'backendImage': images['backend'], 'frontendImage': images['frontend'],
              'scanCounts': ecr_findings, 'testCoverage': tests, 'toolChecksums': tool_checksums,
              'security': security}
    validate_release(record)
    verify_security(record, root)
    shutil.copytree('helm/opsflow', root / 'helm/opsflow')
    (root / 'ci').mkdir()
    for file in ('deploy.py', 'common.py', 'security_contract.py', 'buildspec-cd.yml'):
        shutil.copyfile(Path('ci') / file, root / 'ci' / file)
    (root / 'release.json').write_text(json.dumps(record, indent=2))
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
