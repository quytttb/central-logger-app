#!/usr/bin/env bash
# Create deploy/ for .deb when pyside6-deploy/Nuitka is unavailable or fails.
# Produces a self-contained venv + launcher (larger than Nuitka, but reliable on Linux).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY="${ROOT}/deploy"
VENV="${DEPLOY}/.venv"

echo "== Compile QRC =="
uv run pyside6-rcc resources/resources.qrc -o src/central_logger/resources_rc.py

echo "== Fresh deploy venv =="
rm -rf "${DEPLOY}"
mkdir -p "${DEPLOY}"
uv venv "${VENV}" --python 3.13 2>/dev/null || uv venv "${VENV}"
# shellcheck source=/dev/null
source "${VENV}/bin/activate"
uv pip install "${ROOT}"
deactivate

echo "== Bundle resources + launcher =="
cp -a "${ROOT}/resources" "${DEPLOY}/resources"
cp -a "${ROOT}/src/central_logger/ui" "${DEPLOY}/ui"

cat > "${DEPLOY}/central-logger" <<'EOF'
#!/bin/sh
ROOT="$(cd "$(dirname "$0")" && pwd)"
export CENTRAL_LOGGER_APP_ROOT="${ROOT}"
export QT_QUICK_CONTROLS_CONF="${ROOT}/resources/qtquickcontrols2.conf"
export QT_SCALE_FACTOR_ROUNDING_POLICY="${PassThrough:-PassThrough}"
exec "${ROOT}/.venv/bin/python" -m central_logger.main "$@"
EOF
chmod 755 "${DEPLOY}/central-logger"

echo "Deploy ready: ${DEPLOY}/central-logger"
du -sh "${DEPLOY}"
