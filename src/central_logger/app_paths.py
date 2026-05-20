"""Install root resolution — deb deploy (CENTRAL_LOGGER_APP_ROOT) vs editable dev."""

from __future__ import annotations

import os
from pathlib import Path

_LOGO_NAME = "4M Technologies Blue.svg"


def resolve_install_root() -> Path | None:
    """Return app root containing ``resources/``, or None if unknown."""
    env = os.environ.get("CENTRAL_LOGGER_APP_ROOT", "").strip()
    if env:
        root = Path(env)
        if (root / "resources").is_dir():
            return root

    dev = Path(__file__).resolve().parents[2]
    if (dev / "resources").is_dir():
        return dev
    return None


def resolve_resources_root() -> Path:
    root = resolve_install_root()
    if root is not None:
        return root / "resources"
    return Path(__file__).resolve().parents[2] / "resources"


def resolve_logo_path() -> Path:
    return resolve_resources_root() / "images" / _LOGO_NAME
