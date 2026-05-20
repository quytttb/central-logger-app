#!/usr/bin/env bash
# Build a .deb from a Nuitka/pyside6-deploy output directory.
# Usage: ./scripts/build_deb.sh [DEPLOY_DIR] [VERSION]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_DIR="${1:-${ROOT}/deploy}"
VERSION="${2:-$(python3 -c "import tomllib; print(tomllib.load(open('${ROOT}/pyproject.toml','rb'))['project']['version'])")}"
PKG_NAME="central-logger-app"
ARCH="amd64"
STAGING="${ROOT}/dist/deb-staging"
OUTPUT="${ROOT}/dist/${PKG_NAME}_${VERSION}_${ARCH}.deb"

if [[ ! -d "${DEPLOY_DIR}" ]]; then
  echo "Deploy directory not found: ${DEPLOY_DIR}" >&2
  echo "Run pyside6-deploy first (see README)." >&2
  exit 1
fi

BIN="$(find "${DEPLOY_DIR}" -maxdepth 2 -type f -executable \( -name 'CentralLogger' -o -name 'central_logger*' -o -name '*.bin' \) 2>/dev/null | head -1)"
if [[ -z "${BIN}" ]]; then
  BIN="$(find "${DEPLOY_DIR}" -maxdepth 3 -type f -perm -111 ! -name '*.so' ! -name '*.dll' 2>/dev/null | head -1)"
fi
if [[ -z "${BIN}" ]]; then
  echo "Could not find executable in ${DEPLOY_DIR}" >&2
  exit 1
fi

rm -rf "${STAGING}"
mkdir -p "${STAGING}/DEBIAN" "${STAGING}/opt/central-logger" "${STAGING}/usr/bin" "${STAGING}/usr/share/applications"

cp -a "${DEPLOY_DIR}/." "${STAGING}/opt/central-logger/"
EXE_NAME="$(basename "${BIN}")"

cat > "${STAGING}/usr/bin/central-logger" <<EOF
#!/bin/sh
exec /opt/central-logger/${EXE_NAME} "\$@"
EOF
chmod 755 "${STAGING}/usr/bin/central-logger"

ICON="${ROOT}/resources/images"
DESKTOP_ICON=""
if [[ -f "${ICON}/logo.svg" ]]; then
  DESKTOP_ICON="/opt/central-logger/resources/images/logo.svg"
fi

cat > "${STAGING}/usr/share/applications/central-logger.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Central Logger
Comment=Central management for Modbus TCP Data Loggers
Exec=central-logger
Icon=${DESKTOP_ICON:-central-logger}
Terminal=false
Categories=Utility;
EOF

cat > "${STAGING}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: libzbar0, libxkbcommon0, libegl1, libgl1, libfontconfig1, libdbus-1-3
Maintainer: Central Logger Team <dev@local>
Description: Central Logger App — PySide6 desktop client
EOF

mkdir -p "${ROOT}/dist"
dpkg-deb --build --root-owner-group "${STAGING}" "${OUTPUT}"
echo "Built ${OUTPUT}"
