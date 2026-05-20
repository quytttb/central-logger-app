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
$DeployDir = Join-Path $Root "deploy"
$ExePath = Join-Path $DeployDir "CentralLogger.exe"

function Invoke-Checked {
    param(
        [string]$Label,
        [scriptblock]$Command
    )
    Write-Host "== $Label =="
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed (exit $LASTEXITCODE)"
    }
}

function Publish-DeployFolder {
    $dist = $null
    $candidates = @(
        (Join-Path $DeployDir "CentralLogger.dist")
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) {
            $dist = $path
            break
        }
    }
    if (-not $dist) {
        throw "Nuitka output folder not found (expected deploy\CentralLogger.dist)"
    }

    if ($dist -ne $DeployDir) {
        $staging = Join-Path $Root "_deploy_stage"
        if (Test-Path $staging) {
            Remove-Item -Recurse -Force $staging
        }
        New-Item -ItemType Directory -Force -Path $staging | Out-Null
        Copy-Item -Path (Join-Path $dist "*") -Destination $staging -Recurse -Force
        if (Test-Path $DeployDir) {
            Remove-Item -Recurse -Force $DeployDir
        }
        Move-Item $staging $DeployDir
        if ($dist -ne (Join-Path $DeployDir "CentralLogger.dist")) {
            Remove-Item -Recurse -Force $dist -ErrorAction SilentlyContinue
        }
    }

    $mainExe = Join-Path $DeployDir "main.exe"
    if (Test-Path $mainExe) {
        if (Test-Path $ExePath) {
            Remove-Item -Force $ExePath
        }
        Rename-Item -Path $mainExe -NewName "CentralLogger.exe"
    }
}

Set-Location $Root

. (Join-Path $Root "scripts\preflight_python_windows.ps1")

if ($SkipQr) {
    & $Stage -SkipQr
} else {
    & $Stage
}

Invoke-Checked -Label "Compile Qt resources" -Command {
    pyside6-rcc resources\resources.qrc -o src\central_logger\resources_rc.py
}

. (Join-Path $Root "scripts\prepend_msvc_tools.ps1")

$DeployIgnoreDirs = @(
    "src/central_logger/controllers",
    "src/central_logger/db",
    "src/central_logger/services",
    "src/central_logger/utils",
    "src/central_logger/viewmodels"
) -join ","

Invoke-Checked -Label "pyside6-deploy" -Command {
    # --force: no deploy prompts; --assume-yes-for-downloads in pysidedeploy.spec for Nuitka.
    pyside6-deploy -c pysidedeploy.spec src\central_logger\main.py --mode standalone --force `
        --extra-ignore-dirs=$DeployIgnoreDirs
}

Publish-DeployFolder

if (-not (Test-Path $ExePath)) {
    throw "Deploy failed: $ExePath was not created"
}

Write-Host "Done. Run: .\deploy\CentralLogger.exe"
