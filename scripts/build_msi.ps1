# Build MSI from pyside6-deploy / Nuitka deploy folder (Windows).
# Requires WiX Toolset 7 (dotnet tool install --global wix).
# Usage: .\scripts\build_msi.ps1 -DeployDir deploy [-Version 0.1.0]
param(
    [Parameter(Mandatory = $true)]
    [string]$DeployDir,
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$WixProj = Join-Path $Root "packaging\windows\CentralLogger.wixproj"
$Dist = Join-Path $Root "dist"

if (-not $Version) {
    $pyprojectPath = Join-Path $Root "pyproject.toml"
    $content = Get-Content -LiteralPath $pyprojectPath -Raw
    if ($content -match '(?m)^version\s*=\s*"([^"]+)"') {
        $Version = $Matches[1]
    } else {
        $Version = "0.1.0"
    }
}

$MsiFileVersion = $Version
$WixProductVersion = $Version
if ($WixProductVersion -match '^\d+\.\d+\.\d+$') {
    $WixProductVersion = "$WixProductVersion.0"
}
Write-Host "MSI file version: $MsiFileVersion | WiX Package Version: $WixProductVersion"

$DeployDir = (Resolve-Path $DeployDir).Path
if (-not (Test-Path (Join-Path $DeployDir "CentralLogger.exe"))) {
    Write-Error "CentralLogger.exe not found under $DeployDir"
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Error ".NET SDK not found. Install .NET 8+ and WiX: dotnet tool install --global wix"
}

$wixCmd = Get-Command wix -ErrorAction SilentlyContinue
if (-not $wixCmd) {
    Write-Host "Installing WiX Toolset (global dotnet tool)..."
    dotnet tool install --global wix
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" `
        + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (-not (Get-Command wix -ErrorAction SilentlyContinue)) {
        Write-Error "wix CLI not found after install. Restart shell or add %USERPROFILE%\.dotnet\tools to PATH."
    }
}

Write-Host "== wix version =="
wix --version

New-Item -ItemType Directory -Force -Path $Dist | Out-Null

$expectedMsi = Join-Path $Dist "CentralLogger-$MsiFileVersion-win64.msi"
Write-Host "== dotnet build WiX project =="
dotnet build $WixProj -c Release `
    -p:DeployDir=$DeployDir `
    -p:ProductVersion=$WixProductVersion `
    -p:MsiBaseVersion=$MsiFileVersion `
    -p:AcceptEula=wix7 `
    -v:m
if ($LASTEXITCODE -ne 0) {
    throw "dotnet build CentralLogger.wixproj failed (exit $LASTEXITCODE)"
}

$built = Get-ChildItem -Path $Dist -Filter "CentralLogger-*-win64.msi" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $built) {
    throw "No MSI found under $Dist after build"
}

if ($built.FullName -ne $expectedMsi) {
    if (Test-Path $expectedMsi) {
        Remove-Item $expectedMsi -Force
    }
    Move-Item -Path $built.FullName -Destination $expectedMsi -Force
}

Write-Host "Built $expectedMsi"
