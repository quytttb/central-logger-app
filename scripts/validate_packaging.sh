#!/usr/bin/env bash
# Validate packaging scripts; build .deb only when deploy/ exists (post pyside6-deploy).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

echo "== Syntax check =="
bash -n scripts/build_deb.sh
test -f packaging/windows/Product.wxs

if [[ -f scripts/build_msi.ps1 ]]; then
  echo "build_msi.ps1 present (run on Windows with WiX after deploy)"
fi

DEPLOY="${ROOT}/deploy"
if [[ ! -d "${DEPLOY}" ]] || [[ ! -x "${DEPLOY}/central-logger" ]]; then
  echo "No deploy/ — creating venv deploy (./scripts/build_deploy_venv.sh)..."
  "${ROOT}/scripts/build_deploy_venv.sh"
fi

echo "== Building .deb from ${DEPLOY} =="
./scripts/build_deb.sh "${DEPLOY}"
ls -la "${ROOT}/dist/"*.deb 2>/dev/null || true
echo "OK: .deb built"
