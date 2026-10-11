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
        if p.name == '.env' or (p.name.startswith('.env.') and p.name != '.env.example') or p.name in ('terraform.tfvars', 'backend.hcl') or p.suffix in ('.tfstate', '.tfplan'):
            raise RuntimeError(f'Private/generated source path found: {p}; remove it from Git before CI')
        if any(x in p.parts for x in ['.phase6', '.phase7', '.phase8', '.phase9']) and p.name != '.gitignore':
            raise RuntimeError('Runtime phase files must not be in the source artifact')


def main():
    identity(); source_check()
    commit = env('GIT_COMMIT')
    if not re.fullmatch(r'[a-f0-9]{40}', commit):
        raise RuntimeError('Expected source action full Git commit SHA')
    for app in ['backend', 'frontend']:
        repo = env(app.upper() + '_REPOSITORY')
        prefix = f"{env('EXPECTED_ACCOUNT')}.dkr.ecr.{env('AWS_REGION')}.amazonaws.com/"
        if not repo.startswith(prefix) or not re.fullmatch(r'[a-z0-9/_-]+', repo[len(prefix):]):
            raise RuntimeError('Repository account/region/name mismatch before any image push')
    tests = {}
    for app in ['backend', 'frontend']:
        path = Path(app); package = json.loads((path / 'package.json').read_text())
        if not (path / 'package-lock.json').is_file() or not (path / 'Dockerfile').is_file():
            raise RuntimeError(f'{app} requires reviewed package-lock.json and Dockerfile')
        run(['npm', 'ci'], cwd=app)
        if 'test:ci' in package.get('scripts', {}):
            run(['npm', 'run', 'test:ci'], cwd=app); tests[app] = 'test:ci passed'
        else:
            tests[app] = 'NOT RUN: no declared test:ci script; approval must review this gap'
            print(tests[app])
        if app == 'frontend':
            run(['npm', 'run', 'build'], cwd=app)
    registry = env('BACKEND_REPOSITORY').split('/')[0]
    token = run(['aws', 'ecr', 'get-login-password'], capture=True)
    # Capture docker response; never put the credential in process arguments/logs.
    run(['docker', 'login', '--username', 'AWS', '--password-stdin', registry], capture=True, data=token + '\n')
    del token
    tag = 'r' + commit[:12] + '-' + uuid.uuid4().hex[:16]
    images, findings = {}, {}
    for app in ['backend', 'frontend']:
        repo = env(app.upper() + '_REPOSITORY')
        run(['docker', 'build', '--pull', '--platform', 'linux/amd64', '--label', f'org.opencontainers.image.revision={commit}', '-t', f'{repo}:{tag}', app])
        run(['docker', 'push', f'{repo}:{tag}'])
        detail = aws_json(['ecr', 'describe-images', '--repository-name', repo.split('/', 1)[1], '--image-ids', f'imageTag={tag}'])
        images[app] = repo + '@' + detail['imageDetails'][0]['imageDigest']
        findings[app] = scan(images[app], wait=True)
    record = {'formatVersion': 1, 'commit': commit, 'releaseTag': tag, 'buildId': env('CODEBUILD_BUILD_ID'),
              'account': env('EXPECTED_ACCOUNT'), 'region': env('AWS_REGION'),
              'backendImage': images['backend'], 'frontendImage': images['frontend'],
              'scanCounts': findings, 'testCoverage': tests, 'toolChecksums': tools()}
    validate_release(record)
    root = Path('release-artifact')
    shutil.copytree('helm/opsflow', root / 'helm/opsflow')
    (root / 'ci').mkdir()
    for file in ['deploy.py', 'common.py', 'buildspec-cd.yml']:
        shutil.copyfile(Path('ci') / file, root / 'ci' / file)
    (root / 'release.json').write_text(json.dumps(record, indent=2))
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
