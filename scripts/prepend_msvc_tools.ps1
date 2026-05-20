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

$installPath = $installPath.TrimEnd('\')

function Test-WindowsKits10 {
    return Test-Path "${env:ProgramFiles(x86)}\Windows Kits\10\Include"
}

function Get-VsWindowsSdkComponent {
    $sdkComponentIds = @(
        'Microsoft.VisualStudio.Component.Windows11SDK.26100',
        'Microsoft.VisualStudio.Component.Windows11SDK.22621',
        'Microsoft.VisualStudio.Component.Windows11SDK.22000',
        'Microsoft.VisualStudio.Component.Windows10SDK.19041',
        'Microsoft.VisualStudio.Component.Windows10SDK'
    )
    foreach ($id in $sdkComponentIds) {
        $found = & $vswhere -latest -products * -requires $id -property installationPath 2>$null
        if ($found) {
            return $id
        }
    }
    return $null
}

$sdkComponent = Get-VsWindowsSdkComponent
$hasWindowsKits = Test-WindowsKits10

if ($sdkComponent) {
    Write-Host "[deploy] Windows SDK component present ($sdkComponent)"
} elseif ($hasWindowsKits) {
    Write-Host "[deploy] Windows Kits 10 present (standalone SDK)"
} else {
    $onCi = $env:GITHUB_ACTIONS -eq 'true'
    if ($onCi) {
        Write-Host "[deploy] No VS SDK component detected on CI; skipping vs_installer (use preinstalled runner SDK + VsDevShell)"
    } else {
        $vsInstaller = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
        $preferredSdk = 'Microsoft.VisualStudio.Component.Windows11SDK.22621'
        if (Test-Path $vsInstaller) {
            Write-Host "[deploy] Installing VS component: $preferredSdk"
            $proc = Start-Process -FilePath $vsInstaller -ArgumentList @(
                'modify',
                '--installPath', $installPath,
                '--add', $preferredSdk,
                '--quiet',
                '--wait',
                '--norestart'
            ) -PassThru -Wait -NoNewWindow
            if ($proc.ExitCode -ne 0) {
                Write-Warning "vs_installer modify failed (exit $($proc.ExitCode)) for $preferredSdk; continuing with VsDevShell"
            } else {
                Write-Host "[deploy] Windows SDK component installed."
                $sdkComponent = Get-VsWindowsSdkComponent
            }
        } else {
            Write-Warning "[deploy] vs_installer.exe not found; cannot add $preferredSdk"
        }
        if (-not $sdkComponent) {
            $hasWindowsKits = Test-WindowsKits10
        }
    }
}

$launchVs = Join-Path $installPath "Common7\Tools\Launch-VsDevShell.ps1"
if (Test-Path $launchVs) {
    Import-Module $launchVs -DisableNameChecking
    Enter-VsDevShell -VsInstallPath $installPath -SkipAutomaticLocation -Arch amd64 -HostArch amd64
    Write-Host "[deploy] VsDevShell amd64 active ($installPath)"
} else {
    Write-Host "[deploy] Launch-VsDevShell.ps1 not found; using PATH-only MSVC tools"
}

$hasSdkEnv = -not [string]::IsNullOrWhiteSpace($env:WindowsSdkDir)
$hasWindowsKits = Test-WindowsKits10
if (-not $hasSdkEnv -and -not $hasWindowsKits -and -not $sdkComponent) {
    throw "[deploy] Windows SDK not found. Install VS workload 'Desktop development with C++' + Windows SDK."
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
