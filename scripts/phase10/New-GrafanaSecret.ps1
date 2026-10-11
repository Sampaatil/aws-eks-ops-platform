param([string]$Context = 'opsflow-eks')
$ErrorActionPreference = 'Stop'
$existing = kubectl --context $Context get secret opsflow-grafana-admin -n monitoring --ignore-not-found -o name
if ($LASTEXITCODE -ne 0) { throw 'Secret lookup failed' }
if ($existing) { Write-Host 'Existing Grafana admin Secret preserved.'; return }
$secure = Read-Host 'Choose a Grafana admin password (at least 16 characters)' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if ($plain.Length -lt 16) { throw 'Password must contain at least 16 characters' }
    $manifest = @{
        apiVersion = 'v1'; kind = 'Secret'
        metadata = @{ name = 'opsflow-grafana-admin'; namespace = 'monitoring' }
        type = 'Opaque'
        stringData = @{ 'admin-user' = 'admin'; 'admin-password' = $plain }
    } | ConvertTo-Json -Depth 6
    $manifest | kubectl --context $Context create -f -
    if ($LASTEXITCODE -ne 0) { throw 'Grafana Secret creation failed' }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $plain = $null; $manifest = $null; $secure = $null
}
