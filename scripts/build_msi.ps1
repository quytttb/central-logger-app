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

function Invoke-WixStep {
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

# WiX Product/@Version requires major.minor.build.revision (four integers).
$MsiFileVersion = $Version
$WixProductVersion = $Version
if ($WixProductVersion -match '^\d+\.\d+\.\d+$') {
    $WixProductVersion = "$WixProductVersion.0"
}
Write-Host "MSI file version: $MsiFileVersion | WiX ProductVersion: $WixProductVersion"

$DeployDir = (Resolve-Path $DeployDir).Path
$Dist = Join-Path $Root "dist"
$WxsDir = Join-Path $Root "packaging\windows"
$ObjDir = Join-Path $Dist "wix-obj"
$OutMsi = Join-Path $Dist "CentralLogger-$MsiFileVersion-win64.msi"

if (-not (Test-Path (Join-Path $DeployDir "CentralLogger.exe"))) {
    Write-Error "CentralLogger.exe not found under $DeployDir"
}

New-Item -ItemType Directory -Force -Path $Dist, $ObjDir | Out-Null

foreach ($tool in @("heat.exe", "candle.exe", "light.exe")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "WiX Toolset not found ($tool). Install from https://wixtoolset.org/"
    }
}

$HarvestWxs = Join-Path $ObjDir "Harvest.wxs"
# Exclude main exe — Product.wxs already installs CentralLogger.exe + Start Menu shortcut.
Invoke-WixStep -Label "heat harvest deploy/" -Command {
    heat.exe dir $DeployDir -cg HarvestedFiles -dr INSTALLFOLDER -gg -sfrag -srd `
        -x "CentralLogger.exe" -out $HarvestWxs
}

$ProductWxs = Join-Path $WxsDir "Product.wxs"
$ProductObj = Join-Path $ObjDir "Product.wixobj"
$HarvestObj = Join-Path $ObjDir "Harvest.wixobj"

Invoke-WixStep -Label "candle Product.wxs" -Command {
    candle.exe "-dDeployDir=$DeployDir" "-dProductVersion=$WixProductVersion" -out $ProductObj $ProductWxs
}
Invoke-WixStep -Label "candle Harvest.wxs" -Command {
    candle.exe -out $HarvestObj $HarvestWxs
}

Invoke-WixStep -Label "light MSI" -Command {
    light.exe -out $OutMsi $ProductObj $HarvestObj
}

Write-Host "Built $OutMsi"
