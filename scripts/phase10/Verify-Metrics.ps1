# Run while localhost:9090 forwards to the monitoring Prometheus service.
$ErrorActionPreference = 'Stop'
$queries = @(
    'up',
    'kube_deployment_status_replicas_available{namespace="opsflow",deployment=~"backend|frontend"}',
    'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="opsflow",container!="",container!="POD",image!=""}[5m]))',
    'sum by (pod) (container_memory_working_set_bytes{namespace="opsflow",container!="",container!="POD",image!=""})'
)
foreach ($query in $queries) {
    $url = 'http://127.0.0.1:9090/api/v1/query?query=' + [Uri]::EscapeDataString($query)
    $response = Invoke-RestMethod -Uri $url -TimeoutSec 20
    if ($response.status -ne 'success' -or $response.data.result.Count -eq 0) { throw "No metrics returned: $query" }
    Write-Host "`n$query"
    $response.data.result | ConvertTo-Json -Depth 8
}
$targets = Invoke-RestMethod 'http://127.0.0.1:9090/api/v1/targets' -TimeoutSec 20
$targets.data.activeTargets | Select-Object health, lastError, scrapeUrl | Format-Table -AutoSize
$rules = Invoke-RestMethod 'http://127.0.0.1:9090/api/v1/rules' -TimeoutSec 20
$groups = @($rules.data.groups | Where-Object name -eq 'opsflow.workloads')
if ($groups.Count -ne 1 -or $groups[0].rules.Count -ne 3) { throw 'Expected three OpsFlow rules loaded' }
$groups[0].rules | Select-Object name, health, state, lastError | Format-Table
if (@($groups[0].rules | Where-Object health -ne 'ok').Count -gt 0) { throw 'Rule evaluation errors' }
