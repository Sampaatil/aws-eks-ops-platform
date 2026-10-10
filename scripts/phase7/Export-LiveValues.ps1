[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ExpectedAccountId,[string]$Region='ap-south-1',[string]$Cluster='opsflow-lab',[string]$Context='opsflow-eks')
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\phase6\Common.ps1')
Assert-CloudTarget $ExpectedAccountId $Region $Cluster $Context | Out-Null
$Infra=Get-Infra $RepoRoot
if($Infra.cluster_name.value -ne $Cluster){throw 'Terraform cluster mismatch.'}
Assert-AppDependencies ([pscustomobject]@{context=$Context})
$HelmVersion=(Invoke-Checked 'helm' @('version','--short')) -join ''
if($HelmVersion -notmatch '^v3\.'){throw 'This tested runbook uses Helm 3. Do not mix Helm 4 flags into it.'}
$Releases=Get-JsonResult 'helm' @('list','--all','-n','opsflow','--kube-context',$Context,'-o','json')
if(@($Releases | Where-Object {$_.name -eq 'opsflow'}).Count){throw 'Helm release already exists; use upgrade/recovery, not adoption.'}
$ResourceNames=@('deployment/backend','deployment/frontend','service/backend-service','service/frontend-service','configmap/opsflow-config','configmap/frontend-nginx-config','ingress/opsflow')
$Inventory=Get-JsonResult 'kubectl' (@('--context',$Context,'get')+$ResourceNames+@('-n','opsflow','-o','json'))
if(@($Inventory.items).Count -ne 7){throw 'All seven current resources are required for migration.'}
foreach($Item in $Inventory.items){
 if($Item.metadata.PSObject.Properties['annotations']){
  foreach($Key in @('meta.helm.sh/release-name','meta.helm.sh/release-namespace')){
   if($Item.metadata.annotations.PSObject.Properties[$Key]){throw 'Helm ownership annotation already exists. Diagnose ownership before adoption.'}
  }
 }
 if($Item.metadata.PSObject.Properties['labels'] -and $Item.metadata.labels.PSObject.Properties['app.kubernetes.io/managed-by'] -and $Item.metadata.labels.'app.kubernetes.io/managed-by' -ne 'kubectl'){throw 'Existing management label requires deliberate review before adoption.'}
}
$Back=@($Inventory.items | Where-Object {$_.kind -eq 'Deployment' -and $_.metadata.name -eq 'backend'})[0]
$Front=@($Inventory.items | Where-Object {$_.kind -eq 'Deployment' -and $_.metadata.name -eq 'frontend'})[0]
foreach($D in @($Back,$Front)){
 if(-not $D.status.PSObject.Properties['availableReplicas'] -or $D.status.availableReplicas -lt $D.spec.replicas -or $D.spec.replicas -lt 1){throw 'Current application must be available before adoption.'}
 if($D.spec.selector.matchLabels.app -ne $D.metadata.name){throw 'Selector contract changed; inspect chart rather than changing immutable selectors.'}
}
$Config=@($Inventory.items | Where-Object {$_.kind -eq 'ConfigMap' -and $_.metadata.name -eq 'opsflow-config'})[0].data
if($Config.DB_HOST -ne $Infra.rds_address.value){throw 'Live DB host differs from Terraform.'}
if($Config.DB_SSL -ne 'true' -or $Config.PSObject.Properties['DB_PASSWORD']){throw 'Expected verified TLS config with no password in ConfigMap.'}
$Nginx=@($Inventory.items | Where-Object {$_.kind -eq 'ConfigMap' -and $_.metadata.name -eq 'frontend-nginx-config'})[0].data.'nginx.conf'
$Ingress=@($Inventory.items | Where-Object {$_.kind -eq 'Ingress'})[0]
Assert-Ipv4Cidr $Ingress.metadata.annotations.'alb.ingress.kubernetes.io/inbound-cidrs'
$Annotations=[ordered]@{}
foreach($P in $Ingress.metadata.annotations.PSObject.Properties){if($P.Name.StartsWith('alb.ingress.kubernetes.io/')){$Annotations[$P.Name]=$P.Value}}
$Values=[ordered]@{
 backend=@{image=@($Back.spec.template.spec.containers | Where-Object {$_.name -eq 'backend'})[0].image;replicas=$Back.spec.replicas;resources=@($Back.spec.template.spec.containers | Where-Object {$_.name -eq 'backend'})[0].resources}
 frontend=@{image=@($Front.spec.template.spec.containers | Where-Object {$_.name -eq 'frontend'})[0].image;replicas=$Front.spec.replicas;resources=@($Front.spec.template.spec.containers | Where-Object {$_.name -eq 'frontend'})[0].resources}
 config=$Config;nginxConfig=$Nginx;ingress=@{className=$Ingress.spec.ingressClassName;annotations=$Annotations}
}
foreach($Image in @($Values.backend.image,$Values.frontend.image)){if($Image -notmatch '^\d{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9/_-]+@sha256:[a-f0-9]{64}$' -or -not $Image.StartsWith("$ExpectedAccountId.dkr.ecr.$Region.amazonaws.com/")){throw 'Live images must be digest-pinned in the intended ECR registry.'}}
$Ready=Invoke-RestMethod "$(Get-LabBaseUrl $Context)/ready" -TimeoutSec 30
if($Ready.status -ne 'ready' -or $Ready.database -ne 'connected'){throw 'Existing database readiness failed. Fix Phase 6 first.'}
$Folder=Join-Path $RepoRoot ('.phase7\migration-'+(Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))
if(Test-Path $Folder){throw 'Migration folder already exists.'}
Write-JsonFile (Join-Path $Folder 'values-live.json') $Values
Write-JsonFile (Join-Path $Folder 'baseline.json') ([ordered]@{accountId=$ExpectedAccountId;region=$Region;cluster=$Cluster;context=$Context;rdsHost=$Config.DB_HOST;resources=$Inventory})
Invoke-Checked 'helm' @('lint',(Join-Path $RepoRoot 'helm\opsflow'),'-f',(Join-Path $Folder 'values-live.json'),'--strict','-n','opsflow') | Out-Host
Write-Host "Exported migration folder: $Folder. Review render/diff before adopting anything. No live resources were changed."
