# Build MSI from pyside6-deploy / Nuitka deploy folder (Windows).
# Harvested files use $(var.DeployDir) — candle -dDeployDir and light -b must point at deploy/.
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
    $lines = [System.Collections.Generic.List[string]]::new()
    & $Command 2>&1 | ForEach-Object {
        $line = $_.ToString()
        Write-Host $line
        [void]$lines.Add($line)
    }
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed (exit $LASTEXITCODE)"
    }
    $text = $lines -join "`n"
    if ($text -match '(?m)(?:heat|candle|light)\.exe\s*:\s*warning\s') {
        throw "$Label emitted WiX tool warnings (see log above)"
    }
    if ($text -match 'error LGHT') {
        throw "$Label reported LGHT error (see log above)"
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

# CentralLogger.exe is in Product.wxs; exclude Nuitka marker stubs heat may reference without real files.
$HeatExcludes = @(
    "CentralLogger.exe",
    "_nuitka_package.marker"
)

$HarvestWxs = Join-Path $ObjDir "Harvest.wxs"
$HeatWin64Xslt = Join-Path $WxsDir "HeatWin64.xslt"
$heatExcludeArgs = foreach ($item in $HeatExcludes) { "-x"; $item }

Invoke-WixStep -Label "heat harvest deploy/" -Command {
    heat.exe dir $DeployDir -cg HarvestedFiles -dr INSTALLFOLDER -gg -sfrag -srd `
        -sreg -scom @heatExcludeArgs -var var.DeployDir -t $HeatWin64Xslt -out $HarvestWxs
}

$ProductWxs = Join-Path $WxsDir "Product.wxs"
$ProductObj = Join-Path $ObjDir "Product.wixobj"
$HarvestObj = Join-Path $ObjDir "Harvest.wixobj"

Invoke-WixStep -Label "candle Product.wxs" -Command {
    candle.exe "-dDeployDir=$DeployDir" "-dProductVersion=$WixProductVersion" -out $ProductObj $ProductWxs
}
Invoke-WixStep -Label "candle Harvest.wxs" -Command {
    candle.exe "-dDeployDir=$DeployDir" -out $HarvestObj $HarvestWxs
}
Invoke-WixStep -Label "light MSI" -Command {
    light.exe -b $DeployDir -out $OutMsi $ProductObj $HarvestObj
}

Write-Host "Built $OutMsi"
