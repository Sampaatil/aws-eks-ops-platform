[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReleaseFile)
. (Join-Path $PSScriptRoot 'Common.ps1')
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Release=Get-Content -LiteralPath $ReleaseFile -Raw | ConvertFrom-Json
Assert-ReleaseRecord $Release
Assert-CloudTarget $Release.accountId $Release.region $Release.cluster $Release.context | Out-Null
$Infra=Get-Infra $RepoRoot
if ($Infra.cluster_name.value -ne $Release.cluster -or $Infra.rds_address.value -ne $Release.rdsHost) { throw 'Infrastructure changed since build. Create a current release record; do not deploy stale RDS configuration.' }
Assert-AppDependencies $Release
& (Join-Path $PSScriptRoot 'Render-Release.ps1') -ReleaseFile $ReleaseFile
$Rendered=Join-Path $RepoRoot ".phase6\rendered\$($Release.releaseId)"
$ResourceArgs=@('--context',$Release.context,'get','deployment/backend','deployment/frontend','service/backend-service','service/frontend-service','configmap/opsflow-config','configmap/frontend-nginx-config','ingress/opsflow','-n','opsflow','--ignore-not-found','-o','json')
$Before=Get-JsonResult 'kubectl' $ResourceArgs
$Healthy=@($Before.items | Where-Object { $_.kind -eq 'Deployment' -and $_.status.PSObject.Properties['availableReplicas'] -and $_.status.availableReplicas -ge $_.spec.replicas -and $_.spec.replicas -gt 0 })
$Complete=(@($Before.items).Count -eq 7 -and $Healthy.Count -eq 2)
foreach($Item in $Before.items) {
 foreach($Property in @('status')) { $Item.PSObject.Properties.Remove($Property) }
 foreach($Property in @('uid','resourceVersion','creationTimestamp','generation','managedFields')) { $Item.metadata.PSObject.Properties.Remove($Property) }
 if($Item.metadata.PSObject.Properties['annotations']) {
  $Item.metadata.annotations.PSObject.Properties.Remove('kubectl.kubernetes.io/last-applied-configuration')
  $Item.metadata.annotations.PSObject.Properties.Remove('deployment.kubernetes.io/revision')
 }
}
$BaselinePath=Join-Path $RepoRoot ".phase6\baselines\$($Release.releaseId).json"
if(Test-Path $BaselinePath) { throw 'This release already has a baseline. Use a new release identity rather than overwrite rollback evidence.' }
$Baseline=[ordered]@{
 formatVersion=1;accountId=$Release.accountId;region=$Release.region;cluster=$Release.cluster;context=$Release.context
 rdsHost=$Release.rdsHost;hasHealthyApplication=$Complete
 capturedAt=(Get-Date).ToUniversalTime().ToString('o')
 resources=$Before
}
Write-JsonFile $BaselinePath $Baseline
Invoke-Checked 'kubectl' @('--context',$Release.context,'apply','--dry-run=server','-k',$Rendered) | Out-Host
Invoke-Checked 'kubectl' @('--context',$Release.context,'apply','-k',$Rendered) | Out-Host
foreach($App in @('backend','frontend')) {
 Invoke-Checked 'kubectl' @('--context',$Release.context,'rollout','status',"deployment/$App",'-n','opsflow','--timeout=300s') | Out-Host
 $D=Get-JsonResult 'kubectl' @('--context',$Release.context,'get','deployment',$App,'-n','opsflow','-o','json')
 $Expected=if($App -eq 'backend'){$Release.backendImage}else{$Release.frontendImage}
 $Actual=@($D.spec.template.spec.containers | Where-Object {$_.name -eq $App})[0].image
 if($Actual -ne $Expected){throw "$App Deployment image differs from intended release."}
}
Write-Host "Rollout finished. Baseline: $BaselinePath"
Write-Host 'Now run Verify-Release.ps1 and browser checks. Rollout completion alone is not acceptance.'
