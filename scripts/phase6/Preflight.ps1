[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ExpectedAccountId,
  [string]$Region='ap-south-1',
  [string]$Cluster='opsflow-lab',
  [string]$Context='opsflow-eks'
)
. (Join-Path $PSScriptRoot 'Common.ps1')
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
foreach ($Exe in @('aws','kubectl','terraform','docker','git','node','npm')) { Get-Command $Exe -ErrorAction Stop | Out-Null }
$Infra = Get-Infra $RepoRoot
if ($Infra.cluster_name.value -ne $Cluster) { throw 'Terraform cluster output and requested cluster differ.' }
Assert-CloudTarget $ExpectedAccountId $Region $Cluster $Context | Out-Null
$Db = Get-JsonResult 'aws' @('rds','describe-db-instances','--db-instance-identifier',$Infra.rds_identifier.value,'--region',$Region,'--output','json')
if ($Db.DBInstances[0].DBInstanceStatus -ne 'available' -or $Db.DBInstances[0].PubliclyAccessible) { throw 'RDS must be available and private.' }
if ($Db.DBInstances[0].Endpoint.Address -ne $Infra.rds_address.value) { throw 'RDS endpoint and Terraform state disagree.' }
if (-not (Test-Path (Join-Path $RepoRoot 'database\init.sql') -PathType Leaf)) { throw 'database/init.sql is not an actual file.' }
$DockerOs=(Invoke-Checked 'docker' @('info','--format','{{.OSType}}')) -join ''
if ($DockerOs.Trim() -ne 'linux') { throw 'Docker Desktop must use Linux containers.' }
Write-Host 'Infrastructure target verified. This does not prove schema or application readiness.'
Write-Host 'Before release: test local API; verify CA/app Secret/schema and database readiness.'
