"""SQLModel models cho Central Logger App."""
from __future__ import annotations

from datetime import datetime, timezone

from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class LoggerInfo(SQLModel, table=True):
    """Cấu hình & metadata của 1 Data Logger."""

    __tablename__ = "logger_info"

    id: int | None = Field(default=None, primary_key=True)
    name: str = Field(index=True, max_length=64)
    host: str = Field(max_length=128)
    port: int = Field(default=5020)
    unit_id: int = Field(default=1)
    poll_interval_ms: int = Field(default=2000)
    timeout_s: float = Field(default=2.0)
    enabled: bool = Field(default=True)
    note: str | None = Field(default=None, max_length=256)
    created_at: datetime = Field(default_factory=_utcnow)

    # ----- Remote Config REST (v1) -----
    # Mặc định cùng host với Modbus, port 8080. Cho phép override base URL nếu reverse-proxy.
    api_base_url: str | None = Field(default=None, max_length=256)
    api_port: int = Field(default=8080)
    api_token: str | None = Field(default=None, max_length=256)
    last_revision: int = Field(default=-1)


class SensorReading(SQLModel, table=True):
    """Bản ghi snapshot 1 sensor tại 1 thời điểm."""

    __tablename__ = "sensor_reading"

    id: int | None = Field(default=None, primary_key=True)
    logger_id: int = Field(foreign_key="logger_info.id", index=True)
    sensor_id: int = Field(index=True)
    value: float
    valid: bool = Field(default=True)
    alarm: bool = Field(default=False)
    stale: bool = Field(default=False)
    logger_timestamp: int = Field(default=0, description="Unix ts từ HR2/HR3")
    recorded_at: datetime = Field(default_factory=_utcnow, index=True)
