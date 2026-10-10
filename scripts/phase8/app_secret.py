"""Copy/reconcile an existing app credential; restore only a missing K8s Secret.
No password arguments/files/logs; no database password rotation or auto-sync.
"""
import argparse
import base64
import hmac
import json
import re
import subprocess
import sys
import uuid


class Stop(Exception):
    pass


def kubectl(context, args, payload=None):
    result = subprocess.run(
        ['kubectl', '--context', context, *args],
        input=None if payload is None else json.dumps(payload),
        capture_output=True, text=True, check=False)
    if result.returncode:
        raise Stop('kubectl failed; inspect target/RBAC separately. Sensitive stderr suppressed.')
    return json.loads(result.stdout) if result.stdout.strip() else None


def validate_record(record, config):
    if not isinstance(record, dict) or set(record) != {'formatVersion', 'host', 'database', 'username', 'password'}:
        raise Stop('Unexpected app secret format.')
    if record['formatVersion'] != 1 or not isinstance(record['password'], str) or not record['password']:
        raise Stop('Invalid app secret value.')
    for key, env in [('host', 'DB_HOST'), ('database', 'DB_NAME'), ('username', 'DB_USER')]:
        if record[key] != config[env]:
            raise Stop('Secret identity differs from the live DB configuration; do not restore/overwrite.')
    if record['username'] in ('postgres', 'opsflow_admin'):
        raise Stop('Application credential must not be a master credential.')


def current_secret(sm, arn):
    try:
        return json.loads(sm.get_secret_value(SecretId=arn, VersionStage='AWSCURRENT')['SecretString'])
    except sm.exceptions.ResourceNotFoundException:
        # Caller has already described the metadata resource. No current value yet.
        return None


def reconcile(sm, arn, record, config):
    validate_record(record, config)
    existing = current_secret(sm, arn)
    if existing is not None:
        validate_record(existing, config)
        if not hmac.compare_digest(existing['password'].encode(), record['password'].encode()):
            raise Stop('AWS and Kubernetes credentials differ. Nothing overwritten; investigate rotation history.')
        return 'Existing AWSCURRENT matches Kubernetes; no write performed.'
    sm.put_secret_value(SecretId=arn, ClientRequestToken=str(uuid.uuid4()), SecretString=json.dumps(record))
    return 'Existing app credential stored as AWSCURRENT; database password unchanged.'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode', choices=['backup', 'restore-missing'])
    p.add_argument('--account', required=True)
    p.add_argument('--secret-arn', required=True)
    p.add_argument('--region', default='ap-south-1')
    p.add_argument('--cluster', default='opsflow-lab')
    p.add_argument('--context', default='opsflow-eks')
    a = p.parse_args()
    if not re.fullmatch(r'\d{12}', a.account):
        raise Stop('Invalid expected account.')
    prefix = f'arn:aws:secretsmanager:{a.region}:{a.account}:secret:opsflow/lab/database-app-'
    if not a.secret_arn.startswith(prefix) or not re.fullmatch(r'[A-Za-z0-9]{6}', a.secret_arn[len(prefix):]):
        raise Stop('Use the exact Terraform app-secret ARN in the intended account/region.')
    import boto3
    session = boto3.Session(region_name=a.region)
    if session.client('sts').get_caller_identity()['Account'] != a.account:
        raise Stop('Wrong AWS account.')
    cluster = session.client('eks').describe_cluster(name=a.cluster)['cluster']
    config_view = kubectl(a.context, ['config', 'view', '--minify', '-o', 'json'])
    if cluster['status'] != 'ACTIVE' or config_view['clusters'][0]['cluster']['server'] != cluster['endpoint']:
        raise Stop('Wrong/inactive EKS context.')
    config = kubectl(a.context, ['get', 'configmap', 'opsflow-config', '-n', 'opsflow', '-o', 'json'])['data']
    if config.get('DB_SSL') != 'true' or 'DB_PASSWORD' in config:
        raise Stop('Expected TLS config and no password in ConfigMap.')
    sm = session.client('secretsmanager')
    metadata = sm.describe_secret(SecretId=a.secret_arn)
    if metadata.get('DeletedDate') or metadata.get('RotationEnabled'):
        raise Stop('Secret pending deletion or automatically rotating; manual workflow must not interfere.')
    live = kubectl(a.context, ['get', 'secret', 'opsflow-db-secret', '-n', 'opsflow', '--ignore-not-found', '-o', 'json'])
    if a.mode == 'backup':
        if not live or not live.get('data', {}).get('DB_PASSWORD'):
            raise Stop('Existing Kubernetes app Secret is required; do not generate a new password.')
        record = {'formatVersion': 1, 'host': config['DB_HOST'], 'database': config['DB_NAME'],
                  'username': config['DB_USER'], 'password': base64.b64decode(live['data']['DB_PASSWORD'], validate=True).decode('utf-8')}
        print(reconcile(sm, a.secret_arn, record, config))
    else:
        if live:
            raise Stop('Kubernetes Secret already exists. Restore does not overwrite a live credential.')
        record = current_secret(sm, a.secret_arn)
        validate_record(record, config)
        payload = {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': 'opsflow-db-secret', 'namespace': 'opsflow'},
                   'type': 'Opaque', 'data': {'DB_PASSWORD': base64.b64encode(record['password'].encode()).decode()}}
        # create, not apply: do not retain a last-applied annotation containing Secret data.
        kubectl(a.context, ['create', '-f', '-', '-o', 'json'], payload)
        print('Missing app Secret restored. Restart backend deliberately, then verify TLS/readiness.')


if __name__ == '__main__':
    try:
        main()
    except Stop as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
    except Exception as exc:
        # SDK/kubectl errors may carry request context; never emit full exceptions/tracebacks.
        code = getattr(exc, 'response', {}).get('Error', {}).get('Code', type(exc).__name__)
        print(f'Operation stopped ({code}); no sensitive exception details printed.', file=sys.stderr)
        sys.exit(1)
