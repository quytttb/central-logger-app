#!/usr/bin/env bash
# Configure, build, and install Qaterial into vendor/qaterial-install (shared lib).
# Requires: cmake, ninja (recommended), C++17 toolchain, Qt matching PySide6.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/Qaterial"
BUILD="$ROOT/vendor/qaterial-build"
INSTALL="$ROOT/vendor/qaterial-install"

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found. Install cmake, then re-run." >&2
  exit 1
fi
if [[ ! -f "$SRC/CMakeLists.txt" ]]; then
  echo "Run scripts/fetch_qaterial.sh first (missing $SRC)." >&2
  exit 1
fi

PYTHON="${ROOT}/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  PYTHON="python3"
fi

# Prefer explicit Qt6 prefix (must contain lib/cmake/Qt6/Qt6Config.cmake).
# PySide6 wheels usually do NOT ship CMake files — use distro Qt6 dev (e.g. /usr).
if [[ -n "${CMAKE_PREFIX_PATH:-}" ]]; then
  QT_PREFIX="${CMAKE_PREFIX_PATH}"
elif [[ -f "/usr/lib/x86_64-linux-gnu/cmake/Qt6/Qt6Config.cmake" ]]; then
  QT_PREFIX="/usr"
else
  QT_PREFIX="$("$PYTHON" - <<'PY'
from PySide6.QtCore import QLibraryInfo
print(QLibraryInfo.path(QLibraryInfo.LibraryPath.PrefixPath))
PY
)"
fi

cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
  -DCMAKE_INSTALL_PREFIX="$INSTALL" \
  -DQATERIAL_BUILD_SHARED=ON \
  -DQATERIAL_ENABLE_INSTALL=ON \
  -DQATERIAL_MAIN_PROJECT=OFF

cmake --build "$BUILD" -j"$(nproc 2>/dev/null || echo 4)"
cmake --install "$BUILD" --prefix "$INSTALL"

# Qt resolves ``import Qaterial.Icons.Impl`` as .../Qaterial/Icons/Impl/qmldir, but CMake
# emits the module under Icons/ — mirror what ``central_logger.qml_import_paths`` does at runtime.
ICONS_IMPL="$BUILD/qml/Qaterial/Icons/Impl"
mkdir -p "$ICONS_IMPL"
printf '%s\n' "module Qaterial.Icons.Impl" "IconsImpl 1.0 IconsImpl.qml" >"$ICONS_IMPL/qmldir"
ln -sf ../Generated/IconsImpl.qml "$ICONS_IMPL/IconsImpl.qml"

echo "Installed under $INSTALL — addImportPath picks up lib/qml automatically when present."
