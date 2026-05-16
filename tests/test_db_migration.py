"""Test migration nhẹ cho LoggerInfo: thêm cột mới vào DB cũ."""
from __future__ import annotations

from sqlalchemy import inspect, text
from sqlmodel import create_engine

from central_logger.db.session import _ensure_logger_info_columns


def test_add_missing_columns_on_legacy_table(tmp_path):
    db_path = tmp_path / "legacy.db"
    engine = create_engine(f"sqlite:///{db_path}")
    # Tạo bảng cũ (v0) thiếu các column REST.
    with engine.begin() as conn:
        conn.execute(
            text(
                """
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
                """
            )
        )

    _ensure_logger_info_columns(engine)

    insp = inspect(engine)
    cols = {c["name"] for c in insp.get_columns("logger_info")}
    for required in ("api_base_url", "api_port", "api_token", "last_revision"):
        assert required in cols
