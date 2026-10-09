[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ExpectedAccountId,
  [Parameter(Mandatory=$true)][string]$AdminCidr,
  [string]$Region='ap-south-1',
  [string]$Cluster='opsflow-lab',
  [string]$Context='opsflow-eks'
)
. (Join-Path $PSScriptRoot 'Common.ps1')
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $RepoRoot
Assert-Ipv4Cidr $AdminCidr
Assert-CloudTarget $ExpectedAccountId $Region $Cluster $Context | Out-Null
$Infra = Get-Infra $RepoRoot
if ($Infra.cluster_name.value -ne $Cluster) { throw 'Terraform cluster mismatch.' }
$Dirty = Invoke-Checked 'git' @('status','--porcelain')
if (-not [string]::IsNullOrWhiteSpace(($Dirty -join "`n"))) { throw 'Commit/review source changes first. Build releases from a clean Git working tree.' }
$Commit = ((Invoke-Checked 'git' @('rev-parse','HEAD')) -join '').Trim()
if ($Commit -notmatch '^[a-f0-9]{40}$') { throw 'Expected a full Git SHA.' }
$ReleaseId = 'r' + $Commit.Substring(0,12) + '-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
$Repos = $Infra.ecr_repository_urls.value
foreach ($Repo in @($Repos.backend,$Repos.frontend)) {
  if (-not $Repo.StartsWith("$ExpectedAccountId.dkr.ecr.$Region.amazonaws.com/")) { throw 'ECR account/region mismatch.' }
}
$Registry = $Repos.backend.Split('/')[0]
$LoginPassword = (Invoke-Checked 'aws' @('ecr','get-login-password','--region',$Region)) -join ''
try {
  $LoginPassword | & docker login --username AWS --password-stdin $Registry
  if ($LASTEXITCODE -ne 0) { throw 'Docker ECR login failed.' }
} finally { $LoginPassword=$null }
foreach ($App in @('backend','frontend')) {
  $Repo = $Repos.$App
  Invoke-Checked 'docker' @(
    'build',
    '--pull',
    '--platform', 'linux/amd64',
    '--provenance=false',
    '--sbom=false',
    '--label', "org.opencontainers.image.revision=$Commit",
    '-t', "${Repo}:$ReleaseId",
    (Join-Path $RepoRoot $App)
) | Out-Host
}
$Images = @{}
$Findings = @{}
foreach ($App in @('backend','frontend')) {
  $Repo = $Repos.$App
  $RepoName = $Repo.Substring($Repo.IndexOf('/')+1)
  $Details = Get-JsonResult 'aws' @('ecr','describe-images','--repository-name',$RepoName,'--image-ids',"imageTag=$ReleaseId",'--region',$Region,'--output','json')
  $Digest = $Details.imageDetails[0].imageDigest
  if ($Digest -notmatch '^sha256:[a-f0-9]{64}$') { throw 'Digest lookup failed.' }
  Write-Host "Starting basic ECR scan: $App $Digest"

Invoke-Checked 'aws' @(
    'ecr', 'start-image-scan',
    '--repository-name', $RepoName,
    '--image-id', "imageDigest=$Digest",
    '--region', $Region
) | Out-Null

Write-Host "Waiting for basic ECR scan: $App"

Invoke-Checked 'aws' @(
    'ecr', 'wait', 'image-scan-complete',
    '--repository-name', $RepoName,
    '--image-id', "imageDigest=$Digest",
    '--region', $Region
) | Out-Null
  $Scan = Get-JsonResult 'aws' @('ecr','describe-image-scan-findings','--repository-name',$RepoName,'--image-id',"imageDigest=$Digest",'--region',$Region,'--output','json')
  if ($Scan.imageScanStatus.status -ne 'COMPLETE') { throw 'A completed basic scan is required. Enhanced scanning needs its own Inspector-aware gate.' }
  $Counts = $Scan.imageScanFindings.findingSeverityCounts
  $Critical = 0
  if ($Counts.PSObject.Properties['CRITICAL']) { $Critical = [int]$Counts.CRITICAL }
  if ($Critical -gt 0) { throw "Critical findings block $App release. Patch/rebuild; this script has no scan bypass." }
  $Images[$App] = "$Repo@$Digest"
  $Findings[$App] = $Counts
  Write-Host "$App scan counts: $($Counts | ConvertTo-Json -Compress). Review HIGH and other findings before deployment."
}
$Release = [ordered]@{
  formatVersion=1; releaseId=$ReleaseId; commit=$Commit
  createdAt=(Get-Date).ToUniversalTime().ToString('o')
  accountId=$ExpectedAccountId;region=$Region;cluster=$Cluster;context=$Context
  rdsHost=$Infra.rds_address.value;adminCidr=$AdminCidr
  publicSubnetIds=@($Infra.public_subnet_ids.value)
  backendImage=$Images.backend;frontendImage=$Images.frontend
  scanCounts=$Findings
}
$Path = Join-Path $RepoRoot ".phase6\releases\$ReleaseId.json"
Write-JsonFile $Path $Release
Write-Host "Release record: $Path. Review it and test results before deployment."
