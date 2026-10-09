[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$BaselineFile)
. (Join-Path $PSScriptRoot 'Common.ps1')
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Baseline=Get-Content -LiteralPath $BaselineFile -Raw | ConvertFrom-Json
if($Baseline.formatVersion -ne 1 -or -not $Baseline.hasHealthyApplication){throw 'No complete healthy previous application exists in this baseline. Diagnose the first release; do not pretend rollback is available.'}
Assert-CloudTarget $Baseline.accountId $Baseline.region $Baseline.cluster $Baseline.context | Out-Null
$Infra=Get-Infra $RepoRoot
if($Infra.rds_address.value -ne $Baseline.rdsHost){throw 'Database environment changed; baseline cannot be applied automatically.'}
$Tmp=Join-Path $RepoRoot '.phase6\rollback-resources.json'
Write-JsonFile $Tmp $Baseline.resources
Invoke-Checked 'kubectl' @('--context',$Baseline.context,'apply','--dry-run=server','-f',$Tmp) | Out-Host
Invoke-Checked 'kubectl' @('--context',$Baseline.context,'apply','-f',$Tmp) | Out-Host
foreach($App in @('backend','frontend')) { Invoke-Checked 'kubectl' @('--context',$Baseline.context,'rollout','status',"deployment/$App",'-n','opsflow','--timeout=300s') | Out-Host }
$Base=Get-LabBaseUrl $Baseline.context
$Ready=Invoke-RestMethod "$Base/ready" -TimeoutSec 30
if($Ready.status -ne 'ready' -or $Ready.database -ne 'connected'){throw 'Rollback readiness failed.'}
Invoke-RestMethod "$Base/api/incidents" -TimeoutSec 30 | Out-Null
Write-Host 'Previous application resources restored; run browser checks and record the rollback. Database/schema was not reverted.'
