[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\..')
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path $RepoRoot).Path
$SourceRoot = (Resolve-Path $SourceRoot).Path
if (-not (Test-Path (Join-Path $RepoRoot '.git'))) { throw 'Target must be the existing Git repository' }
function Get-NormalizedText([string]$Path) {
    return [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").TrimStart([char]0xFEFF)
}
function Get-TextHash([string]$Text) {
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $Hasher.Dispose() }
}
$Manifest = Get-Content (Join-Path $SourceRoot 'package-manifest.json') -Raw | ConvertFrom-Json
# Check ALL files before making any change. Preserve unexpected local changes.
foreach ($Entry in $Manifest.files) {
    if ($Entry.path -match '(^[/\\]|\.\.)') { throw 'Invalid package path' }
    $Source = Join-Path $SourceRoot $Entry.path
    $Target = Join-Path $RepoRoot $Entry.path
    $DesiredHash = Get-TextHash (Get-NormalizedText $Source)
    if ($DesiredHash -ne $Entry.sha256) { throw "Package checksum mismatch: $($Entry.path)" }
    if (Test-Path $Target) {
        $CurrentHash = Get-TextHash (Get-NormalizedText $Target)
        if (($CurrentHash -ne $DesiredHash) -and ($CurrentHash -ne $Entry.originalSha256)) {
            throw "Existing file differs from reviewed baseline: $($Entry.path). Preserve it; do not force overwrite."
        }
    } elseif ($Entry.originalSha256) {
        throw "Expected existing file missing: $($Entry.path)"
    }
}
$Runtime = Join-Path $RepoRoot '.phase13'
New-Item -ItemType Directory -Force -Path $Runtime | Out-Null
[IO.File]::WriteAllText((Join-Path $Runtime '.gitignore'), "*`n!.gitignore`n", (New-Object Text.UTF8Encoding($false)))
$Backup = Join-Path $Runtime ('apply-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
foreach ($Entry in $Manifest.files) {
    $Source = Join-Path $SourceRoot $Entry.path
    $Target = Join-Path $RepoRoot $Entry.path
    $Text = Get-NormalizedText $Source
    if ((Test-Path $Target) -and ((Get-TextHash (Get-NormalizedText $Target)) -eq $Entry.sha256)) { continue }
    if (Test-Path $Target) {
        $Saved = Join-Path $Backup $Entry.path
        New-Item -ItemType Directory -Force -Path (Split-Path $Saved) | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Saved
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
    [IO.File]::WriteAllText($Target, $Text, (New-Object Text.UTF8Encoding($false)))
    Write-Host "Prepared $($Entry.path)"
}
Write-Host 'Phase 13 files prepared. No Git commit, AWS provisioning, pipeline execution or Helm operation was performed.'
Write-Host "Backups, if needed: $Backup"
