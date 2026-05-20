#!/usr/bin/env bash
# Validate packaging scripts; build .deb from deploy/ (does not bump version — use build.sh deb patch for releases).
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
if [[ ! -d "${DEPLOY}" ]] || ! find "${DEPLOY}" -maxdepth 3 -type f -executable ! -name '*.so' 2>/dev/null | grep -q .; then
  echo "No deploy/ — running ./scripts/build_deploy_linux.sh..."
  "${ROOT}/scripts/build_deploy_linux.sh"
fi

echo "== Building .deb from ${DEPLOY} =="
./scripts/build_deb.sh "${DEPLOY}"
ls -la "${ROOT}/dist/"*.deb 2>/dev/null || true
echo "OK: .deb built"
