[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$BackendImage,
  [Parameter(Mandatory=$true)][string]$FrontendImage,
  [Parameter(Mandatory=$true)][string]$RdsHost,
  [Parameter(Mandatory=$true)][string]$AdminCidr,
  [Parameter(Mandatory=$true)][string[]]$PublicSubnetIds
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$TemplateRoot = Join-Path $RepoRoot 'kubernetes\eks\templates'
$OutputRoot = Join-Path $RepoRoot 'kubernetes\eks\generated'
if ($BackendImage -notmatch '^\d{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9/_-]+@sha256:[a-f0-9]{64}$') { throw 'Use the verified backend ECR image digest URI.' }
if ($FrontendImage -notmatch '^\d{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9/_-]+@sha256:[a-f0-9]{64}$') { throw 'Use the verified frontend ECR image digest URI.' }
if ($RdsHost -notmatch '^[a-zA-Z0-9.-]+\.rds\.amazonaws\.com$') { throw 'Invalid RDS DNS name.' }
$CidrIp = $AdminCidr.Split('/')[0]
$ParsedIp = $null
if ($AdminCidr -notmatch '/32$' -or -not [System.Net.IPAddress]::TryParse($CidrIp, [ref]$ParsedIp) -or $ParsedIp.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { throw 'Use your public IPv4 /32.' }
if ($PublicSubnetIds.Count -ne 2 -or @($PublicSubnetIds | Where-Object { $_ -notmatch '^subnet-[a-f0-9]+$' }).Count -gt 0) { throw 'Supply both actual public subnet IDs.' }
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$Map = @{
  '__BACKEND_IMAGE__' = $BackendImage
  '__FRONTEND_IMAGE__' = $FrontendImage
  '__RDS_HOST__' = $RdsHost
  '__ADMIN_CIDR__' = $AdminCidr
  '__PUBLIC_SUBNETS__' = ($PublicSubnetIds -join ',')
}
$Utf8 = New-Object System.Text.UTF8Encoding($false)
Get-ChildItem -LiteralPath $TemplateRoot -Filter '*.yaml' | ForEach-Object {
  $Content = [System.IO.File]::ReadAllText($_.FullName)
  foreach ($Entry in $Map.GetEnumerator()) { $Content = $Content.Replace($Entry.Key, $Entry.Value) }
  if ($Content -match '__[A-Z_]+__') { throw "Unresolved placeholder in $($_.Name)" }
  [System.IO.File]::WriteAllText((Join-Path $OutputRoot $_.Name), $Content, $Utf8)
}
Write-Host "Rendered manifests to $OutputRoot. Review them before applying."
