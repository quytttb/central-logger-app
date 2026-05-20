"""Tests for native lib path helpers (no DLL required on Linux CI)."""

from __future__ import annotations

import sys

from central_logger.utils import native_libs


def test_zbar_windows_dir_dev_layout():
    root = native_libs.project_root()
    expected = root / "resources" / "native" / "windows"
    if not getattr(sys, "frozen", False):
        assert native_libs.zbar_windows_dir() == expected


def test_qr_available_on_linux_without_bundle():
    if sys.platform == "win32":
        return
    # CI Linux: pyzbar may or may not be installed; path helper must not crash.
    reason = native_libs.qr_scan_unavailable_reason()
    assert isinstance(reason, str)
    _ = native_libs.ensure_zbar_loaded()
