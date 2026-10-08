param(
    [string]$BackupDirectory = 'D:\SmartMoveBackups\MongoDB'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:MONGODB_URI)) {
    throw 'Set MONGODB_URI in the current PowerShell session before running this backup.'
}

if ([string]::IsNullOrWhiteSpace($env:MONGODB_DATABASE)) {
    throw 'Set MONGODB_DATABASE in the current PowerShell session before running this backup.'
}

$mongodump = Get-Command mongodump -ErrorAction SilentlyContinue
if ($null -eq $mongodump) {
    throw 'mongodump was not found. Install MongoDB Database Tools and add mongodump to PATH.'
}

New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$archive = Join-Path $BackupDirectory "smartmove_$($env:MONGODB_DATABASE)_$timestamp.archive.gz"

& $mongodump.Source `
    "--uri=$($env:MONGODB_URI)" `
    "--db=$($env:MONGODB_DATABASE)" `
    "--archive=$archive" `
    --gzip

if ($LASTEXITCODE -ne 0) {
    throw "mongodump failed with exit code $LASTEXITCODE."
}

Write-Output "MongoDB backup created: $archive"
