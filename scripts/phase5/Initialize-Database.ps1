[CmdletBinding()]
param(
  [string]$Context = 'opsflow-eks',
  [string]$ClusterName = 'opsflow-lab',
  [string]$Region = 'ap-south-1',
  [Parameter(Mandatory=$true)][string]$MasterSecretArn,
  [Parameter(Mandatory=$true)][string]$ExpectedAccountId
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Assert-NativeSuccess([string]$Step) { if ($LASTEXITCODE -ne 0) { throw "$Step failed. Stop and diagnose." } }
$Identity = aws sts get-caller-identity --output json | ConvertFrom-Json
Assert-NativeSuccess 'Identity lookup'
if ($Identity.Account -ne $ExpectedAccountId) { throw 'Wrong AWS account.' }
if ($MasterSecretArn -notmatch "^arn:aws:secretsmanager:$Region`:$ExpectedAccountId`:secret:") { throw 'Secret ARN account/region mismatch.' }
$ExpectedEndpoint = aws eks describe-cluster --name $ClusterName --region $Region --query cluster.endpoint --output text
Assert-NativeSuccess 'Cluster lookup'
$ActualEndpoint = kubectl --context $Context config view --minify -o jsonpath='{.clusters[0].cluster.server}'
Assert-NativeSuccess 'Context lookup'
if ($ActualEndpoint.Trim() -ne $ExpectedEndpoint.Trim()) { throw 'Context does not point to the intended EKS cluster.' }
$InitFile = Join-Path $RepoRoot 'database\init.sql'
if (-not (Test-Path -LiteralPath $InitFile -PathType Leaf)) { throw 'database/init.sql must be an actual file. Review its contents before this script.' }
$Jobs = Join-Path $RepoRoot 'kubernetes\eks\jobs'
$ExistingSecret = kubectl --context $Context get secret opsflow-db-secret -n opsflow --ignore-not-found -o name
Assert-NativeSuccess 'Application secret lookup'
if ([string]::IsNullOrWhiteSpace($ExistingSecret)) {
  $RandomBytes = New-Object byte[] 32
  $Random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $Random.GetBytes($RandomBytes) } finally { $Random.Dispose() }
  $AppPassword = [Convert]::ToBase64String($RandomBytes)
  $AppSecret = @{
    apiVersion='v1'; kind='Secret'; metadata=@{name='opsflow-db-secret';namespace='opsflow'}
    type='Opaque'; data=@{DB_PASSWORD=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($AppPassword))}
  }
  $AppSecret | ConvertTo-Json -Depth 10 -Compress | kubectl --context $Context create -f -
  Assert-NativeSuccess 'Application secret creation'
} else {
  # Preserve a working password. Never silently generate a replacement for an existing DB user.
  $AppPasswordEncoded = kubectl --context $Context get secret opsflow-db-secret -n opsflow -o jsonpath='{.data.DB_PASSWORD}'
  Assert-NativeSuccess 'Existing application secret lookup'
  $AppPassword = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($AppPasswordEncoded))
}
$BootstrapSecretCreated = $false
try {
  $MasterRaw = aws secretsmanager get-secret-value --secret-id $MasterSecretArn --region $Region --query SecretString --output text
  Assert-NativeSuccess 'Master credential retrieval'
  $Master = $MasterRaw | ConvertFrom-Json
  if ($Master.username -ne 'opsflow_admin' -or [string]::IsNullOrWhiteSpace($Master.password)) { throw 'Unexpected master credential structure.' }
  $BootstrapSecret = @{
    apiVersion='v1';kind='Secret';metadata=@{name='opsflow-rds-bootstrap';namespace='opsflow'}
    type='Opaque';data=@{password=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Master.password))}
  }
  # Create fails if a stale bootstrap secret exists: inspect and remove it before retrying.
  $BootstrapSecret | ConvertTo-Json -Depth 10 -Compress | kubectl --context $Context create -f -
  Assert-NativeSuccess 'Bootstrap secret creation'
  $BootstrapSecretCreated = $true
  $RoleSql = Join-Path $Jobs 'create-app-role.sql'
  kubectl --context $Context create configmap opsflow-app-role-sql -n opsflow "--from-file=create-app-role.sql=$RoleSql" --dry-run=client -o yaml | kubectl --context $Context apply -f -
  Assert-NativeSuccess 'Role SQL config map'
  kubectl --context $Context apply -f (Join-Path $Jobs 'create-app-role.yaml')
  Assert-NativeSuccess 'Role job apply'
  kubectl --context $Context wait --for=condition=complete job/opsflow-create-app-role -n opsflow --timeout=300s
  Assert-NativeSuccess 'Role creation job'
  # Master job and temporary master secret must disappear before leaving this stage.
  kubectl --context $Context delete job opsflow-create-app-role -n opsflow --wait=true
  Assert-NativeSuccess 'Bootstrap job cleanup'
  kubectl --context $Context delete secret opsflow-rds-bootstrap -n opsflow
  Assert-NativeSuccess 'Bootstrap secret cleanup'
  $BootstrapSecretCreated = $false
  kubectl --context $Context create configmap opsflow-schema -n opsflow "--from-file=init.sql=$InitFile" --dry-run=client -o yaml | kubectl --context $Context apply -f -
  Assert-NativeSuccess 'Schema config map'
  kubectl --context $Context apply -f (Join-Path $Jobs 'init-schema.yaml')
  Assert-NativeSuccess 'Schema job apply'
  kubectl --context $Context wait --for=condition=complete job/opsflow-init-schema -n opsflow --timeout=300s
  Assert-NativeSuccess 'Schema job'
  kubectl --context $Context logs job/opsflow-init-schema -n opsflow
  Assert-NativeSuccess 'Schema verification logs'
  Write-Host 'Schema initialized as opsflow_app. Verify ssl=t in job output.'
} finally {
  if ($BootstrapSecretCreated) {
    kubectl --context $Context delete job opsflow-create-app-role -n opsflow --ignore-not-found --wait=true | Out-Null
    kubectl --context $Context delete secret opsflow-rds-bootstrap -n opsflow --ignore-not-found | Out-Null
  }
  $AppPassword=$null; $AppPasswordEncoded=$null; $MasterRaw=$null; $Master=$null; $AppSecret=$null; $BootstrapSecret=$null
}
