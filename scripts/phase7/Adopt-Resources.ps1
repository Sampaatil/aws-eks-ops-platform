[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$MigrationFolder)
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\phase6\Common.ps1')
$Baseline=Get-Content (Join-Path $MigrationFolder 'baseline.json') -Raw | ConvertFrom-Json
Assert-CloudTarget $Baseline.accountId $Baseline.region $Baseline.cluster $Baseline.context | Out-Null
$Infra=Get-Infra $RepoRoot
if($Infra.rds_address.value -ne $Baseline.rdsHost){throw 'RDS target changed; baseline is stale.'}
$Allowed=@('Deployment/backend','Deployment/frontend','Service/backend-service','Service/frontend-service','ConfigMap/opsflow-config','ConfigMap/frontend-nginx-config','Ingress/opsflow')
if(@($Baseline.resources.items).Count -ne 7){throw 'Expected exactly seven resources.'}
$Seen=@{}
# Check all objects before changing any metadata.
foreach($Item in $Baseline.resources.items){
 $Key="$($Item.kind)/$($Item.metadata.name)"
 if($Key -notin $Allowed -or $Seen.ContainsKey($Key) -or $Item.metadata.namespace -ne 'opsflow'){throw 'Unexpected or duplicate resource in baseline.'};$Seen[$Key]=$true
 $Live=Get-JsonResult 'kubectl' @('--context',$Baseline.context,'get',$Key,'-n','opsflow','-o','json')
 if($Live.metadata.uid -ne $Item.metadata.uid -or $Live.metadata.resourceVersion -ne $Item.metadata.resourceVersion){throw 'Resource changed after export. Re-export and review a current baseline.'}
 if($Live.metadata.PSObject.Properties['annotations'] -and $Live.metadata.annotations.PSObject.Properties['meta.helm.sh/release-name']){throw 'Resource is already owned; do not overwrite another release.'}
}
foreach($Item in $Baseline.resources.items){
 $Key="$($Item.kind)/$($Item.metadata.name)"
 Invoke-Checked 'kubectl' @('--context',$Baseline.context,'label',$Key,'-n','opsflow','app.kubernetes.io/managed-by=Helm','--overwrite') | Out-Host
 Invoke-Checked 'kubectl' @('--context',$Baseline.context,'annotate',$Key,'-n','opsflow','meta.helm.sh/release-name=opsflow','meta.helm.sh/release-namespace=opsflow') | Out-Host
}
Write-Host 'Ownership metadata added to the seven existing resources. Helm installation is still required; this is not a completed migration.'
