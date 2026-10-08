$OpsContext = "opsflow-lab"
$OpsCluster = "opsflow-lab"
$OpsRegion = "ap-south-1"
$OpsAccount = "952078551971"

$env:AWS_PROFILE = "opsflow-admin-role"
$env:AWS_REGION = $OpsRegion
$env:AWS_DEFAULT_REGION = $OpsRegion
$env:AWS_PAGER = ""

Write-Host "OpsFlow environment initialized"
Write-Host "AWS Profile: $env:AWS_PROFILE"
Write-Host "Region: $OpsRegion"
Write-Host "EKS Cluster: $OpsCluster"