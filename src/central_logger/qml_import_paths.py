"""Optional QML import paths (e.g. built Qaterial)."""

from __future__ import annotations

import ctypes
import logging
import os
import shutil
import sys
from pathlib import Path


def bootstrap_qaterial_library_path(project_root: Path) -> None:
    """Prepend vendor/qaterial-install/lib to LD_LIBRARY_PATH (Linux) before importing Qt.

    libQaterial.so lives there; must be visible when the QML engine loads the module.
    Call this before any ``PySide6`` / ``Qt`` import.
    """
    lib_dir = project_root / "vendor" / "qaterial-install" / "lib"
    if not lib_dir.is_dir():
        return
    sep = os.pathsep
    prev = os.environ.get("LD_LIBRARY_PATH", "")
    os.environ["LD_LIBRARY_PATH"] = str(lib_dir) + (sep + prev if prev else "")


def load_qaterial_shared_library(project_root: Path) -> None:
    """Load libQaterial so C++ startup hooks can register QML types.

    **Must run only after PySide6 / Qt from the wheel are imported.** If this runs
    before ``import PySide6``, ``libQaterial.so`` (linked against system Qt) pulls in
    ``/usr/lib/.../libQt6Core.so`` first and the wheel's ``libpyside6`` then fails with
    undefined private Qt symbols (e.g. ``QMetaPropertyBuilder::setOverride``).

    ``ctypes.CDLL`` forces the loader to map the shared object. Prepend PySide's bundled
    ``Qt/lib`` to ``LD_LIBRARY_PATH`` via :func:`prepare_qaterial_shared_library` before
    calling this from application code.
    """
    inst = project_root / "vendor" / "qaterial-install"
    if sys.platform == "win32":
        candidates = [
            inst / "bin" / "Qaterial.dll",
            inst / "lib" / "Qaterial.dll",
        ]
    elif sys.platform == "darwin":
        candidates = [inst / "lib" / "libQaterial.dylib"]
    else:
        candidates = [inst / "lib" / "libQaterial.so"]

    for path in candidates:
        if not path.is_file():
            continue
        try:
            ctypes.CDLL(str(path))
            return
        except OSError as exc:
            logging.warning("Could not preload Qaterial from %s: %s", path, exc)
    logging.debug("No Qaterial shared library found under %s", inst)


def prepare_qaterial_shared_library(project_root: Path) -> None:
    """After ``import PySide6``, ensure ``libQaterial.so`` resolves Qt from the PySide bundle.

    Qaterial is typically built with system CMake Qt; at runtime it must use the **same**
    ``libQt6Core`` / ``libQt6Qml`` as PySide6, not ``/usr/lib``.
    """
    try:
        import PySide6  # noqa: PLC0415 — deliberate late import after caller imported Qt
    except ImportError:
        return

    qt_lib = Path(PySide6.__file__).resolve().parent / "Qt" / "lib"
    if qt_lib.is_dir():
        sep = os.pathsep
        prev = os.environ.get("LD_LIBRARY_PATH", "")
        os.environ["LD_LIBRARY_PATH"] = str(qt_lib) + (sep + prev if prev else "")
    load_qaterial_shared_library(project_root)
    ensure_qaterial_icons_impl_filesystem(project_root)


def ensure_qaterial_icons_impl_filesystem(project_root: Path) -> bool:
    """Expose ``Qaterial.Icons.Impl`` on the filesystem where Qt expects it.

    Upstream places ``qmldir`` under ``.../Qaterial/Icons/`` with ``module Qaterial.Icons.Impl``,
    but the engine resolves that URI as ``<importRoot>/Qaterial/Icons/Impl/qmldir``. Without an
    ``Impl/`` directory, ``import Qaterial.Icons.Impl`` fails even though resources exist in
    ``libQaterial.so``.
    """
    icons = project_root / "vendor" / "qaterial-build" / "qml" / "Qaterial" / "Icons"
    generated = icons / "Generated" / "IconsImpl.qml"
    impl = icons / "Impl"
    if not generated.is_file():
        logging.debug("Qaterial IconsImpl not found at %s — skip Impl layout fix.", generated)
        return False

    impl.mkdir(parents=True, exist_ok=True)
    qmldir = impl / "qmldir"
    qtext = "module Qaterial.Icons.Impl\nIconsImpl 1.0 IconsImpl.qml\n"
    if not qmldir.is_file() or qmldir.read_text(encoding="utf-8") != qtext:
        qmldir.write_text(qtext, encoding="utf-8")

    link = impl / "IconsImpl.qml"
    rel = Path("../Generated/IconsImpl.qml")
    if link.is_symlink() or link.is_file():
        try:
            if link.is_symlink() and link.resolve() == generated.resolve():
                return True
        except OSError:
            pass
        link.unlink(missing_ok=True)

    try:
        link.symlink_to(rel)
    except OSError:
        shutil.copy2(generated, link)
    return True


def qaterial_import_candidates(project_root: Path) -> list[Path]:
    """Return existing directories that may contain Qaterial's QML modules."""
    out: list[Path] = []
    env = os.environ.get("QATERIAL_QML_PATH", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.is_dir():
            out.append(p)
    # Built tree: qmldir + QML sources (install step may not copy qml/)
    build_qml = project_root / "vendor" / "qaterial-build" / "qml"
    if (build_qml / "Qaterial").is_dir():
        out.append(build_qml)
    inst = project_root / "vendor" / "qaterial-install"
    for sub in ("lib/qml", "qml", "lib64/qml"):
        p = inst / sub
        if p.is_dir():
            out.append(p)
    return out
