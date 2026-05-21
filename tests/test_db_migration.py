"""Test migration nhẹ cho LoggerInfo: thêm cột mới vào DB cũ."""

from __future__ import annotations

from sqlalchemy import inspect, text
from sqlmodel import create_engine

from central_logger.controllers import logger_ops
from central_logger.db.session import (
    _drop_legacy_poll_interval_ms,
    _ensure_logger_info_columns,
    _migrate_poll_interval_seconds,
    init_db,
)
from central_logger.db import session as db_session


def test_add_missing_columns_on_legacy_table(tmp_path):
    db_path = tmp_path / "legacy.db"
    engine = create_engine(f"sqlite:///{db_path}")
    # Tạo bảng cũ (v0) thiếu các column REST.
    with engine.begin() as conn:
        conn.execute(text("""
                CREATE TABLE logger_info (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    host TEXT NOT NULL,
                    port INTEGER NOT NULL DEFAULT 5020,
                    unit_id INTEGER NOT NULL DEFAULT 1,
                    poll_interval_ms INTEGER NOT NULL DEFAULT 2000,
                    timeout_s REAL NOT NULL DEFAULT 2.0,
                    enabled BOOLEAN NOT NULL DEFAULT 1,
                    note TEXT,
                    created_at TEXT
                )
                """))

    _ensure_logger_info_columns(engine)

    insp = inspect(engine)
    cols = {c["name"] for c in insp.get_columns("logger_info")}
    for required in ("api_base_url", "api_port", "api_token", "last_revision"):
        assert required in cols


def test_migrate_poll_interval_seconds(tmp_path):
    db_path = tmp_path / "legacy_poll.db"
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        conn.execute(text("""
                CREATE TABLE logger_info (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    host TEXT NOT NULL,
                    port INTEGER NOT NULL DEFAULT 5020,
                    unit_id INTEGER NOT NULL DEFAULT 1,
                    poll_interval_ms INTEGER NOT NULL DEFAULT 4000,
                    timeout_s REAL NOT NULL DEFAULT 2.0,
                    enabled BOOLEAN NOT NULL DEFAULT 1
                )
                """))
        conn.execute(text("INSERT INTO logger_info (id, name, host) VALUES (1, 'L', '127.0.0.1')"))
    _migrate_poll_interval_seconds(engine)
    insp = inspect(engine)
    cols = {c["name"] for c in insp.get_columns("logger_info")}
    assert "poll_interval_s" in cols
    with engine.connect() as conn:
        row = conn.execute(text("SELECT poll_interval_s FROM logger_info WHERE id=1")).one()
    assert row[0] == 4


def _create_legacy_logger_table(conn) -> None:
    conn.execute(text("""
            CREATE TABLE logger_info (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                host TEXT NOT NULL,
                port INTEGER NOT NULL DEFAULT 5020,
                unit_id INTEGER NOT NULL DEFAULT 1,
                poll_interval_ms INTEGER NOT NULL DEFAULT 4000,
                poll_interval_s INTEGER NOT NULL DEFAULT 4,
                timeout_s REAL NOT NULL DEFAULT 2.0,
                enabled BOOLEAN NOT NULL DEFAULT 1,
                note TEXT,
                created_at TEXT,
                api_base_url VARCHAR(256),
                api_port INTEGER NOT NULL DEFAULT 8080,
                api_token VARCHAR(256),
                last_revision INTEGER NOT NULL DEFAULT -1
            )
            """))


def test_drop_legacy_poll_interval_ms_after_partial_migration(tmp_path):
    """DB đã có cả poll_interval_ms và poll_interval_s — drop cột ms."""
    db_path = tmp_path / "partial.db"
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        _create_legacy_logger_table(conn)
    _drop_legacy_poll_interval_ms(engine)
    insp = inspect(engine)
    cols = {c["name"] for c in insp.get_columns("logger_info")}
    assert "poll_interval_s" in cols
    assert "poll_interval_ms" not in cols


def test_init_db_legacy_schema_allows_insert_logger(tmp_path, monkeypatch):
    """init_db trên DB legacy (chỉ ms) rồi insert_logger không lỗi NOT NULL."""
    db_path = tmp_path / "legacy_init.db"
    url = f"sqlite:///{db_path}"
    engine = create_engine(url)
    with engine.begin() as conn:
        conn.execute(text("""
                CREATE TABLE logger_info (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    host TEXT NOT NULL,
                    port INTEGER NOT NULL DEFAULT 5020,
                    unit_id INTEGER NOT NULL DEFAULT 1,
                    poll_interval_ms INTEGER NOT NULL DEFAULT 2000,
                    timeout_s REAL NOT NULL DEFAULT 2.0,
                    enabled BOOLEAN NOT NULL DEFAULT 1,
                    note TEXT,
                    created_at TEXT
                )
                """))
    monkeypatch.setenv("CENTRAL_LOGGER_DB_URL", url)
    db_session._engine = None  # noqa: SLF001
    init_db()
    row = logger_ops.insert_logger(
        name="TEST",
        host="192.168.1.223",
        port=5020,
        unit_id=1,
        poll_interval_s=5,
        api_port=8080,
        api_token="tok",
        enabled=True,
        timeout_s=2.0,
        note="",
        api_base_url="",
    )
    assert row is not None
    assert row.poll_interval_s == 5
    insp = inspect(db_session.get_engine())
    cols = {c["name"] for c in insp.get_columns("logger_info")}
    assert "poll_interval_ms" not in cols
    db_session._engine = None  # noqa: SLF001
