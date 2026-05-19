"""SQLModel engine & session helpers - SQLite mặc định, có thể override qua env."""
from __future__ import annotations

import os
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from sqlalchemy import inspect, text
from sqlmodel import Session, SQLModel, create_engine

DEFAULT_SQLITE_PATH = Path.home() / ".central-logger" / "central-logger.db"
_engine = None


def _resolve_db_url() -> str:
    url = os.environ.get("CENTRAL_LOGGER_DB_URL")
    if url:
        return url
    DEFAULT_SQLITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    return f"sqlite:///{DEFAULT_SQLITE_PATH}"


def get_engine():
    global _engine
    if _engine is None:
        url = _resolve_db_url()
        connect_args = {"check_same_thread": False} if url.startswith("sqlite") else {}
        _engine = create_engine(url, echo=False, connect_args=connect_args)
    return _engine


def init_db() -> None:
    # import models để SQLModel.metadata biết các table
    from central_logger.db import models  # noqa: F401

    engine = get_engine()
    SQLModel.metadata.create_all(engine)
    _ensure_logger_info_columns(engine)
    _migrate_poll_interval_seconds(engine)
    _seed_app_settings()


def _seed_app_settings() -> None:
    """Đảm bảo bảng app_settings luôn có row id=1 với defaults."""
    from central_logger.db.models import DEFAULT_SYSTEM_TIMEZONE, AppSettings

    with Session(get_engine()) as session:
        row = session.get(AppSettings, 1)
        if row is None:
            session.add(AppSettings(id=1))
            session.commit()
        elif row.system_timezone in ("", "UTC"):
            # DB cũ seed UTC — nâng lên múi giờ VN cho chart và Settings.
            row.system_timezone = DEFAULT_SYSTEM_TIMEZONE
            session.add(row)
            session.commit()


# Lightweight migration: SQLite create_all không tự ALTER bảng đã tồn tại.
# Cho v1, bổ sung column thiếu nếu DB cũ thiếu (idempotent).
_REQUIRED_LOGGER_COLUMNS: dict[str, str] = {
    "api_base_url": "VARCHAR(256)",
    "api_port": "INTEGER NOT NULL DEFAULT 8080",
    "api_token": "VARCHAR(256)",
    "last_revision": "INTEGER NOT NULL DEFAULT -1",
}


def _ensure_logger_info_columns(engine) -> None:
    insp = inspect(engine)
    if "logger_info" not in insp.get_table_names():
        return
    existing = {col["name"] for col in insp.get_columns("logger_info")}
    missing = {k: v for k, v in _REQUIRED_LOGGER_COLUMNS.items() if k not in existing}
    if not missing:
        return
    with engine.begin() as conn:
        for col, ddl in missing.items():
            conn.execute(text(f"ALTER TABLE logger_info ADD COLUMN {col} {ddl}"))


def _migrate_poll_interval_seconds(engine) -> None:
    """Thêm poll_interval_s và migrate từ poll_interval_ms (legacy)."""
    insp = inspect(engine)
    if "logger_info" not in insp.get_table_names():
        return
    existing = {col["name"] for col in insp.get_columns("logger_info")}
    if "poll_interval_s" in existing:
        return
    with engine.begin() as conn:
        conn.execute(
            text("ALTER TABLE logger_info ADD COLUMN poll_interval_s INTEGER NOT NULL DEFAULT 2")
        )
        if "poll_interval_ms" in existing:
            conn.execute(
                text(
                    """
                    UPDATE logger_info
                    SET poll_interval_s = MAX(1, poll_interval_ms / 1000)
                    """
                )
            )
        else:
            conn.execute(text("UPDATE logger_info SET poll_interval_s = 2 WHERE poll_interval_s < 1"))


@contextmanager
def get_session() -> Iterator[Session]:
    with Session(get_engine()) as session:
        yield session


def reset_engine_for_tests(url: str) -> None:
    """Chỉ dùng trong tests - reset engine với URL khác (vd in-memory sqlite)."""
    global _engine
    _engine = create_engine(url, echo=False, connect_args={"check_same_thread": False})
