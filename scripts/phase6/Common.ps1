Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Invoke-Checked {
  param([Parameter(Mandatory=$true)][string]$Executable, [string[]]$Arguments = @())
  $Result = @(& $Executable @Arguments)
  if ($LASTEXITCODE -ne 0) { throw "$Executable failed (exit $LASTEXITCODE). Stop and diagnose before continuing." }
  return $Result
}
function Get-JsonResult {
  param([string]$Executable, [string[]]$Arguments)
  $Text = (Invoke-Checked $Executable $Arguments) -join "`n"
  return ($Text | ConvertFrom-Json)
}
function Write-JsonFile {
  param([string]$Path, $Value)
  $Parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Path $Parent -Force | Out-Null
  $Utf8 = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 100), $Utf8)
}
function Assert-Ipv4Cidr {
  param([string]$Cidr)
  $Ip = $null
  if ($Cidr -notmatch '/32$' -or -not [Net.IPAddress]::TryParse($Cidr.Split('/')[0], [ref]$Ip) -or $Ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'Use the actual current public IPv4 address with /32.' }
}
function Get-Infra {
  param([string]$RepoRoot)
  $Folder = Join-Path $RepoRoot 'infrastructure\phase5'
  if (-not (Test-Path $Folder -PathType Container)) { throw 'Phase 5 Terraform folder is missing.' }
  $Output = Get-JsonResult 'terraform' @("-chdir=$Folder",'output','-json')
  foreach ($Name in @('cluster_name','rds_address','rds_identifier','public_subnet_ids','ecr_repository_urls')) {
    if (-not $Output.PSObject.Properties[$Name]) { throw "Phase 5 output $Name is missing. Initialize its backend, then check whether infrastructure was destroyed. Do not release yet." }
  }
  return $Output
}
function Assert-CloudTarget {
  param([string]$ExpectedAccountId,[string]$Region,[string]$Cluster,[string]$Context)
  if ($ExpectedAccountId -notmatch '^\d{12}$') { throw 'ExpectedAccountId must be the intended 12-digit AWS account.' }
  if ([string]::IsNullOrWhiteSpace($Region) -or [string]::IsNullOrWhiteSpace($Cluster) -or [string]::IsNullOrWhiteSpace($Context)) { throw 'Region, cluster and context must be non-empty.' }
  $Identity = Get-JsonResult 'aws' @('sts','get-caller-identity','--output','json')
  if ($Identity.Account -ne $ExpectedAccountId) { throw 'Wrong AWS account.' }
  $Cloud = Get-JsonResult 'aws' @('eks','describe-cluster','--name',$Cluster,'--region',$Region,'--output','json')
  if ($Cloud.cluster.status -ne 'ACTIVE') { throw 'EKS is not ACTIVE.' }
  $Config = Get-JsonResult 'kubectl' @('--context',$Context,'config','view','--minify','-o','json')
  if ($Config.clusters[0].cluster.server -ne $Cloud.cluster.endpoint) { throw 'The named kube context points to a different cluster.' }
  $Nodes = Get-JsonResult 'kubectl' @('--context',$Context,'get','nodes','-o','json')
  $Ready = @($Nodes.items | Where-Object { @($_.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' }).Count -gt 0 })
  if ($Ready.Count -lt 1) { throw 'No Ready EKS worker nodes.' }
  return $Cloud
}
function Assert-ReleaseRecord {
  param($Release)
  foreach ($Name in @('formatVersion','releaseId','commit','accountId','region','cluster','context','rdsHost','adminCidr','publicSubnetIds','backendImage','frontendImage')) {
    if (-not $Release.PSObject.Properties[$Name]) { throw "Release record missing $Name." }
  }
  if ($Release.formatVersion -ne 1 -or $Release.releaseId -notmatch '^[a-z0-9-]+$' -or $Release.commit -notmatch '^[a-f0-9]{40}$') { throw 'Invalid release identity.' }
  foreach ($Image in @($Release.backendImage,$Release.frontendImage)) {
    if ($Image -notmatch '^\d{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9/_-]+@sha256:[a-f0-9]{64}$') { throw 'Use digest-pinned ECR images in the release record.' }
    if (-not $Image.StartsWith("$($Release.accountId).dkr.ecr.$($Release.region).amazonaws.com/")) { throw 'Image registry account/region mismatch.' }
  }
  Assert-Ipv4Cidr $Release.adminCidr
  if ($Release.rdsHost -notmatch '^[a-zA-Z0-9.-]+\.rds\.amazonaws\.com$') { throw 'Invalid RDS hostname.' }
  if (@($Release.publicSubnetIds).Count -ne 2 -or @($Release.publicSubnetIds | Where-Object { $_ -notmatch '^subnet-[a-f0-9]+$' }).Count) { throw 'Expected two valid public subnet IDs.' }
}
function Assert-AppDependencies {
  param($Release)
  foreach ($Name in @('secret/opsflow-db-secret','configmap/rds-ca')) {
    Invoke-Checked 'kubectl' @('--context',$Release.context,'get',$Name,'-n','opsflow','-o','name') | Out-Null
  }
  $Controller = Get-JsonResult 'kubectl' @('--context',$Release.context,'get','deployment','aws-load-balancer-controller','-n','kube-system','-o','json')
  if (-not $Controller.status.PSObject.Properties['availableReplicas'] -or $Controller.status.availableReplicas -lt 1) { throw 'Load balancer controller is not available.' }
}
function Get-LabBaseUrl {
  param([string]$Context)
  $Ingress = Get-JsonResult 'kubectl' @('--context',$Context,'get','ingress','opsflow','-n','opsflow','-o','json')
  if (-not $Ingress.status.PSObject.Properties['loadBalancer'] -or -not $Ingress.status.loadBalancer.PSObject.Properties['ingress'] -or @($Ingress.status.loadBalancer.ingress).Count -eq 0) { throw 'ALB hostname is not ready; inspect Ingress/controller and retry verification.' }
  $HostName = $Ingress.status.loadBalancer.ingress[0].hostname
  if ($HostName -notmatch '^[a-zA-Z0-9.-]+\.elb\.amazonaws\.com$') { throw 'Unexpected ALB hostname.' }
  return "http://$HostName"
}
