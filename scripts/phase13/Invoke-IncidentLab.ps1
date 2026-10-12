[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Pod,
    [string]$RepoRoot = 'C:\Users\ROHIT\Desktop\aws-eks-ops-platform'
)
$ErrorActionPreference = 'Stop'
$Base = 'http://127.0.0.1:13001'
$Initial = Invoke-RestMethod "$Base/status" -TimeoutSec 10
if ($Initial.pod -ne $Pod) { throw 'Port-forward reaches a different Pod than the selected target' }
if ($Initial.armed) { throw 'A lab run is already armed. Finish or disarm it before starting another' }
$Started = [DateTimeOffset]::UtcNow
$Before = (Invoke-WebRequest 'http://127.0.0.1:13000/metrics' -UseBasicParsing -TimeoutSec 10).Content
$Arm = Invoke-RestMethod "$Base/arm" -Method Post -TimeoutSec 10
$Results = @()
try {
    for ($Index = 0; $Index -lt 5; $Index++) {
        # HttpWebRequest handles expected 500 responses consistently on Windows PowerShell 5.1 and PowerShell 7.
        $Request = [Net.HttpWebRequest]::Create("$Base/error")
        $Request.Timeout = 10000
        $Request.Headers.Add('X-OpsFlow-Lab-Run', $Arm.runId)
        $Response = $null
        try { $Response = $Request.GetResponse() }
        catch [Net.WebException] {
            if ($null -eq $_.Exception.Response) { throw }
            $Response = $_.Exception.Response
        }
        try {
            $Status = [int]$Response.StatusCode
            $Reader = New-Object IO.StreamReader($Response.GetResponseStream())
            try { $Body = $Reader.ReadToEnd() | ConvertFrom-Json } finally { $Reader.Dispose() }
            if ($Status -ne 500 -or $Body.synthetic -ne $true -or $Body.runId -ne $Arm.runId -or -not $Body.requestId) {
                throw 'Unexpected response; stop rather than issuing more requests'
            }
            $Results += [PSCustomObject]@{status=$Status; runId=$Body.runId; requestId=$Body.requestId}
            Write-Host "Synthetic 500 $($Index + 1)/5 requestId=$($Body.requestId)"
        } finally { if ($Response) { $Response.Dispose() } }
    }
} finally {
    # Always attempt disarm, including partial runs; server also expires after two minutes.
    try { Invoke-RestMethod "$Base/disarm" -Method Post -TimeoutSec 10 | Out-Null }
    catch { Write-Warning 'Disarm call failed. Confirm /status; TTL expires within two minutes. Do not start another run.' }
}
$After = (Invoke-WebRequest 'http://127.0.0.1:13000/metrics' -UseBasicParsing -TimeoutSec 10).Content
function Get-LabCounter([string]$Text) {
    $Match = [regex]::Match($Text, '(?m)^opsflow_incident_lab_errors_total\s+(\d+)\s*$')
    if (-not $Match.Success) { throw 'Expected counter not found' }
    return [long]$Match.Groups[1].Value
}
$Delta = (Get-LabCounter $After) - (Get-LabCounter $Before)
if ($Delta -ne 5) { throw 'Expected same-Pod counter increase of five; inspect concurrent runs/Pod restart' }
$Final = Invoke-RestMethod "$Base/status" -TimeoutSec 10
if ($Final.armed) { throw 'Lab still armed; disarm and investigate' }
$Record = [PSCustomObject]@{
    pod=$Pod; runId=$Arm.runId; startedUtc=$Started.ToString('o'); endedUtc=[DateTimeOffset]::UtcNow.ToString('o')
    requests=$Results; exactLocalCounterDelta=$Delta; armedAfter=$Final.armed
    prometheusVerified=$false; cloudWatchVerified=$false; grafanaVerified=$false
}
$Folder = Join-Path $RepoRoot '.phase13'
New-Item -ItemType Directory -Force -Path $Folder | Out-Null
$Path = Join-Path $Folder ('run-' + $Arm.runId + '.json')
[IO.File]::WriteAllText($Path, ($Record | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
Write-Host "Run ID: $($Arm.runId)"
Write-Host "Saved local request evidence: $Path"
Write-Host 'HTTP/local-counter checks passed. Prometheus, Grafana, CloudWatch and real application acceptance remain unverified.'
