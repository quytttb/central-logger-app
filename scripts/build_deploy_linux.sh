#!/usr/bin/env bash
# Linux deploy via pyside6-deploy / Nuitka (standalone → deploy/).
# Mirror of scripts/build_deploy_windows.ps1. Used by CI Release and ./scripts/build.sh deploy
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY="${ROOT}/deploy"
IGNORE_DIRS="src/central_logger/controllers,src/central_logger/db,src/central_logger/services,src/central_logger/utils,src/central_logger/viewmodels"

_publish_deploy_folder() {
  local dist="${DEPLOY}/CentralLogger.dist"

  if [[ ! -d "${dist}" ]]; then
    dist=""
  fi

  if [[ -z "${dist}" ]]; then
    if find "${DEPLOY}" -maxdepth 3 -type f -executable ! -name '*.so' 2>/dev/null | grep -q .; then
      return 0
    fi
    echo "Nuitka output folder not found (expected deploy/CentralLogger.dist or deploy/ executable)" >&2
    exit 1
  fi

  if [[ "${dist}" != "${DEPLOY}" ]]; then
    local staging="${ROOT}/_deploy_stage"
    rm -rf "${staging}"
    mkdir -p "${staging}"
    cp -a "${dist}/." "${staging}/"
    rm -rf "${DEPLOY}"
    mv "${staging}" "${DEPLOY}"
    rm -rf "${dist}" 2>/dev/null || true
  fi

  if [[ -f "${DEPLOY}/main.bin" && ! -f "${DEPLOY}/CentralLogger" ]]; then
    mv "${DEPLOY}/main.bin" "${DEPLOY}/CentralLogger"
  fi
  if [[ -f "${DEPLOY}/main" && ! -f "${DEPLOY}/CentralLogger" ]]; then
    mv "${DEPLOY}/main" "${DEPLOY}/CentralLogger"
  fi
}

cd "${ROOT}"

echo "== Compile Qt resources =="
uv run pyside6-rcc resources/resources.qrc -o src/central_logger/resources_rc.py

echo "== pyside6-deploy (Nuitka standalone) =="
uv pip install patchelf 2>/dev/null || true
uv run pyside6-deploy -c pysidedeploy.spec src/central_logger/main.py --mode standalone --force \
  --extra-ignore-dirs="${IGNORE_DIRS}"

_publish_deploy_folder

if ! find "${DEPLOY}" -maxdepth 3 -type f -executable ! -name '*.so' 2>/dev/null | grep -q .; then
  echo "Deploy failed: no executable under ${DEPLOY}" >&2
  exit 1
fi

echo "Deploy ready: ${DEPLOY}"
du -sh "${DEPLOY}"
