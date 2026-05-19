"""Locate and load bundled native libraries (Windows deploy)."""
from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

log = logging.getLogger(__name__)

# Relative to project root (dev) or next to executable (Nuitka standalone).
_ZBAR_SUBDIR = Path("native") / "windows"
_ZBAR_DLL_NAMES = ("libzbar-64.dll", "libiconv.dll")


def project_root() -> Path:
    """Repository / install root."""
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    # .../src/central_logger/utils/native_libs.py -> repo root
    return Path(__file__).resolve().parents[3]


def zbar_windows_dir() -> Path:
    """Directory that should contain libzbar-64.dll (and optionally libiconv.dll)."""
    root = project_root()
    if getattr(sys, "frozen", False):
        return root / _ZBAR_SUBDIR
    return root / "resources" / _ZBAR_SUBDIR


def ensure_zbar_loaded() -> bool:
    """Register ZBar DLL search path on Windows. No-op on Linux/macOS."""
    if sys.platform != "win32":
        return True

    dll_dir = zbar_windows_dir()
    if not dll_dir.is_dir():
        log.debug("ZBar bundle dir missing: %s", dll_dir)
        return False

    zbar_dll = dll_dir / "libzbar-64.dll"
    if not zbar_dll.is_file():
        log.debug("libzbar-64.dll not found in %s", dll_dir)
        return False

    try:
        if hasattr(os, "add_dll_directory"):
            os.add_dll_directory(str(dll_dir.resolve()))
        else:
            path = str(dll_dir.resolve())
            cur = os.environ.get("PATH", "")
            if path not in cur.split(";"):
                os.environ["PATH"] = path + ";" + cur
        log.debug("ZBar DLL directory registered: %s", dll_dir)
        return True
    except OSError as exc:
        log.warning("Failed to register ZBar DLL dir %s: %s", dll_dir, exc)
        return False


def is_qr_scan_available() -> bool:
    """True if pyzbar can run (deps + Windows DLL bundle when needed)."""
    if sys.platform == "win32" and not ensure_zbar_loaded():
        return False
    try:
        import pyzbar.pyzbar  # noqa: F401
        from PIL import Image  # noqa: F401
    except ImportError:
        return False
    return True


def qr_scan_unavailable_reason() -> str:
    if sys.platform == "win32":
        dll_dir = zbar_windows_dir()
        if not (dll_dir / "libzbar-64.dll").is_file():
            return (
                "QR scan needs ZBar DLLs in "
                f"{dll_dir} — see resources/native/windows/README.md"
            )
    try:
        import pyzbar.pyzbar  # noqa: F401
        from PIL import Image  # noqa: F401
    except ImportError:
        return "QR scan requires pyzbar and Pillow (reinstall the app package)."
    return "QR scan is not available."
