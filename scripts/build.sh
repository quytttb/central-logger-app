#!/usr/bin/env bash
# Build entry point: interactive menu or non-interactive args.
#   ./scripts/build.sh
#   ./scripts/build.sh deb patch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

_current_version() {
  uv run python "${ROOT}/scripts/bump_version.py" show 2>/dev/null || echo "?"
}

_bump_version() {
  local level="$1"
  case "${level}" in
    major|minor|patch) ;;
    *)
      echo "Invalid bump level: ${level}" >&2
      return 1
      ;;
  esac
  echo "== Bump version (${level}) =="
  uv run python "${ROOT}/scripts/bump_version.py" bump "${level}"
}

_prompt_bump() {
  local ver="$(_current_version)"
  echo ""
  echo "Version bump (required for .deb release) — current: ${ver}"
  echo "  1) PATCH  — bug fixes (0.0.X)"
  echo "  2) MINOR  — new features (0.X.0)"
  echo "  3) MAJOR  — breaking change (X.0.0)"
  echo "  0) Cancel"
  echo ""
  local choice
  read -rp "Select bump [0-3]: " choice
  case "${choice}" in
    1) _bump_version patch ;;
    2) _bump_version minor ;;
    3) _bump_version major ;;
    0) echo "Cancelled."; return 1 ;;
    *) echo "Invalid choice." >&2; return 1 ;;
  esac
}

_has_deploy_executable() {
  find "${ROOT}/deploy" -maxdepth 3 -type f -executable ! -name '*.so' 2>/dev/null | grep -q .
}

_do_deb() {
  if [[ $# -eq 0 ]]; then
    _prompt_bump || return 1
  else
    _bump_version "$1"
  fi
  if ! _has_deploy_executable; then
    echo "No deploy/ — running build_deploy_linux.sh..."
    "${ROOT}/scripts/build_deploy_linux.sh"
  fi
  "${ROOT}/scripts/build_deb.sh" "${ROOT}/deploy"
}

_do_deploy() {
  "${ROOT}/scripts/build_deploy_linux.sh"
}

_show_menu() {
  local ver="$(_current_version)"
  echo ""
  echo "========================================"
  echo "  Central Logger — Build (Linux)"
  echo "  Current version: ${ver}"
  echo "========================================"
  echo ""
  echo "  1) Build .deb (Ubuntu package)"
  echo "  2) Build deploy/ only (Nuitka / pyside6-deploy)"
  echo "  0) Exit"
  echo ""
  local choice
  read -rp "Select option [0-2]: " choice
  case "${choice}" in
    1) _do_deb ;;
    2) _do_deploy ;;
    0) echo "Bye." ;;
    *) echo "Invalid choice." >&2; return 1 ;;
  esac
}

# Non-interactive: ./scripts/build.sh deb patch | deploy
if [[ $# -gt 0 ]]; then
  CMD="${1}"
  BUMP="${2:-}"
  case "${CMD}" in
    deb)
      if [[ -z "${BUMP}" ]]; then
        echo "Usage: $0 deb {major|minor|patch}" >&2
        echo "  Or run $0 without arguments for the interactive menu." >&2
        exit 1
      fi
      _do_deb "${BUMP}"
      ;;
    deploy|deploy-nuitka) _do_deploy ;;
    deploy-venv)
      echo "deploy-venv removed; use: $0 deploy" >&2
      exit 1
      ;;
    msi)
      echo "MSI: run .\\scripts\\build.ps1 on Windows." >&2
      exit 1
      ;;
    *)
      echo "Usage: $0  OR  $0 {deb major|minor|patch|deploy}" >&2
      exit 1
      ;;
  esac
  exit 0
fi

_show_menu
