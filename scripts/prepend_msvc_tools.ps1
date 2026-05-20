# Add MSVC dumpbin/link to PATH when Visual Studio Build Tools are installed.
# Used before pyside6-deploy so PySide6 can scan Qt DLL dependencies (no dumpbin warning).

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Host "[deploy] MSVC Build Tools not found (optional). Install for dependency scan:"
    Write-Host "       https://visualstudio.microsoft.com/visual-cpp-build-tools/"
    return
}

$installPath = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath 2>$null

if (-not $installPath) {
    Write-Host "[deploy] MSVC C++ workload not found in Visual Studio (dumpbin optional)."
    return
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
