#!/usr/bin/env python3
"""Resize resources/images/4M Technologies Blue.png to Freedesktop hicolor PNG sizes."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

_ROOT = Path(__file__).resolve().parents[1]
_SRC = _ROOT / "resources" / "images" / "4M Technologies Blue.png"
_OUT_DIR = _ROOT / "resources" / "images"
_SIZES = (16, 32, 48, 64, 128, 256, 512)


def main() -> int:
    if not _SRC.is_file():
        print(f"Source PNG not found: {_SRC}", file=sys.stderr)
        return 1

    img = Image.open(_SRC).convert("RGBA")
    for px in _SIZES:
        out = _OUT_DIR / f"central-logger-{px}.png"
        img.resize((px, px), Image.Resampling.LANCZOS).save(out, format="PNG", optimize=True)
        print(f"Wrote {out.relative_to(_ROOT)} ({px}x{px})")

    master = _OUT_DIR / "central-logger.png"
    img.resize((512, 512), Image.Resampling.LANCZOS).save(master, format="PNG", optimize=True)
    print(f"Wrote {master.relative_to(_ROOT)} (512x512)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
