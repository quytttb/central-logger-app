# Deploy / release entry point: git tag + push -> GitHub Actions Release.
#   .\scripts\deploy.ps1
#   .\scripts\deploy.ps1 release patch
param(
    [Parameter(Position = 0)]
    [ValidateSet("release", "bump", "commit", "tag", "push-tag", "status", "cheatsheet", "")]
    [string]$Command = "",

    [Parameter(Position = 1)]
    [ValidateSet("major", "minor", "patch", "")]
    [string]$Bump = "",

    [string]$Remote = $(if ($env:DEPLOY_REMOTE) { $env:DEPLOY_REMOTE } else { "origin" })
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root
$BumpScript = Join-Path $Root "scripts\bump_version.py"

function Get-Python {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $py) { throw "python not found on PATH" }
    return $py
}

function Get-ProjectVersion {
    $py = Get-Python
    $v = & $py.Source $BumpScript show 2>$null
    if ($LASTEXITCODE -ne 0) { return "?" }
    return $v.Trim()
}

function Get-TagName {
    return "v$(Get-ProjectVersion)"
}

function Get-GitBranch {
    try {
        return (git rev-parse --abbrev-ref HEAD).Trim()
    } catch {
        return "?"
    }
}

function Test-Confirm {
    param([string]$Prompt)
    $answer = Read-Host "$Prompt [y/N]"
    return $answer -match '^[Yy]$'
}

function Show-UnexpectedDirtyWarning {
    $status = git status --porcelain 2>$null
    if (-not $status) { return }
    $unexpected = @()
    foreach ($line in $status) {
        $path = ($line -replace '^..\s+', '').Trim()
        if ($path -match ' -> ') {
            $path = ($path -split ' -> ', 2)[1].Trim()
        }
        if ($path -in @('pyproject.toml', 'uv.lock')) { continue }
        $unexpected += $line
    }
    if ($unexpected.Count -eq 0) { return }
    Write-Host "Warning: con thay doi chua commit (ngoai version / uv.lock):" -ForegroundColor Yellow
    $unexpected | ForEach-Object { Write-Host "    $_" }
}

function Add-ReleaseFiles {
    git add pyproject.toml
    $lock = Join-Path $Root "uv.lock"
    if (Test-Path $lock) {
        git add uv.lock
    }
}

function Test-TagExists {
    param([string]$Tag)
    git rev-parse $Tag 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

function Show-GitHubUrls {
    try {
        $url = (git remote get-url $Remote 2>$null).Trim()
    } catch {
        return
    }
    if ($url -match 'github\.com[:/]([^/]+)/([^/.]+)') {
        $owner = $Matches[1]
        $repo = $Matches[2] -replace '\.git$', ''
        Write-Host "  Actions:  https://github.com/$owner/$repo/actions/workflows/build-release.yml"
        Write-Host "  Releases: https://github.com/$owner/$repo/releases"
    }
}

function Invoke-BumpVersion {
    param([ValidateSet("major", "minor", "patch")][string]$Level)
    $py = Get-Python
    Write-Host "== Bump version ($Level) =="
    & $py.Source $BumpScript bump $Level
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Read-BumpChoice {
    $ver = Get-ProjectVersion
    Write-Host ""
    Write-Host "Chon muc bump — hien tai: $ver"
    Write-Host "  1) PATCH  — bug fixes (0.0.X)"
    Write-Host "  2) MINOR  — new features (0.X.0)"
    Write-Host "  3) MAJOR  — breaking change (X.0.0)"
    Write-Host "  0) Cancel"
    Write-Host ""
    switch (Read-Host "Select bump [0-3]") {
        "1" { return "patch" }
        "2" { return "minor" }
        "3" { return "major" }
        "0" { return $null }
        default { Write-Error "Invalid choice." }
    }
}

function Invoke-DoBump {
    param([string]$Level)
    if (-not $Level) {
        $Level = Read-BumpChoice
        if (-not $Level) { return }
    }
    Invoke-BumpVersion -Level $Level
}

function Invoke-DoCommit {
    $ver = Get-ProjectVersion
    $tag = "v$ver"
    $msg = "chore: release $tag"
    Show-UnexpectedDirtyWarning
    git diff --quiet -- pyproject.toml 2>$null
    $unstaged = $LASTEXITCODE -eq 0
    git diff --cached --quiet -- pyproject.toml 2>$null
    $unstagedCached = $LASTEXITCODE -eq 0
    if ($unstaged -and $unstagedCached) {
        Write-Host "pyproject.toml khong co thay doi — bo qua commit."
        return
    }
    Add-ReleaseFiles
    if (Test-Confirm "Commit pyproject.toml (+ uv.lock neu doi) voi message: $msg") {
        git commit -m $msg
        Write-Host "Da commit."
    } else {
        Write-Host "Da stage pyproject.toml; chua commit."
    }
}

function Invoke-DoTag {
    $ver = Get-ProjectVersion
    $tag = "v$ver"
    if (Test-TagExists $tag) {
        throw "Tag $tag da ton tai."
    }
    Show-UnexpectedDirtyWarning
    if (Test-Confirm "Tao annotated tag $tag") {
        git tag -a $tag -m "Release $tag"
        Write-Host "Da tao tag $tag"
    }
}

function Invoke-DoPushTag {
    $tag = Get-TagName
    if (-not (Test-TagExists $tag)) {
        throw "Tag local $tag chua co. Chay option 4 hoac: .\scripts\deploy.ps1 tag"
    }
    Write-Host "Se push: git push $Remote $tag"
    Show-GitHubUrls
    if (Test-Confirm "Push tag $tag len $Remote? (kich hoat workflow Build Release)") {
        git push $Remote $tag
        Write-Host "Da push $tag. Xem tien trinh build tren GitHub Actions."
        Show-GitHubUrls
    }
}

function Invoke-DoRelease {
    param([string]$Level)
    if (-not $Level) {
        $Level = Read-BumpChoice
        if (-not $Level) { return }
    } else {
        Invoke-BumpVersion -Level $Level
    }
    $ver = Get-ProjectVersion
    $tag = "v$ver"
    Write-Host ""
    Write-Host "Phat hanh: version $ver -> tag $tag -> push $Remote"
    Show-UnexpectedDirtyWarning
    if (-not (Test-Confirm "Tiep tuc (commit pyproject.toml + uv.lock -> tag -> push)?")) {
        Write-Host "Cancelled."
        return
    }
    Add-ReleaseFiles
    git commit -m "chore: release $tag"
    if ($LASTEXITCODE -ne 0) {
        throw "Commit that bai (co the khong co thay doi?)."
    }
    if (Test-TagExists $tag) {
        throw "Tag $tag da ton tai."
    }
    git tag -a $tag -m "Release $tag"
    Write-Host "Push $tag..."
    git push $Remote HEAD
    git push $Remote $tag
    Write-Host "Hoan tat. GitHub Actions se build .deb + .msi va tao Release."
    Show-GitHubUrls
}

function Show-Status {
    $ver = Get-ProjectVersion
    $tag = Get-TagName
    $branch = Get-GitBranch
    Write-Host ""
    Write-Host "Version (pyproject): $ver"
    Write-Host "Tag (expected):      $tag"
    Write-Host "Branch:              $branch"
    Write-Host "Remote:              $Remote"
    Write-Host ""
    if (Test-TagExists $tag) {
        $short = (git rev-parse --short $tag).Trim()
        Write-Host "Tag local $tag : co ($short)"
    } else {
        Write-Host "Tag local $tag : chua co"
    }
    $remoteTag = git ls-remote --tags $Remote $tag 2>$null
    if ($remoteTag) {
        Write-Host "Tag tren $Remote : co"
    } else {
        Write-Host "Tag tren $Remote : chua co"
    }
    Write-Host ""
    git status -sb
    Write-Host ""
    Write-Host "Build local: .\scripts\build.ps1"
    Show-GitHubUrls
}

function Show-Cheatsheet {
    $ver = Get-ProjectVersion
    $tag = Get-TagName
    Write-Host @"

--- Cheat sheet (git release) ---

  Version hien tai: $ver  ->  tag $tag

  # Phat hanh day du
  .\scripts\deploy.ps1 release patch

  # Tung buoc
  python scripts\bump_version.py bump patch
  git add pyproject.toml; git commit -m "chore: release $tag"
  git tag -a $tag -m "Release $tag"
  git push $Remote HEAD
  git push $Remote $tag

  # Re-build Release (tag da co)
  GitHub -> Actions -> Release -> Run workflow -> nhap $tag

  Build goi local:
  .\scripts\build.ps1

"@
}

function Show-DeployMenu {
    $ver = Get-ProjectVersion
    $tag = Get-TagName
    $branch = Get-GitBranch
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  Central Logger — Deploy / Release"
    Write-Host "  Version: $ver  ->  tag $tag"
    Write-Host "  Branch: $branch    Remote: $Remote"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "  1) Phat hanh day du — bump -> commit -> tag -> push $Remote"
    Write-Host "  2) Chi bump version (pyproject.toml)"
    Write-Host "  3) Commit pyproject.toml"
    Write-Host "  4) Tao git tag annotated v{version}"
    Write-Host "  5) Push tag len $Remote (kich hoat workflow Build Release)"
    Write-Host "  6) Trang thai — version, tag, git status"
    Write-Host "  7) Cheat sheet lenh git (chi in)"
    Write-Host "  0) Thoat"
    Write-Host ""
    switch (Read-Host "Select option [0-7]") {
        "1" { Invoke-DoRelease }
        "2" { Invoke-DoBump }
        "3" { Invoke-DoCommit }
        "4" { Invoke-DoTag }
        "5" { Invoke-DoPushTag }
        "6" { Show-Status }
        "7" { Show-Cheatsheet }
        "0" { Write-Host "Bye." }
        default { Write-Error "Invalid choice." }
    }
}

if (-not (Test-Path (Join-Path $Root "pyproject.toml"))) {
    throw "Chay script tu root repo (thieu pyproject.toml)."
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git khong co tren PATH."
}

if ($Command) {
    switch ($Command) {
        "release" {
            if ($Bump) { Invoke-DoRelease -Level $Bump } else { Invoke-DoRelease }
        }
        "bump" {
            if (-not $Bump) {
                Write-Host "Usage: .\scripts\deploy.ps1 bump {major|minor|patch}"
                exit 1
            }
            Invoke-DoBump -Level $Bump
        }
        "commit" { Invoke-DoCommit }
        "tag" { Invoke-DoTag }
        "push-tag" { Invoke-DoPushTag }
        "status" { Show-Status }
        "cheatsheet" { Show-Cheatsheet }
    }
    exit 0
}

Show-DeployMenu
