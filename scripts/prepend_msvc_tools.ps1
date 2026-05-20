# MSVC + Windows SDK for Nuitka/pyside6-deploy (CI and local Windows builds).
# - VsDevCmd amd64: SDK/MSVC env for Nuitka
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

function Import-VsDevCmdEnvironment {
    param([string]$VsInstallPath)

    $devCmd = Join-Path $VsInstallPath "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path $devCmd)) {
        return $false
    }

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        cmd.exe /c "`"$devCmd`" -no_logo -arch=amd64 -host_arch=amd64 >nul 2>&1 && set > `"$tempFile`""
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        Get-Content $tempFile | ForEach-Object {
            if ($_ -match '^(?<key>[^=]+?)=(?<val>.*)$') {
                Set-Item -Path "Env:$($matches['key'])" -Value $matches['val'] -Force
            }
        }
        return $true
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

$sdkComponent = Get-VsWindowsSdkComponent
if ($sdkComponent) {
    Write-Host "[deploy] Windows SDK component present ($sdkComponent)"
} elseif (Test-WindowsKits10) {
    Write-Host "[deploy] Windows Kits 10 present (standalone SDK)"
} else {
    Write-Host "[deploy] No Windows SDK detected via vswhere or Windows Kits 10"
}

if ($env:VSCMD_VER) {
    Write-Host "[deploy] VS dev environment already active ($($env:VSCMD_VER))"
} elseif (Import-VsDevCmdEnvironment -VsInstallPath $installPath) {
    Write-Host "[deploy] VsDevCmd amd64 active ($installPath)"
} else {
    Write-Host "[deploy] VsDevCmd failed; using PATH-only MSVC tools"
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
