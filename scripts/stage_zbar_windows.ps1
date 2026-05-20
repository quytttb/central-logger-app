# Stage ZBar Windows DLLs into resources/native/windows (dev + Nuitka bundle).
#
# Default: download pinned DLLs from NaturalHistoryMuseum/barcode-reader-dlls (see manifest).
# Optional: copy from a local install with -Source.
#
#   .\scripts\stage_zbar_windows.ps1
#   .\scripts\stage_zbar_windows.ps1 -Source 'C:\Program Files\ZBar\bin'
#   .\scripts\stage_zbar_windows.ps1 -Force
#   .\scripts\stage_zbar_windows.ps1 -SkipQr   # no download, no QR in build

param(
    [string]$Source = "",
    [switch]$Force,
    [switch]$SkipQr
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Dest = Join-Path $RepoRoot "resources\native\windows"
$ManifestPath = Join-Path $Dest "zbar-dlls.manifest.json"
$Required = @("libzbar-64.dll", "libiconv.dll")

function Test-Staged {
    foreach ($name in $Required) {
        if (-not (Test-Path (Join-Path $Dest $name))) {
            return $false
        }
    }
    return $true
}

function Get-FileSha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function Assert-FileSha256 {
    param(
        [string]$Path,
        [string]$Expected
    )
    $actual = Get-FileSha256 -Path $Path
    if ($actual -ne $Expected.ToLowerInvariant()) {
        Remove-Item -Force -Path $Path -ErrorAction SilentlyContinue
        Write-Error "SHA256 mismatch for $(Split-Path -Leaf $Path): expected $Expected, got $actual"
    }
}

function Copy-FromSource {
    param([string]$SourceDir)
    if (-not (Test-Path $SourceDir)) {
        Write-Error @"
Source directory not found: $SourceDir

Use the folder that contains libzbar-64.dll, or omit -Source to download automatically:
  .\scripts\stage_zbar_windows.ps1
"@
    }
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    foreach ($name in $Required) {
        $src = Join-Path $SourceDir $name
        if (Test-Path $src) {
            Copy-Item -Force $src (Join-Path $Dest $name)
            Write-Host "Copied $name from $SourceDir"
        } else {
            Write-Warning "Missing $src (skip)"
        }
    }
    if (-not (Test-Path (Join-Path $Dest "libzbar-64.dll"))) {
        Write-Error "libzbar-64.dll is required in $Dest"
    }
}

function Download-FromManifest {
    if (-not (Test-Path $ManifestPath)) {
        Write-Error "Manifest not found: $ManifestPath"
    }
    $manifest = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null

    Write-Host "Downloading ZBar DLLs (release $($manifest.release))..."
    Write-Host "Source: $($manifest.source)"

    foreach ($entry in $manifest.files) {
        $out = Join-Path $Dest $entry.name
        Write-Host "  -> $($entry.name)"
        try {
            Invoke-WebRequest -Uri $entry.url -OutFile $out -UseBasicParsing
        } catch {
            Write-Error "Download failed for $($entry.name): $_"
        }
        Assert-FileSha256 -Path $out -Expected $entry.sha256
        Write-Host "     OK (sha256 verified)"
    }
}

if ($SkipQr) {
    Write-Host "SkipQr: ZBar DLLs not staged. QR scan will be unavailable in this build."
    exit 0
}

if ((Test-Staged) -and -not $Force -and [string]::IsNullOrWhiteSpace($Source)) {
    Write-Host "ZBar DLLs already present in $Dest (use -Force to re-download)."
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($Source)) {
    Copy-FromSource -SourceDir $Source
} else {
    Download-FromManifest
}

if (-not (Test-Staged)) {
    Write-Error "Staging incomplete: libzbar-64.dll and libiconv.dll required in $Dest"
}

Write-Host "Done. DLLs staged in $Dest"
Write-Host "Note: end users of a built deploy/ folder do not need a separate ZBar install."
Write-Host "      VC++ 2013 Redistributable (x64) may be required on some PCs — see resources/native/windows/README.md"
