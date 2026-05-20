# Build MSI from pyside6-deploy / Nuitka deploy folder (Windows).
# Usage: .\scripts\build_msi.ps1 -DeployDir deploy [-Version 0.1.0]
param(
    [Parameter(Mandatory = $true)]
    [string]$DeployDir,
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $Version) {
    $pyproject = Join-Path $Root "pyproject.toml"
    if ($pyproject -match 'version\s*=\s*"([^"]+)"') {
        $Version = $Matches[1]
    } else {
        $Version = "0.1.0"
    }
}

$DeployDir = Resolve-Path $DeployDir
$Dist = Join-Path $Root "dist"
$WxsDir = Join-Path $Root "packaging\windows"
$ObjDir = Join-Path $Dist "wix-obj"
$OutMsi = Join-Path $Dist "CentralLogger-$Version-win64.msi"

if (-not (Test-Path (Join-Path $DeployDir "CentralLogger.exe"))) {
    Write-Error "CentralLogger.exe not found under $DeployDir"
}

New-Item -ItemType Directory -Force -Path $Dist, $ObjDir | Out-Null

# Prefer WiX heat to harvest full deploy tree
$heat = Get-Command heat.exe -ErrorAction SilentlyContinue
$candle = Get-Command candle.exe -ErrorAction SilentlyContinue
$light = Get-Command light.exe -ErrorAction SilentlyContinue
if (-not $heat -or -not $candle -or -not $light) {
    Write-Error @"
WiX Toolset not found (heat.exe, candle.exe, light.exe).
Install from https://wixtoolset.org/ then re-run this script.
"@
}

$HarvestWxs = Join-Path $ObjDir "Harvest.wxs"
& heat.exe dir $DeployDir -cg HarvestedFiles -dr INSTALLFOLDER -gg -sfrag -srd -out $HarvestWxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ProductWxs = Join-Path $WxsDir "Product.wxs"
$ProductObj = Join-Path $ObjDir "Product.wixobj"
$HarvestObj = Join-Path $ObjDir "Harvest.wixobj"

& candle.exe -dDeployDir=$DeployDir -dProductVersion=$Version -out $ProductObj $ProductWxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& candle.exe -out $HarvestObj $HarvestWxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& light.exe -out $OutMsi $ProductObj $HarvestObj -ext WixUIExtension
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Built $OutMsi"
