#!/usr/bin/env bash
# Build a .deb from deploy/ (venv or Nuitka output).
# Version is read from pyproject.toml (bump via ./scripts/build.sh deb patch|minor|major).
# Usage: ./scripts/build_deb.sh [DEPLOY_DIR]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_DIR="${1:-${ROOT}/deploy}"
VERSION="$(python3 -c "import tomllib; print(tomllib.load(open('${ROOT}/pyproject.toml','rb'))['project']['version'])")"
PKG_NAME="central-logger-app"
ARCH="amd64"
STAGING="${ROOT}/dist/deb-staging"
OUTPUT="${ROOT}/dist/${PKG_NAME}_${VERSION}_${ARCH}.deb"
LOGO_SVG="${ROOT}/resources/images/4M Technologies Blue.svg"

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
mkdir -p "${STAGING}/DEBIAN" \
  "${STAGING}/opt/central-logger" \
  "${STAGING}/usr/bin" \
  "${STAGING}/usr/share/applications" \
  "${STAGING}/usr/share/icons/hicolor/scalable/apps" \
  "${STAGING}/usr/share/icons/hicolor/256x256/apps"

cp -a "${DEPLOY_DIR}/." "${STAGING}/opt/central-logger/"
EXE_NAME="$(basename "${BIN}")"

cat > "${STAGING}/usr/bin/central-logger" <<EOF
#!/bin/sh
exec /opt/central-logger/${EXE_NAME} "\$@"
EOF
chmod 755 "${STAGING}/usr/bin/central-logger"

if [[ -f "${LOGO_SVG}" ]]; then
  cp "${LOGO_SVG}" "${STAGING}/usr/share/icons/hicolor/scalable/apps/central-logger.svg"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 256 -h 256 "${LOGO_SVG}" \
      -o "${STAGING}/usr/share/icons/hicolor/256x256/apps/central-logger.png"
  else
    echo "[build_deb] WARNING: rsvg-convert not found; skipping 256x256 menu icon PNG." >&2
    echo "[build_deb]          Install: sudo apt install librsvg2-bin" >&2
  fi
fi

cat > "${STAGING}/usr/share/applications/central-logger.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Central Logger
Comment=Central management for Modbus TCP Data Loggers
Exec=central-logger
Icon=central-logger
StartupWMClass=central-logger
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
Description: Central Logger App - PySide6 desktop client
EOF

cat > "${STAGING}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor || true
fi
EOF
chmod 755 "${STAGING}/DEBIAN/postinst"

mkdir -p "${ROOT}/dist"
dpkg-deb --build --root-owner-group "${STAGING}" "${OUTPUT}"
echo "Built ${OUTPUT}"
