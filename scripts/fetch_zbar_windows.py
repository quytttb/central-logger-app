#!/usr/bin/env python3
"""Download and verify ZBar Windows DLLs (same manifest as stage_zbar_windows.ps1)."""

from __future__ import annotations

import hashlib
import json
import sys
import urllib.request
from pathlib import Path

_REPO = Path(__file__).resolve().parents[1]
_DEST = _REPO / "resources" / "native" / "windows"
_MANIFEST = _DEST / "zbar-dlls.manifest.json"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    if not _MANIFEST.is_file():
        print(f"Manifest missing: {_MANIFEST}", file=sys.stderr)
        return 1

    data = json.loads(_MANIFEST.read_text(encoding="utf-8"))
    _DEST.mkdir(parents=True, exist_ok=True)

    for entry in data["files"]:
        name = entry["name"]
        url = entry["url"]
        expected = entry["sha256"].lower()
        out = _DEST / name
        print(f"Downloading {name}...")
        urllib.request.urlretrieve(url, out)
        actual = _sha256(out)
        if actual != expected:
            out.unlink(missing_ok=True)
            print(f"SHA256 mismatch for {name}: expected {expected}, got {actual}", file=sys.stderr)
            return 1
        print(f"  OK {name}")

    print(f"Done: {_DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
