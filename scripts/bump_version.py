#!/usr/bin/env python3
"""Bump project.version in pyproject.toml (SemVer MAJOR.MINOR.PATCH)."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import tomllib

ROOT = Path(__file__).resolve().parents[1]
PYPROJECT = ROOT / "pyproject.toml"
UV_LOCK = ROOT / "uv.lock"
_VERSION_LINE = re.compile(r'(?m)^version\s*=\s*"([^"]*)"')
_LOCK_PKG_VERSION = re.compile(
    r'(\[\[package\]\]\nname = "central-logger-app"\nversion = )"[^"]*"',
)


def _parse_version(raw: str) -> tuple[int, int, int]:
    parts = raw.strip().split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        raise ValueError(f"expected X.Y.Z with non-negative integers, got {raw!r}")
    return int(parts[0]), int(parts[1]), int(parts[2])


def read_version() -> str:
    data = tomllib.loads(PYPROJECT.read_text(encoding="utf-8"))
    return str(data["project"]["version"])


def sync_uv_lock(version: str) -> None:
    """Keep uv.lock [[package]] central-logger-app version aligned with pyproject.toml."""
    if not UV_LOCK.is_file():
        return
    text = UV_LOCK.read_text(encoding="utf-8")
    new_text, count = _LOCK_PKG_VERSION.subn(rf'\1"{version}"', text, count=1)
    if count != 1:
        raise RuntimeError(
            'could not find central-logger-app package version in uv.lock; run "uv lock"'
        )
    UV_LOCK.write_text(new_text, encoding="utf-8")


def write_version(version: str) -> None:
    text = PYPROJECT.read_text(encoding="utf-8")
    new_text, count = _VERSION_LINE.subn(f'version = "{version}"', text, count=1)
    if count != 1:
        raise RuntimeError("could not find exactly one version = line in pyproject.toml")
    PYPROJECT.write_text(new_text, encoding="utf-8")
    sync_uv_lock(version)


def bump(level: str) -> str:
    major, minor, patch = _parse_version(read_version())
    if level == "major":
        major += 1
        minor = 0
        patch = 0
    elif level == "minor":
        minor += 1
        patch = 0
    elif level == "patch":
        patch += 1
    else:
        raise ValueError(f"unknown bump level: {level!r}")
    new_version = f"{major}.{minor}.{patch}"
    write_version(new_version)
    return new_version


def main() -> int:
    parser = argparse.ArgumentParser(description="SemVer bump for central-logger-app")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("show", help="print current version")

    bump_p = sub.add_parser("bump", help="bump version in pyproject.toml")
    bump_p.add_argument(
        "level",
        choices=("major", "minor", "patch"),
        help="major=breaking, minor=features, patch=fixes",
    )

    args = parser.parse_args()
    try:
        if args.command == "show":
            print(read_version())
            return 0
        print(bump(args.level))
        return 0
    except (ValueError, RuntimeError) as exc:
        print(exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
