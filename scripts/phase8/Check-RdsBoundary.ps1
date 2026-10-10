[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ExpectedAccountId,[string]$Region='ap-south-1',[string]$Cluster='opsflow-lab',[string]$Context='opsflow-eks')
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\phase6\Common.ps1')
Assert-CloudTarget $ExpectedAccountId $Region $Cluster $Context | Out-Null
$Infra=Get-Infra $RepoRoot
if($Infra.cluster_name.value -ne $Cluster){throw 'Terraform cluster mismatch.'}
$Cfg=Get-JsonResult 'kubectl' @('--context',$Context,'get','configmap','opsflow-config','-n','opsflow','-o','json')
if($Cfg.data.DB_HOST -ne $Infra.rds_address.value -or $Cfg.data.DB_SSL -ne 'true' -or $Cfg.data.DB_USER -ne 'opsflow_app'){throw 'Application RDS/TLS/app role configuration mismatch.'}
$Db=Get-JsonResult 'aws' @('rds','describe-db-instances','--db-instance-identifier',$Infra.rds_identifier.value,'--region',$Region,'--output','json')
$D=$Db.DBInstances[0]
if($D.DBInstanceStatus -ne 'available' -or $D.PubliclyAccessible -or -not $D.StorageEncrypted -or $D.BackupRetentionPeriod -lt 1 -or $D.Endpoint.Address -ne $Cfg.data.DB_HOST){throw 'RDS availability/privacy/encryption/backup/endpoint check failed.'}
$Workloads=Get-JsonResult 'kubectl' @('--context',$Context,'get','deployments,statefulsets','-n','opsflow','-o','json')
$Suspect=@($Workloads.items | Where-Object {$_.metadata.name -match 'postgres|postgresql' -or @($_.spec.template.spec.containers | Where-Object {$_.image -match '(^|/)(postgres|postgresql)(:|@|$)'}).Count -gt 0})
if($Suspect.Count){throw 'Potential PostgreSQL workload exists. Investigate its data/ownership; do not delete it automatically.'}
Invoke-Checked 'kubectl' @('--context',$Context,'get','secret/opsflow-db-secret','configmap/rds-ca','-n','opsflow','-o','name') | Out-Host
$Ready=Invoke-RestMethod "$(Get-LabBaseUrl $Context)/ready" -TimeoutSec 30
if($Ready.status -ne 'ready' -or $Ready.database -ne 'connected'){throw 'Database readiness failed.'}
$Restorable=if($D.PSObject.Properties['LatestRestorableTime']){$D.LatestRestorableTime}else{$null}
[pscustomobject]@{RdsHost=$D.Endpoint.Address;Private=$true;Encrypted=$true;BackupRetentionDays=$D.BackupRetentionPeriod;LatestRestorableTime=$Restorable;ConfiguredAppRole=$Cfg.data.DB_USER;Readiness=$Ready.status}
Write-Host 'Boundary checks passed. Run the existing Pool diagnostic once if actual TLS/schema evidence is not already recorded. Workload name/image inspection is not a universal database detector.'
