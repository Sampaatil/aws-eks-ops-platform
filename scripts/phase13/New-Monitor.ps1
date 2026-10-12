[CmdletBinding()]
param([string]$RepoRoot = 'C:\Users\ROHIT\Desktop\aws-eks-ops-platform', [string]$Context = 'opsflow-eks')
$ErrorActionPreference = 'Stop'
$Raw = kubectl --context $Context get prometheus -n monitoring -o json
if ($LASTEXITCODE -ne 0) { throw 'Existing Prometheus CR required' }
$Items = @((($Raw -join "`n") | ConvertFrom-Json).items)
if ($Items.Count -ne 1) { throw 'Expected one existing Prometheus; inspect/select explicitly rather than guessing' }
$Selector = $Items[0].spec.podMonitorSelector
if ($null -eq $Selector) { throw 'Prometheus does not select PodMonitors; review existing monitoring configuration first' }
if (@($Selector.matchExpressions).Count -gt 0 -and $null -ne $Selector.matchExpressions) {
    throw 'Expression-based selector needs explicit review; no broad selector change is made'
}
$Labels = @{}
if ($Selector.matchLabels) {
    foreach ($Property in $Selector.matchLabels.PSObject.Properties) { $Labels[$Property.Name] = $Property.Value }
}
$NamespaceSelector = $Items[0].spec.podMonitorNamespaceSelector
if ($NamespaceSelector) {
    if ($NamespaceSelector.matchExpressions) { throw 'Review namespace selector expressions before generating monitor' }
    $NamespaceRaw = kubectl --context $Context get namespace monitoring -o json
    if ($LASTEXITCODE -ne 0) { throw 'Monitoring namespace lookup failed' }
    $NamespaceLabels = (($NamespaceRaw -join "`n") | ConvertFrom-Json).metadata.labels
    foreach ($Property in $NamespaceSelector.matchLabels.PSObject.Properties) {
        if ($NamespaceLabels.($Property.Name) -ne $Property.Value) { throw 'Prometheus namespace selector excludes monitoring' }
    }
}
$Monitor = Get-Content (Join-Path $RepoRoot 'kubernetes\phase13\podmonitor-template.json') -Raw | ConvertFrom-Json
$Monitor.metadata.labels = $Labels
$Runtime = Join-Path $RepoRoot '.phase13'
New-Item -ItemType Directory -Force -Path $Runtime | Out-Null
$Path = Join-Path $Runtime 'podmonitor.json'
[IO.File]::WriteAllText($Path, ($Monitor | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
Write-Host "Prepared monitor for Prometheus $($Items[0].metadata.name); no cluster mutation performed."
Write-Host $Path
