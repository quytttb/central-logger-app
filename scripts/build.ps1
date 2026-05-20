# Build entry point: interactive menu or non-interactive args.
#   .\scripts\build.ps1
#   .\scripts\build.ps1 msi patch -DeployDir deploy
param(
    [Parameter(Position = 0)]
    [ValidateSet("msi", "")]
    [string]$Target = "",

    [Parameter(Position = 1)]
    [ValidateSet("major", "minor", "patch", "")]
    [string]$Bump = "",

    [string]$DeployDir = "deploy"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BumpScript = Join-Path $Root "scripts\bump_version.py"
$MsiScript = Join-Path $Root "scripts\build_msi.ps1"

function Get-ProjectVersion {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $py) { return "?" }
    $v = & $py.Source $BumpScript show 2>$null
    if ($LASTEXITCODE -ne 0) { return "?" }
    return $v.Trim()
}

function Invoke-BumpVersion {
    param([ValidateSet("major", "minor", "patch")][string]$Level)
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $py) { Write-Error "python not found on PATH" }
    Write-Host "== Bump version ($Level) =="
    & $py.Source $BumpScript bump $Level
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Read-BumpChoice {
    $ver = Get-ProjectVersion
    Write-Host ""
    Write-Host "Version bump (required for MSI release) — current: $ver"
    Write-Host "  1) PATCH  — bug fixes (0.0.X)"
    Write-Host "  2) MINOR  — new features (0.X.0)"
    Write-Host "  3) MAJOR  — breaking change (X.0.0)"
    Write-Host "  0) Cancel"
    Write-Host ""
    $choice = Read-Host "Select bump [0-3]"
    switch ($choice) {
        "1" { return "patch" }
        "2" { return "minor" }
        "3" { return "major" }
        "0" { return $null }
        default {
            Write-Error "Invalid choice."
        }
    }
}

function Build-Msi {
    param(
        [string]$BumpLevel,
        [string]$Dir
    )
    if (-not $BumpLevel) {
        Write-Host "Cancelled."
        return
    }
    Invoke-BumpVersion -Level $BumpLevel
    $resolved = Resolve-Path $Dir -ErrorAction Stop
    & $MsiScript -DeployDir $resolved.Path
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Show-BuildMenu {
    $ver = Get-ProjectVersion
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  Central Logger — Build (Windows)"
    Write-Host "  Current version: $ver"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "  1) Build MSI installer"
    Write-Host "  0) Exit"
    Write-Host ""
    $choice = Read-Host "Select option [0-1]"
    switch ($choice) {
        "1" {
            $defaultDeploy = Join-Path $Root "deploy"
            $dirInput = Read-Host "Deploy folder [$defaultDeploy]"
            if ([string]::IsNullOrWhiteSpace($dirInput)) {
                $dirInput = $defaultDeploy
            }
            $bump = Read-BumpChoice
            Build-Msi -BumpLevel $bump -Dir $dirInput
        }
        "0" { Write-Host "Bye." }
        default { Write-Error "Invalid choice." }
    }
}

# Non-interactive
if ($Target -eq "msi") {
    if (-not $Bump) {
        Write-Host "Usage: .\scripts\build.ps1 msi {major|minor|patch} -DeployDir deploy" -ForegroundColor Yellow
        Write-Host "  Or run .\scripts\build.ps1 without arguments for the interactive menu." -ForegroundColor Yellow
        exit 1
    }
    Build-Msi -BumpLevel $Bump -Dir $DeployDir
    exit 0
}

if ($Target -ne "") {
    Write-Host "Usage: .\scripts\build.ps1  OR  .\scripts\build.ps1 msi {major|minor|patch} -DeployDir deploy"
    exit 1
}

Show-BuildMenu
