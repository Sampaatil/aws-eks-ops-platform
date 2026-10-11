import json
import os
import re
import subprocess
from pathlib import Path


def run(args, *, capture=False, cwd=None, data=None):
    p = subprocess.run(args, cwd=cwd, input=data, text=True, capture_output=capture, check=False)
    if p.returncode:
        raise RuntimeError(f'{Path(args[0]).name} failed with exit {p.returncode}; stop and inspect build logs.')
    return p.stdout.strip() if capture else None


def aws_json(args):
    return json.loads(run(['aws', *args, '--output', 'json'], capture=True))


def env(name):
    value = os.environ.get(name, '')
    if not value:
        raise RuntimeError(f'Missing {name}')
    return value


def identity():
    if aws_json(['sts', 'get-caller-identity'])['Account'] != env('EXPECTED_ACCOUNT'):
        raise RuntimeError('Wrong AWS account')


def validate_release(r):
    if r.get('formatVersion') != 1 or not re.fullmatch(r'[a-f0-9]{40}', r.get('commit', '')):
        raise RuntimeError('Invalid release identity')
    if r.get('account') != env('EXPECTED_ACCOUNT') or r.get('region') != env('AWS_REGION'):
        raise RuntimeError('Release target mismatch')
    for app in ['backend', 'frontend']:
        repo = env(app.upper() + '_REPOSITORY')
        if not repo.startswith(f"{env('EXPECTED_ACCOUNT')}.dkr.ecr.{env('AWS_REGION')}.amazonaws.com/"):
            raise RuntimeError('Repository target mismatch')
        if not re.fullmatch(re.escape(repo) + r'@sha256:[a-f0-9]{64}', r.get(app + 'Image', '')):
            raise RuntimeError('Expected designated digest-pinned ECR image')


def scan(image, *, wait):
    repo, digest = image.split('@')
    name = repo.split('/', 1)[1]
    if wait:
        import subprocess
    import time
    scan_wait_command = [
        'aws', 'ecr', 'wait', 'image-scan-complete',
        '--repository-name', name, '--image-id', f'imageDigest={digest}'
    ]
    for attempt in range(24):
        result = subprocess.run(scan_wait_command, capture_output=True, text=True)
        if result.returncode == 0:
            break
        error = result.stdout + result.stderr
        if 'ScanNotFoundException' not in error or attempt == 23:
            raise RuntimeError(f'ECR scan waiter failed: {error}')
        print('ECR scan record not available yet; retrying in 5 seconds.', flush=True)
        time.sleep(5)
    result = aws_json(['ecr', 'describe-image-scan-findings', '--repository-name', name, '--image-id', f'imageDigest={digest}'])
    if result['imageScanStatus']['status'] != 'COMPLETE':
        raise RuntimeError('Completed BASIC ECR scan required. Enhanced scanning requires a separate Inspector-aware gate.')
    counts = result['imageScanFindings'].get('findingSeverityCounts', {})
    if counts.get('CRITICAL', 0):
        raise RuntimeError('Critical findings block release')
    return counts
