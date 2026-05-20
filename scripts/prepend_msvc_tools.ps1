# MSVC + Windows SDK for Nuitka/pyside6-deploy (CI and local Windows builds).
# - VsDevShell amd64: SDK paths Nuitka expects inside Visual Studio
# - dumpbin on PATH: PySide6 Qt dependency scan

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Host "[deploy] Visual Studio Installer not found."
    Write-Host "       https://visualstudio.microsoft.com/visual-cpp-build-tools/"
    return
}

$installPath = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath 2>$null

if (-not $installPath) {
    Write-Host "[deploy] MSVC C++ workload not found in Visual Studio."
    return
}

# Windows SDK component (Nuitka: must be installed in VS, not only standalone SDK).
$sdkComponent = "Microsoft.VisualStudio.Component.Windows11SDK.22621"
$hasSdk = & $vswhere -latest -products * -requires $sdkComponent -property installationPath 2>$null
if (-not $hasSdk) {
    $vsInstaller = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
    if (Test-Path $vsInstaller) {
        Write-Host "[deploy] Installing VS component: $sdkComponent"
        $proc = Start-Process -FilePath $vsInstaller -ArgumentList @(
            "modify",
            "--installPath", $installPath,
            "--add", $sdkComponent,
            "--quiet",
            "--wait",
            "--norestart"
        ) -PassThru -Wait -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            throw "vs_installer modify failed (exit $($proc.ExitCode)) for $sdkComponent"
        }
        Write-Host "[deploy] Windows SDK component installed."
    } else {
        Write-Host "[deploy] vs_installer.exe not found; cannot add $sdkComponent"
    }
} else {
    Write-Host "[deploy] Windows SDK component present ($sdkComponent)"
}

$launchVs = Join-Path $installPath "Common7\Tools\Launch-VsDevShell.ps1"
if (Test-Path $launchVs) {
    Import-Module $launchVs -DisableNameChecking
    Enter-VsDevShell -VsInstallPath $installPath -SkipAutomaticLocation -Arch amd64 -HostArch amd64
    Write-Host "[deploy] VsDevShell amd64 active ($installPath)"
} else {
    Write-Host "[deploy] Launch-VsDevShell.ps1 not found; using PATH-only MSVC tools"
}

$dumpbin = Get-ChildItem -Path (Join-Path $installPath "VC\Tools\MSVC") `
    -Filter dumpbin.exe -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "Hostx64\\x64\\dumpbin\.exe$" } |
    Select-Object -First 1

if ($dumpbin) {
    $binDir = $dumpbin.Directory.FullName
    if ($env:Path -notlike "*$binDir*") {
        $env:Path = "$binDir;$env:Path"
    }
    Write-Host "[deploy] MSVC tools on PATH ($binDir)"
} else {
    Write-Host "[deploy] dumpbin.exe not found under $installPath"
}
