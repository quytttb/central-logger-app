#!/usr/bin/env bash
# Build entry point: .deb (Linux) or validate MSI script (Windows).
# Usage: ./scripts/build.sh deb
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="${1:-}"

case "${CMD}" in
  deb)
    if [[ ! -x "${ROOT}/deploy/central-logger" ]]; then
      echo "No deploy/ — running build_deploy_venv.sh (Nuitka alternative)..."
      "${ROOT}/scripts/build_deploy_venv.sh"
    fi
    "${ROOT}/scripts/build_deb.sh" "${ROOT}/deploy"
    ;;
  deploy-venv)
    "${ROOT}/scripts/build_deploy_venv.sh"
    ;;
  deploy-nuitka)
    uv run pyside6-rcc resources/resources.qrc -o src/central_logger/resources_rc.py
    uv pip install patchelf 2>/dev/null || true
    echo "Tip: use Python 3.13 and system patchelf if Nuitka fails on .a QML plugins."
    uv run pyside6-deploy src/central_logger/main.py -f
    ;;
  msi)
    echo "MSI must be built on Windows after deploy:" >&2
    echo "  .\\scripts\\build_msi.ps1 -DeployDir deploy" >&2
    exit 1
    ;;
  *)
    echo "Usage: $0 {deb|deploy-venv|deploy-nuitka|msi}" >&2
    exit 1
    ;;
esac
