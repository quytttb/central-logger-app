# Portable Windows deploy: stage ZBar (auto-download) + rcc + pyside6-deploy.
#
#   .\scripts\build_deploy_windows.ps1
#   .\scripts\build_deploy_windows.ps1 -SkipQr

param(
    [switch]$SkipQr
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Stage = Join-Path $Root "scripts\stage_zbar_windows.ps1"

Set-Location $Root

if ($SkipQr) {
    & $Stage -SkipQr
} else {
    & $Stage
}

Write-Host "== Compile Qt resources =="
pyside6-rcc resources\resources.qrc -o src\central_logger\resources_rc.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== pyside6-deploy =="
pyside6-deploy src\central_logger\main.py -f
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Done. Run: .\deploy\CentralLogger.exe"
