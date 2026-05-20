"""Pinned ZBar Windows DLL manifest (no network)."""

from __future__ import annotations

import json
from pathlib import Path

_MANIFEST = (
    Path(__file__).resolve().parents[1] / "resources" / "native" / "windows" / "zbar-dlls.manifest.json"
)


def test_zbar_manifest_lists_required_dlls():
    data = json.loads(_MANIFEST.read_text(encoding="utf-8"))
    names = {f["name"] for f in data["files"]}
    assert "libzbar-64.dll" in names
    assert "libiconv.dll" in names
    for entry in data["files"]:
        assert len(entry["sha256"]) == 64
        assert entry["url"].startswith("https://github.com/NaturalHistoryMuseum/barcode-reader-dlls/")
