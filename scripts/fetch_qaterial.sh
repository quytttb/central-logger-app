#!/usr/bin/env bash
# Clone Qaterial (Qt 6, master) into vendor/Qaterial for local CMake builds.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/vendor/Qaterial"
mkdir -p "$ROOT/vendor"
if [[ -d "$DEST/.git" ]]; then
  echo "Qaterial already present: $DEST"
  exit 0
fi
git clone --depth 1 https://github.com/OlivierLDff/Qaterial.git "$DEST"
echo "Cloned Qaterial to $DEST. Next: run scripts/build_qaterial.sh (requires cmake, compiler)."
