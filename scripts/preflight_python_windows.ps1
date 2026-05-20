# Fail fast when the active Python cannot be used with Nuitka (pyside6-deploy).
# Microsoft Store Python installs under WindowsApps and blocks access to libs/.

$ErrorActionPreference = "Stop"

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    throw "python not found on PATH. Activate .venv or install Python 3.12/3.13."
}

$info = python -c @"
import sys, os
base = getattr(sys, 'base_prefix', sys.prefix)
exe = sys.executable
libs = os.path.join(base, 'libs')
lib_file = None
if os.path.isdir(libs):
    for name in os.listdir(libs):
        if name.startswith('python3') and name.endswith('.lib'):
            lib_file = os.path.join(libs, name)
            break
print(base)
print(exe)
print(libs)
print('1' if os.path.isdir(libs) else '0')
print(lib_file or '')
"@

$lines = $info -split "`n", 5
$basePrefix = $lines[0].Trim()
$executable = $lines[1].Trim()
$libsDir = $lines[2].Trim()
$hasLibsDir = $lines[3].Trim() -eq '1'
$libFile = $lines[4].Trim()

$isStore = ($basePrefix -match 'WindowsApps') -or ($executable -match 'WindowsApps')

if ($isStore) {
    throw @"
[deploy] Unsupported Python: Microsoft Store install detected.

  base_prefix: $basePrefix
  executable:  $executable

Nuitka cannot link against python3*.lib from WindowsApps (AccessDenied on libs/).

Fix:
  1. Install Python from https://www.python.org/downloads/ (3.12 or 3.13, 64-bit).
     Check "Add python.exe to PATH" and prefer "Install for all users".
  2. Disable App execution aliases for python/python3 (Settings > Apps > Advanced app settings).
  3. Remove old venv and recreate from the new interpreter:

       Remove-Item -Recurse -Force .venv
       py -3.13 -m venv .venv
       .\.venv\Scripts\Activate.ps1
       python -m pip install -U pip
       pip install -e ".[build]"

  4. Re-run: .\scripts\build_deploy_windows.ps1
"@
}

if (-not $hasLibsDir -or -not $libFile) {
    throw @"
[deploy] Python development files missing (expected $libsDir\python3*.lib).

  base_prefix: $basePrefix

Use a full python.org installer (not embeddable-only) and recreate .venv.
"@
}

Write-Host "[deploy] Python OK for Nuitka ($libFile)"
