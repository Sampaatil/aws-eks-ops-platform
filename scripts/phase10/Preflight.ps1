param([string]$Context = 'opsflow-eks', [string]$Region = 'ap-south-1')
$ErrorActionPreference = 'Stop'
$env:AWS_PAGER = ''
$account = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0 -or $account.Trim() -ne '952078551971') { throw 'AWS identity mismatch or expired session' }
helm status opsflow -n opsflow --kube-context $Context
if ($LASTEXITCODE -ne 0) { throw 'Existing OpsFlow release required' }
kubectl --context $Context get nodes -o wide
if ($LASTEXITCODE -ne 0) { throw 'Node lookup failed' }
kubectl --context $Context describe nodes
if ($LASTEXITCODE -ne 0) { throw 'Capacity lookup failed' }
kubectl --context $Context get pods -A -o wide
if ($LASTEXITCODE -ne 0) { throw 'Pod inventory failed' }
helm list -A --kube-context $Context
if ($LASTEXITCODE -ne 0) { throw 'Helm inventory failed' }
aws eks describe-addon --cluster-name opsflow-lab --addon-name eks-pod-identity-agent --region $Region --query 'addon.{Status:status,Version:addonVersion}'
if ($LASTEXITCODE -ne 0) { throw 'Existing Pod Identity agent required; do not add a duplicate' }
aws codepipeline list-pipeline-executions --pipeline-name opsflow-lab-application --region $Region --max-results 10 --query 'pipelineExecutionSummaries[].{Id:pipelineExecutionId,Status:status}'
if ($LASTEXITCODE -ne 0) { throw 'Pipeline inventory failed' }
Write-Host 'Review capacity and existing collectors before installing. This script does not mark capacity adequate automatically.'
