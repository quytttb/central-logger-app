#!/usr/bin/env bash
# Deploy / release entry point: git tag + push → GitHub Actions Release.
#   ./scripts/deploy.sh
#   ./scripts/deploy.sh release patch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

BUMP_SCRIPT="${ROOT}/scripts/bump_version.py"
REMOTE="${DEPLOY_REMOTE:-origin}"

_ensure_repo() {
  if [[ ! -f "${ROOT}/pyproject.toml" ]]; then
    echo "Chạy script từ root repo (thiếu pyproject.toml)." >&2
    exit 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "git không có trên PATH." >&2
    exit 1
  fi
}

_run_bump() {
  local level="$1"
  case "${level}" in
    major|minor|patch) ;;
    *)
      echo "Invalid bump level: ${level}" >&2
      return 1
      ;;
  esac
  if command -v uv >/dev/null 2>&1; then
    uv run python "${BUMP_SCRIPT}" bump "${level}"
  else
    python3 "${BUMP_SCRIPT}" bump "${level}"
  fi
}

_current_version() {
  if command -v uv >/dev/null 2>&1; then
    uv run python "${BUMP_SCRIPT}" show 2>/dev/null || echo "?"
  else
    python3 "${BUMP_SCRIPT}" show 2>/dev/null || echo "?"
  fi
}

_tag_name() {
  echo "v$(_current_version)"
}

_git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?"
}

_confirm() {
  local prompt="$1"
  local answer
  read -rp "${prompt} [y/N]: " answer
  [[ "${answer}" =~ ^[Yy]$ ]]
}

# Chỉ cảnh báo file lạ — pyproject.toml / uv.lock sẽ commit trong bước release.
_git_unexpected_dirty_warning() {
  local dirty line path unexpected=""
  dirty="$(git status --porcelain 2>/dev/null)" || return 0
  [[ -z "${dirty}" ]] && return 0
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    path="${line##* }"
    if [[ "${path}" == *" -> "* ]]; then
      path="${path##* -> }"
    fi
    case "${path}" in
      pyproject.toml | uv.lock) continue ;;
      *) unexpected+="${line}"$'\n' ;;
    esac
  done <<< "${dirty}"
  [[ -z "${unexpected}" ]] && return 0
  echo "⚠ Còn thay đổi chưa commit (ngoài version / uv.lock):"
  printf '%s' "${unexpected}" | sed 's/^/    /'
}

_stage_release_files() {
  git add pyproject.toml
  if [[ -f "${ROOT}/uv.lock" ]]; then
    git add uv.lock
  fi
}

_tag_exists() {
  local tag="$1"
  git rev-parse "${tag}" >/dev/null 2>&1
}

_github_urls() {
  local url
  url="$(git remote get-url "${REMOTE}" 2>/dev/null || true)"
  if [[ "${url}" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]%.git}"
    echo "  Actions:  https://github.com/${owner}/${repo}/actions/workflows/build-release.yml"
    echo "  Releases: https://github.com/${owner}/${repo}/releases"
  fi
}

_prompt_bump() {
  local ver="$(_current_version)"
  echo ""
  echo "Chọn mức bump — hiện tại: ${ver}"
  echo "  1) PATCH  — bug fixes (0.0.X)"
  echo "  2) MINOR  — new features (0.X.0)"
  echo "  3) MAJOR  — breaking change (X.0.0)"
  echo "  0) Cancel"
  echo ""
  local choice
  read -rp "Select bump [0-3]: " choice
  case "${choice}" in
    1) _run_bump patch ;;
    2) _run_bump minor ;;
    3) _run_bump major ;;
    0) echo "Cancelled."; return 1 ;;
    *) echo "Invalid choice." >&2; return 1 ;;
  esac
}

_do_bump() {
  if [[ $# -eq 0 ]]; then
    _prompt_bump || return 1
  else
    _run_bump "$1"
  fi
}

_do_commit() {
  local ver tag msg
  ver="$(_current_version)"
  tag="$(_tag_name)"
  msg="chore: release ${tag}"
  _git_unexpected_dirty_warning
  if git diff --quiet -- pyproject.toml uv.lock 2>/dev/null && \
     git diff --cached --quiet -- pyproject.toml uv.lock 2>/dev/null; then
    echo "pyproject.toml / uv.lock không có thay đổi — bỏ qua commit."
    return 0
  fi
  _stage_release_files
  if _confirm "Commit pyproject.toml (+ uv.lock nếu đổi) với message: ${msg}?"; then
    git commit -m "${msg}"
    echo "Đã commit."
  else
    echo "Đã stage pyproject.toml / uv.lock; chưa commit."
  fi
}

_do_tag() {
  local tag ver
  ver="$(_current_version)"
  tag="v${ver}"
  if _tag_exists "${tag}"; then
    echo "Tag ${tag} đã tồn tại." >&2
    return 1
  fi
  _git_unexpected_dirty_warning
  if _confirm "Tạo annotated tag ${tag}?"; then
    git tag -a "${tag}" -m "Release ${tag}"
    echo "Đã tạo tag ${tag}"
  fi
}

_do_push_tag() {
  local tag
  tag="$(_tag_name)"
  if ! _tag_exists "${tag}"; then
    echo "Tag local ${tag} chưa có. Chạy option 4 hoặc: $0 tag" >&2
    return 1
  fi
  echo "Sẽ push: git push ${REMOTE} ${tag}"
  _github_urls
  if _confirm "Push tag ${tag} lên ${REMOTE}? (kích hoạt workflow Build Release)"; then
    git push "${REMOTE}" "${tag}"
    echo "Đã push ${tag}. Xem tiến trình build trên GitHub Actions."
    _github_urls
  fi
}

_do_release() {
  local level="${1:-}"
  if [[ -z "${level}" ]]; then
    _prompt_bump || return 1
  else
    _run_bump "${level}"
  fi
  local ver tag
  ver="$(_current_version)"
  tag="v${ver}"
  echo ""
  echo "Phát hành: version ${ver} → tag ${tag} → push ${REMOTE}"
  _git_unexpected_dirty_warning
  if ! _confirm "Tiếp tục (commit pyproject.toml + uv.lock → tag → push)?"; then
    echo "Cancelled."
    return 1
  fi
  _stage_release_files
  git commit -m "chore: release ${tag}" || {
    echo "Commit thất bại (có thể không có thay đổi?)." >&2
    return 1
  }
  if _tag_exists "${tag}"; then
    echo "Tag ${tag} đã tồn tại." >&2
    return 1
  fi
  git tag -a "${tag}" -m "Release ${tag}"
  echo "Push ${tag}..."
  git push "${REMOTE}" HEAD
  git push "${REMOTE}" "${tag}"
  echo "Hoàn tất. GitHub Actions sẽ build .deb + .msi và tạo Release."
  _github_urls
}

_do_status() {
  local ver tag branch
  ver="$(_current_version)"
  tag="$(_tag_name)"
  branch="$(_git_branch)"
  echo ""
  echo "Version (pyproject): ${ver}"
  echo "Tag (expected):      ${tag}"
  echo "Branch:              ${branch}"
  echo "Remote:              ${REMOTE}"
  echo ""
  if _tag_exists "${tag}"; then
    echo "Tag local ${tag}: có ($(git rev-parse --short "${tag}"))"
  else
    echo "Tag local ${tag}: chưa có"
  fi
  if git ls-remote --tags "${REMOTE}" "${tag}" 2>/dev/null | grep -q .; then
    echo "Tag trên ${REMOTE}: có"
  else
    echo "Tag trên ${REMOTE}: chưa có"
  fi
  echo ""
  git status -sb
  echo ""
  echo "Build local: ./scripts/build.sh"
  _github_urls
}

_show_cheatsheet() {
  local ver tag
  ver="$(_current_version)"
  tag="$(_tag_name)"
  cat <<EOF

--- Cheat sheet (git release) ---

  Version hiện tại: ${ver}  →  tag ${tag}

  # Phát hành đầy đủ (tương đương menu option 1)
  ./scripts/deploy.sh release patch

  # Từng bước
  uv run python scripts/bump_version.py bump patch
  git add pyproject.toml && git commit -m "chore: release ${tag}"
  git tag -a ${tag} -m "Release ${tag}"
  git push ${REMOTE} HEAD
  git push ${REMOTE} ${tag}

  # Re-build Release khi tag đã có (không cần git)
  GitHub → Actions → Release → Run workflow → nhập ${tag}

  Build gói local (không qua GitHub):
  ./scripts/build.sh

EOF
}

_show_menu() {
  local ver tag branch
  ver="$(_current_version)"
  tag="$(_tag_name)"
  branch="$(_git_branch)"
  echo ""
  echo "========================================"
  echo "  Central Logger — Deploy / Release"
  echo "  Version: ${ver}  →  tag ${tag}"
  echo "  Branch: ${branch}    Remote: ${REMOTE}"
  echo "========================================"
  echo ""
  echo "  1) Phát hành đầy đủ — bump → commit → tag → push ${REMOTE}"
  echo "  2) Chỉ bump version (pyproject.toml)"
  echo "  3) Commit pyproject.toml"
  echo "  4) Tạo git tag annotated v{version}"
  echo "  5) Push tag lên ${REMOTE} (kích hoạt workflow Build Release)"
  echo "  6) Trạng thái — version, tag, git status"
  echo "  7) Cheat sheet lệnh git (chỉ in)"
  echo "  0) Thoát"
  echo ""
  local choice
  read -rp "Select option [0-7]: " choice
  case "${choice}" in
    1) _do_release ;;
    2) _prompt_bump ;;
    3) _do_commit ;;
    4) _do_tag ;;
    5) _do_push_tag ;;
    6) _do_status ;;
    7) _show_cheatsheet ;;
    0) echo "Bye." ;;
    *) echo "Invalid choice." >&2; return 1 ;;
  esac
}

_ensure_repo

if [[ $# -gt 0 ]]; then
  CMD="${1}"
  ARG="${2:-}"
  case "${CMD}" in
    release)
      if [[ -z "${ARG}" ]]; then
        _do_release
      else
        _do_release "${ARG}"
      fi
      ;;
    bump)
      if [[ -z "${ARG}" ]]; then
        echo "Usage: $0 bump {major|minor|patch}" >&2
        exit 1
      fi
      _do_bump "${ARG}"
      ;;
    commit) _do_commit ;;
    tag) _do_tag ;;
    push-tag) _do_push_tag ;;
    status) _do_status ;;
    cheatsheet) _show_cheatsheet ;;
    *)
      echo "Usage: $0  OR  $0 {release|bump|commit|tag|push-tag|status|cheatsheet} [patch|minor|major]" >&2
      exit 1
      ;;
  esac
  exit 0
fi

_show_menu
