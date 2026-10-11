"""Serial, fail-closed security gates; never print raw secret scanner matches."""
import datetime as dt
import hashlib
import http.client
import io
import json
import os
import re
import subprocess
import tarfile
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

RUNTIME = Path('.phase12')
REPORTS = Path('release-artifact/security/reports')


def checked(args, *, capture=False, cwd=None):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=capture)
    if result.returncode:
        raise RuntimeError(f'{Path(args[0]).name} failed ({result.returncode}); inspect stage logs')
    return result.stdout.strip() if capture else None


def download(url):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                return response.read()
        except (http.client.IncompleteRead, urllib.error.URLError, TimeoutError, ConnectionError):
            if attempt == 2:
                raise
            print(f'Tool download interrupted; attempt {attempt + 2}/3', flush=True)
            time.sleep(5 * (attempt + 1))


def install_tools():
    pins = json.loads(Path('security/tool-pins.json').read_text())
    dest = RUNTIME / 'bin'
    dest.mkdir(parents=True, exist_ok=True)
    for tool in ('trivy', 'terraform'):
        pin = pins[tool]
        if not re.fullmatch(r'\d+\.\d+\.\d+', pin['version']) or not re.fullmatch(r'[a-f0-9]{64}', pin['sha256']):
            raise RuntimeError('Invalid reviewed tool pin')
        base = (f"https://github.com/aquasecurity/trivy/releases/download/v{pin['version']}/"
                if tool == 'trivy' else f"https://releases.hashicorp.com/terraform/{pin['version']}/")
        archive_name = (f"trivy_{pin['version']}_Linux-64bit.tar.gz" if tool == 'trivy'
                        else f"terraform_{pin['version']}_linux_amd64.zip")
        if pin['archive'] != archive_name:
            raise RuntimeError('Tool archive name mismatch')
        blob = download(base + archive_name)
        if hashlib.sha256(blob).hexdigest() != pin['sha256']:
            raise RuntimeError(f'{tool} checksum mismatch; release blocked')
        if tool == 'trivy':
            with tarfile.open(fileobj=io.BytesIO(blob), mode='r:gz') as archive:
                member = archive.getmember('trivy')
                if not member.isfile():
                    raise RuntimeError('Expected scanner binary')
                binary = archive.extractfile(member).read()
        else:
            with zipfile.ZipFile(io.BytesIO(blob)) as archive:
                binary = archive.read('terraform')
        path = dest / tool
        path.write_bytes(binary)
        path.chmod(0o755)
    (RUNTIME / 'empty-ignore').write_text('')
    (RUNTIME / 'empty-trivy.yaml').write_text('{}\n')
    # Repository or inherited TRIVY_* settings cannot silently disable this gate.
    for key in list(os.environ):
        if key.startswith('TRIVY_'):
            del os.environ[key]
    return pins


def fingerprint(item):
    fields = [item['kind'], item['target'], item['id'], item['subject'], item.get('installedVersion', '')]
    return hashlib.sha256(json.dumps(fields, separators=(',', ':')).encode()).hexdigest()


def exceptions():
    items = json.loads(Path('security/exceptions.json').read_text())
    if not isinstance(items, list):
        raise RuntimeError('Exceptions must be a reviewed list')
    today = dt.datetime.now(dt.timezone.utc).date()
    result = {}
    for entry in items:
        expiration = dt.date.fromisoformat(entry['expires'])
        if expiration < today or expiration > today + dt.timedelta(days=30):
            raise RuntimeError('Exception expired or exceeds 30-day review window')
        fp = entry['fingerprint']
        if not re.fullmatch(r'[a-f0-9]{64}', fp) or fp in result:
            raise RuntimeError('Duplicate/invalid exception fingerprint')
        for key in ('owner', 'reason', 'reviewReference'):
            if not isinstance(entry.get(key), str) or len(entry[key].strip()) < 5:
                raise RuntimeError('Exception owner, reason and review reference required')
        result[fp] = entry
    return result


def findings(document):
    if document.get('SchemaVersion') != 2 or not isinstance(document.get('Results', []), list):
        raise RuntimeError('Unexpected Trivy report schema')
    result = []
    for group in document.get('Results', []):
        target = group.get('Target', '')
        # Preserve safe identifiers; omit Match, Code, CauseMetadata snippets and full source.
        for value in group.get('Secrets', []):
            result.append({'kind': 'secret', 'target': target, 'id': value['RuleID'],
                           'subject': f"lines:{value.get('StartLine', 0)}-{value.get('EndLine', 0)}",
                           'severity': value.get('Severity', 'UNKNOWN')})
        for value in group.get('Vulnerabilities', []):
            result.append({'kind': 'vulnerability', 'target': target, 'id': value['VulnerabilityID'],
                           'subject': value['PkgName'], 'installedVersion': value['InstalledVersion'],
                           'fixedVersion': value.get('FixedVersion', ''), 'severity': value['Severity']})
        for value in group.get('Misconfigurations', []):
            if value.get('Status') != 'FAIL':
                continue
            cause = value.get('CauseMetadata', {})
            resource = cause.get('Resource') or f"lines:{cause.get('StartLine', 0)}-{cause.get('EndLine', 0)}"
            result.append({'kind': 'misconfiguration', 'target': target, 'id': value['ID'],
                           'subject': resource, 'severity': value['Severity']})
    for item in result:
        item['fingerprint'] = fingerprint(item)
    return result


def evaluate(name, document, accepted, **metadata):
    records = findings(document)
    blocking = []
    for item in records:
        severity = item['severity']
        if severity not in ('UNKNOWN', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'):
            raise RuntimeError('Unknown finding severity; review scanner schema')
        hard_block = (
            item['kind'] == 'secret'
            or (
                item['kind'] != 'misconfiguration'
                and severity in ('CRITICAL', 'UNKNOWN')
            )
        )
        entry = accepted.get(item['fingerprint'])
        item['disposition'] = 'INFORMATIONAL'
        if hard_block:
            item['disposition'] = 'BLOCKED'
            blocking.append(item)
        elif severity == 'HIGH' and item['kind'] != 'misconfiguration':
            if entry:
                item['disposition'] = 'ACCEPTED'
                item['exception'] = entry
            else:
                item['disposition'] = 'BLOCKED'
                blocking.append(item)
    summary = {'schemaVersion': 1, 'status': 'FAILED' if blocking else 'PASSED',
               'blockingCount': len(blocking), 'findings': records, **metadata}
    REPORTS.mkdir(parents=True, exist_ok=True)
    (REPORTS / (name + '.json')).write_text(json.dumps(summary, indent=2))
    print(f'{name}: {summary["status"]}; findings={len(records)}, blocked={len(blocking)}', flush=True)
    # Identifiers only: raw secret values and matched lines never enter logs/artifacts.
    for item in blocking:
        print(json.dumps({k: item[k] for k in ('kind', 'target', 'id', 'subject', 'severity', 'fingerprint')}), flush=True)
    if blocking:
        raise RuntimeError(f'{name}: blocking findings; fix or review a specific HIGH exception')
    return summary


def scan(name, arguments, accepted, **metadata):
    raw = RUNTIME / (name + '-raw.json')
    cmd = [str(RUNTIME / 'bin/trivy'), '--config', str(RUNTIME / 'empty-trivy.yaml'),
           '--cache-dir', str(RUNTIME / 'trivy-cache'), *arguments, '--timeout', '10m',
           '--ignorefile', str(RUNTIME / 'empty-ignore'), '--format', 'json', '--output', str(raw)]
    # Findings are evaluated below; nonzero scanner exit is an operational failure, never a pass.
    process = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if process.returncode:
        categories = [word for word in ('database', 'timeout', 'rate limit', 'permission', 'connection', 'memory', 'unsupported')
                      if word in process.stderr.lower()]
        print(f'{name}: scanner failed ({process.returncode}); category={categories or ["unclassified"]}; release blocked', flush=True)
        # Raw scanner errors may include source; keep them only in private build runtime.
        (RUNTIME / (name + '-scanner-error.txt')).write_text(process.stderr)
        raise RuntimeError('Scanner execution/database/network failure; no release')
    if not raw.is_file():
        raise RuntimeError('Scanner produced no report')
    try:
        document = json.loads(raw.read_text())
        if name == 'source-dependencies':
            targets = [r.get('Target', '').replace('\\', '/') for r in document.get('Results', []) if r.get('Type') == 'npm']
            if not all(any(t.endswith(app + '/package-lock.json') for t in targets) for app in ('backend', 'frontend')):
                raise RuntimeError('Scanner must recognize both npm lockfiles')
        if name == 'iac' and not document.get('Results'):
            raise RuntimeError('IaC scan produced no recognized results')
        if 'localImageId' in metadata:
            for group in document.get('Results', []):
                group['Target'] = group.get('Target', '').replace(metadata['image'], metadata['imageScope'] + '-image')
        if 'localImageId' in metadata and document.get('Metadata', {}).get('ImageID') != metadata['localImageId']:
            raise RuntimeError('Scanner image ID differs from built local image')
        return evaluate(name, document, accepted, **metadata)
    finally:
        raw.unlink(missing_ok=True)


def secret_scan(accepted):
    skips = ['.git', '.phase12', 'release-artifact', 'backend/node_modules', 'frontend/node_modules', 'frontend/dist']
    skips += [str(p) for p in Path('infrastructure').rglob('.terraform')]
    opts = [value for path in skips for value in ('--skip-dirs', path)]
    scan('source-secrets', ['fs', '--scanners', 'secret', *opts, '.'], accepted)


def dependency_scan(accepted):
    staging = RUNTIME / 'dependency-source'
    for app in ('backend', 'frontend'):
        target = staging / app
        target.mkdir(parents=True, exist_ok=True)
        for name in ('package.json', 'package-lock.json'):
            (target / name).write_bytes((Path(app) / name).read_bytes())
    scan('source-dependencies', ['fs', '--scanners', 'vuln', '--include-dev-deps', str(staging)], accepted)


def iac_scan(accepted, helm):
    import shutil
    staging = RUNTIME / 'iac-source'
    staging.mkdir(parents=True, exist_ok=True)
    for directory in ('infrastructure', 'kubernetes'):
        for path in Path(directory).rglob('*'):
            if not path.is_file() or '.terraform' in path.parts:
                continue
            if path.suffix not in ('.tf', '.yaml', '.yml', '.json'):
                continue
            if 'trivy:ignore' in path.read_text() or 'tfsec:ignore' in path.read_text():
                raise RuntimeError(f'Inline scanner suppression requires review/removal: {path}')
            target = staging / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
    for app in ('backend', 'frontend'):
        target = staging / app / 'Dockerfile'
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(Path(app) / 'Dockerfile', target)
    # Synthetic values are for static chart checking only; they never enter deployment.
    values = {
        app: {'image': f'952078551971.dkr.ecr.ap-south-1.amazonaws.com/opsflow-lab-{app}@sha256:' + '0' * 64}
        for app in ('backend', 'frontend')
    }
    values['config'] = {'DB_HOST': 'ci-placeholder.rds.amazonaws.com'}
    values['nginxConfig'] = Path('frontend/nginx.conf').read_text()
    values['ingress'] = {'annotations': {
        'alb.ingress.kubernetes.io/inbound-cidrs': '192.0.2.1/32',
        'alb.ingress.kubernetes.io/subnets': 'subnet-ci-placeholder',
        'alb.ingress.kubernetes.io/scheme': 'internet-facing',
        'alb.ingress.kubernetes.io/target-type': 'ip',
        'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP":80}]'
    }}
    overlay = RUNTIME / 'chart-check-values.json'
    overlay.write_text(json.dumps(values))
    checked([helm, 'lint', 'helm/opsflow', '-n', 'opsflow', '-f', str(overlay), '--strict'])
    rendered = checked([helm, 'template', 'opsflow', 'helm/opsflow', '-n', 'opsflow', '-f', str(overlay)], capture=True)
    (staging / 'rendered-opsflow.yaml').write_text(rendered)
    scan('iac', ['config', str(staging)], accepted)


def terraform_checks():
    cache = RUNTIME / 'provider-cache'
    cache.mkdir(parents=True, exist_ok=True)
    os.environ['TF_PLUGIN_CACHE_DIR'] = str(cache.resolve())
    os.environ['TF_IN_AUTOMATION'] = 'true'
    for key in list(os.environ):
        if key.startswith('TF_CLI_ARGS') or key == 'TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE':
            del os.environ[key]
    roots = sorted(p.parent for p in Path('infrastructure').rglob('versions.tf') if '.terraform' not in p.parts)
    if not roots:
        raise RuntimeError('No Terraform roots discovered')
    for root in roots:
        if not (root / '.terraform.lock.hcl').is_file():
            raise RuntimeError(f'Reviewed provider lockfile required: {root}')
        print(f'Validate Terraform root: {root}', flush=True)
        terraform = str(RUNTIME / 'bin/terraform')
        checked([terraform, f'-chdir={root}', 'fmt', '-check'])
        checked([terraform, f'-chdir={root}', 'init', '-backend=false', '-input=false', '-lockfile=readonly', '-no-color'])
        checked([terraform, f'-chdir={root}', 'validate', '-no-color'])
    return [str(root) for root in roots]


def report_manifest():
    return {path.stem: {'path': str(path.relative_to('release-artifact')),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in sorted(REPORTS.glob('*.json'))}
