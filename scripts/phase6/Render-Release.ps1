[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReleaseFile)
. (Join-Path $PSScriptRoot 'Common.ps1')
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Release=Get-Content -LiteralPath $ReleaseFile -Raw | ConvertFrom-Json
Assert-ReleaseRecord $Release
$Templates=Join-Path $RepoRoot 'kubernetes\eks\templates'
if (-not (Test-Path $Templates -PathType Container)) { throw 'Actual Phase 5 templates are required.' }
$Output=Join-Path $RepoRoot ".phase6\rendered\$($Release.releaseId)"
New-Item -ItemType Directory -Path $Output -Force | Out-Null
$Map=@{
 '__BACKEND_IMAGE__'=$Release.backendImage
 '__FRONTEND_IMAGE__'=$Release.frontendImage
 '__RDS_HOST__'=$Release.rdsHost
 '__ADMIN_CIDR__'=$Release.adminCidr
 '__PUBLIC_SUBNETS__'=($Release.publicSubnetIds -join ',')
}
$Utf8=New-Object Text.UTF8Encoding($false)
Get-ChildItem -LiteralPath $Templates -Filter '*.yaml' | ForEach-Object {
 $Text=[IO.File]::ReadAllText($_.FullName)
 foreach($Entry in $Map.GetEnumerator()) { $Text=$Text.Replace($Entry.Key,$Entry.Value) }
 if($Text -match '__[A-Z_]+__') { throw "Unresolved placeholder in $($_.Name)" }
 [IO.File]::WriteAllText((Join-Path $Output $_.Name),$Text,$Utf8)
}
# Roll Pods when mounted ConfigMap/config values change, even if images are unchanged.
$ConfigText=[IO.File]::ReadAllText((Join-Path $Output 'configmap.yaml'))+[IO.File]::ReadAllText((Join-Path $Output 'nginx.yaml'))
$Sha=[Security.Cryptography.SHA256]::Create()
try { $Hash=([BitConverter]::ToString($Sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($ConfigText)))).Replace('-','').ToLowerInvariant() } finally { $Sha.Dispose() }
$Kustomization=Join-Path $Output 'kustomization.yaml'
$Original=[IO.File]::ReadAllText($Kustomization)
if ($Original -match '(?m)^commonAnnotations:') { throw 'Existing commonAnnotations requires a deliberate merge; renderer will not silently overwrite it.' }
[IO.File]::WriteAllText($Kustomization,$Original+"`ncommonAnnotations:`n  opsflow/config-sha256: '$Hash'`n",$Utf8)
Write-Host "Rendered release: $Output. Review with kubectl kustomize before deploy."
