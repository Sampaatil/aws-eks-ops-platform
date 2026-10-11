import hashlib
import json
import os
import subprocess
import time
import urllib.request
from pathlib import Path
from common import aws_json, env, identity, run, scan, validate_release


def k(args, *, capture=False):
    return run(['tools/kubectl', '--context', 'opsflow-ci', '-n', 'opsflow', *args], capture=capture)


def helm(args, *, capture=False):
    return run(['tools/helm', *args, '-n', 'opsflow', '--kube-context', 'opsflow-ci'], capture=capture)


def verify():
    p = subprocess.Popen(['tools/kubectl', '--context', 'opsflow-ci', '-n', 'opsflow', 'port-forward',
                          'service/frontend-service', '18080:8080', '--address', '127.0.0.1'],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline = time.monotonic() + 90
        while True:
            try:
                with urllib.request.urlopen('http://127.0.0.1:18080/ready', timeout=8) as response:
                    result = json.load(response)
                if result.get('status') != 'ready' or result.get('database') != 'connected':
                    raise RuntimeError('Readiness contract failed')
                break
            except Exception:
                if p.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError('Internal frontend/backend/database readiness failed')
                time.sleep(3)
        for path in ['/', '/nginx-health', '/health', '/api/incidents']:
            with urllib.request.urlopen('http://127.0.0.1:18080' + path, timeout=15) as response:
                if response.status != 200:
                    raise RuntimeError('Internal HTTP check failed')
                if path == '/api/incidents':
                    # Read-only existence/status check; never print incident content.
                    json.load(response)
                else:
                    response.read()
    finally:
        p.terminate()
        try: p.wait(timeout=10)
        except subprocess.TimeoutExpired: p.kill(); p.wait()


def main():
    evidence = Path('deployment.json')
    record = json.loads(Path('release.json').read_text()); validate_release(record); identity()
    for name in ['helm', 'kubectl']:
        path = Path('tools') / name
        if hashlib.sha256(path.read_bytes()).hexdigest() != record['toolChecksums'][name]:
            raise RuntimeError('Artifact tool checksum mismatch')
        path.chmod(0o755)
    cluster = aws_json(['eks', 'describe-cluster', '--name', env('EKS_CLUSTER')])['cluster']
    if cluster['status'] != 'ACTIVE' or not cluster['resourcesVpcConfig']['endpointPrivateAccess']:
        raise RuntimeError('Expected ACTIVE EKS with private endpoint access')
    run(['aws', 'eks', 'update-kubeconfig', '--name', env('EKS_CLUSTER'), '--alias', 'opsflow-ci'])
    status = json.loads(helm(['status', 'opsflow', '-o', 'json'], capture=True))
    if status['info']['status'] != 'deployed':
        raise RuntimeError('Existing verified deployed Helm release required; pipeline does not bootstrap/recover an initial install')
    verify()  # Establish a healthy read-only baseline before relying on rollback.
    previous = int(status['version'])
    values = json.loads(helm(['get', 'values', 'opsflow', '-o', 'json'], capture=True))
    if values['config'].get('DB_PASSWORD') or values['config']['DB_SSL'] != 'true':
        raise RuntimeError('Unsafe existing Helm values')
    for app in ['backend', 'frontend']:
        scan(record[app + 'Image'], wait=False)
        values[app]['image'] = record[app + 'Image']
    Path('values-deploy.json').write_text(json.dumps(values))
    helm(['lint', 'helm/opsflow', '-f', 'values-deploy.json', '--strict'])
    helm(['template', 'opsflow', 'helm/opsflow', '-f', 'values-deploy.json'], capture=True)
    result = {'commit': record['commit'], 'previousRevision': previous, 'backendImage': record['backendImage'],
              'frontendImage': record['frontendImage'], 'internalChecksPassed': False, 'publicAlbBrowserVerified': False}
    evidence.write_text(json.dumps(result, indent=2))
    # Atomic rolls back Kubernetes readiness failures; post-rollout HTTP failures require explicit rollback below.
    upgrade_succeeded = False
    try:
        helm(['upgrade', 'opsflow', 'helm/opsflow', '-f', 'values-deploy.json', '--atomic', '--wait', '--timeout', '10m', '--history-max', '10'])
        upgrade_succeeded = True
        for app in ['backend', 'frontend']:
            k(['rollout', 'status', f'deployment/{app}', '--timeout=300s'])
            deployed = json.loads(k(['get', 'deployment', app, '-o', 'json'], capture=True))
            image = next(c['image'] for c in deployed['spec']['template']['spec']['containers'] if c['name'] == app)
            if image != record[app + 'Image']:
                raise RuntimeError('Running Deployment digest mismatch')
        verify()
        result['internalChecksPassed'] = True
        result['deployedRevision'] = json.loads(helm(['status', 'opsflow', '-o', 'json'], capture=True))['version']
    except Exception:
        # Do not race an active/pending operation or overwrite a manual intervention.
        current = json.loads(helm(['status', 'opsflow', '-o', 'json'], capture=True))
        if upgrade_succeeded and current['info']['status'] == 'deployed' and int(current['version']) != previous:
            result['recoveryAction'] = f'rollback requested to verified revision {previous}'
            evidence.write_text(json.dumps(result, indent=2))
            helm(['rollback', 'opsflow', str(previous), '--wait', '--timeout', '10m'])
            verify()
            result['rollbackInternalChecksPassed'] = True
        else:
            result['recoveryAction'] = 'No extra rollback; inspect atomic result/pending state/history'
        evidence.write_text(json.dumps(result, indent=2))
        raise
    evidence.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
