[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReleaseFile,[switch]$CreateTestIncident)
. (Join-Path $PSScriptRoot 'Common.ps1')
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Release=Get-Content -LiteralPath $ReleaseFile -Raw | ConvertFrom-Json
Assert-ReleaseRecord $Release
Assert-CloudTarget $Release.accountId $Release.region $Release.cluster $Release.context | Out-Null
foreach($App in @('backend','frontend')) {
 $D=Get-JsonResult 'kubectl' @('--context',$Release.context,'get','deployment',$App,'-n','opsflow','-o','json')
 $Expected=if($App -eq 'backend'){$Release.backendImage}else{$Release.frontendImage}
 $Container=@($D.spec.template.spec.containers | Where-Object {$_.name -eq $App})[0]
 if($Container.image -ne $Expected -or -not $D.status.PSObject.Properties['availableReplicas'] -or $D.status.availableReplicas -lt $D.spec.replicas) { throw "$App rollout/image verification failed." }
 $Pods=Get-JsonResult 'kubectl' @('--context',$Release.context,'get','pods','-n','opsflow','-l',"app=$App",'-o','json')
 $Running=@($Pods.items | Where-Object {-not $_.metadata.PSObject.Properties['deletionTimestamp']})
 if($Running.Count -lt $D.spec.replicas) { throw 'Not enough non-terminating Pods.' }
 foreach($Pod in $Running){
  $PodContainer=@($Pod.spec.containers | Where-Object {$_.name -eq $App})
  if($PodContainer.Count -ne 1 -or $PodContainer[0].image -ne $Expected){throw "Pod image differs from intended release."}
  $Status=@($Pod.status.containerStatuses | Where-Object {$_.name -eq $App})
  if($Status.Count -ne 1 -or -not $Status[0].ready -or [string]::IsNullOrWhiteSpace($Status[0].imageID)){throw 'Pod container is not ready or has no runtime image identity.'}
 }
}
$Base=Get-LabBaseUrl $Release.context
$Nginx=Invoke-RestMethod "$Base/nginx-health" -TimeoutSec 30
$Health=Invoke-RestMethod "$Base/health" -TimeoutSec 30
$Ready=Invoke-RestMethod "$Base/ready" -TimeoutSec 30
if($Ready.status -ne 'ready' -or $Ready.database -ne 'connected'){throw 'Database readiness did not pass.'}
$List=Invoke-RestMethod "$Base/api/incidents" -TimeoutSec 30
$TestMarker=$null
$CreatedId=$null
if($CreateTestIncident){
 $TestMarker="Phase 6 verification $($Release.releaseId)"
 $Body=@{title=$TestMarker;description='Synthetic release acceptance record';severity='medium';service='opsflow-api'} | ConvertTo-Json
 $Created=Invoke-RestMethod "$Base/api/incidents" -Method POST -ContentType 'application/json' -Body $Body -TimeoutSec 30
 $List=Invoke-RestMethod "$Base/api/incidents" -TimeoutSec 30
 $Rows=if($List -is [array]){$List}elseif($List.PSObject.Properties['incidents']){@($List.incidents)}else{throw 'Unexpected incident list format; inspect actual API contract.'}
 $Matched=@($Rows | Where-Object {$_.title -eq $TestMarker})
 if($Matched.Count -lt 1){throw 'Created incident was not returned by GET.'}
 $CreatedId=$Matched[0].id
}
$Report=[ordered]@{
 releaseId=$Release.releaseId;verifiedAt=(Get-Date).ToUniversalTime().ToString('o')
 baseUrl=$Base;backendImage=$Release.backendImage;frontendImage=$Release.frontendImage
 health=$Health;readiness=$Ready;syntheticIncidentTitle=$TestMarker;syntheticIncidentId=$CreatedId
 browserChecked=$false;notes='HTTP/API checks passed; complete manual browser and update/delete checks using actual routes.'
}
$ReportPath=Join-Path $RepoRoot ".phase6\verification\$($Release.releaseId).json"
Write-JsonFile $ReportPath $Report
Write-Host "HTTP/API checks passed: $Base. Evidence: $ReportPath"
Write-Host 'Test record remains for persistence checks; remove only through the actual supported API/UI.'
