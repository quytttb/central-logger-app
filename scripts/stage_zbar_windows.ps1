# Copy ZBar Windows DLLs into resources/native/windows for dev + Nuitka bundle.
param(
    [Parameter(Mandatory = $true)]
    [string]$Source
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Dest = Join-Path $RepoRoot "resources\native\windows"

if (-not (Test-Path $Source)) {
    Write-Error @"
Source directory not found: $Source

Use the folder that contains libzbar-64.dll (not the README placeholder C:\path\to\zbar\bin).
Install ZBar x64, then run for example:
  .\scripts\stage_zbar_windows.ps1 -Source 'C:\Program Files\ZBar\bin'

Skip this step entirely if you do not need QR scan — continue with pyside6-deploy.
"@
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$files = @("libzbar-64.dll", "libiconv.dll")
foreach ($name in $files) {
    $src = Join-Path $Source $name
    if (Test-Path $src) {
        Copy-Item -Force $src (Join-Path $Dest $name)
        Write-Host "Copied $name"
    } else {
        Write-Warning "Missing $src (skip)"
    }
}

if (-not (Test-Path (Join-Path $Dest "libzbar-64.dll"))) {
    Write-Error "libzbar-64.dll is required in $Dest"
}

Write-Host "Done. DLLs staged in $Dest"
