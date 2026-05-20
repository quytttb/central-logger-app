"""Per-logger sensor caches, REST/Modbus merge, poll history for charts."""
from __future__ import annotations

import json
import logging
import time
from collections import deque
from collections.abc import Callable
from datetime import datetime, timezone
from typing import Any

from central_logger.controllers import chart_queries
from central_logger.services import now_iso
from central_logger.services.sensor_catalog import merge_sensor_rows

log = logging.getLogger(__name__)

class SensorState:
    def __init__(
        self,
        *,
        is_online: Callable[[int], bool | None],
        on_sensors_updated: Callable[[int, str], None],
        on_invalidate_poll_trending: Callable[[int], None],
        on_invalidate_ingestion: Callable[[], None],
        request_catalog: Callable[[int], None] | None = None,
        request_readings: Callable[..., None] | None = None,
    ) -> None:
        self._is_online = is_online
        self._on_sensors_updated = on_sensors_updated
        self._on_invalidate_poll = on_invalidate_poll_trending
        self._on_invalidate_ingestion = on_invalidate_ingestion
        self._request_catalog = request_catalog
        self._request_readings = request_readings

        self.last_snapshot: dict[int, dict[str, Any]] = {}
        self.sensor_catalog: dict[int, list[dict[str, Any]]] = {}
        self.last_modbus_raw: dict[int, list[dict[str, Any]]] = {}
        self.last_rest_readings: dict[int, list[dict[str, Any]]] = {}
        self.poll_history: dict[int, deque[dict[str, Any]]] = {}
        self.poll_trending_json: dict[int, str] = {}
        self.last_sensors_updated_at: dict[int, float] = {}

    def set_rest_hooks(
        self,
        request_catalog: Callable[[int], None],
        request_readings: Callable[..., None],
    ) -> None:
        self._request_catalog = request_catalog
        self._request_readings = request_readings

    def clear_logger(self, logger_id: int) -> None:
        self.last_snapshot.pop(logger_id, None)
        self.last_modbus_raw.pop(logger_id, None)
        self.sensor_catalog.pop(logger_id, None)
        self.last_rest_readings.pop(logger_id, None)
        self.poll_history.pop(logger_id, None)
        self.poll_trending_json.pop(logger_id, None)
        self.last_sensors_updated_at.pop(logger_id, None)

    def merge_kwargs(self, logger_id: int, snapshot: Any | None = None) -> dict[str, bool]:
        online = self._is_online(logger_id)
        polling = False
        if snapshot is not None:
            polling = bool(snapshot.header.polling)
        elif logger_id in self.last_snapshot:
            polling = bool(self.last_snapshot[logger_id].get("polling", False))
        return {
            "logger_online": bool(online) if online is not None else False,
            "logger_polling": polling,
        }

    @staticmethod
    def modbus_sensors_from_snapshot(snapshot: Any) -> list[dict[str, Any]]:
        return [
            {
                "sensor_id": s.sensor_id,
                "value": float(s.value),
                "valid": bool(s.valid),
                "alarm": bool(s.alarm),
                "stale": bool(s.stale),
            }
            for s in snapshot.sensors
        ]

    def build_snapshot_payload(
        self, logger_id: int, snapshot: Any, modbus_sensors: list[dict[str, Any]]
    ) -> dict[str, Any]:
        catalog = self.sensor_catalog.get(logger_id)
        rest = self.last_rest_readings.get(logger_id)
        merged = merge_sensor_rows(
            catalog,
            modbus_sensors,
            rest,
            **self.merge_kwargs(logger_id, snapshot),
        )
        return {
            "logger_id": logger_id,
            "timestamp": int(snapshot.header.timestamp),
            "iso": now_iso(),
            "polling": bool(snapshot.header.polling),
            "rtu_connected": bool(snapshot.header.rtu_connected),
            "any_alarm": bool(snapshot.header.any_alarm),
            "sensors": merged,
            "has_catalog": bool(catalog),
        }

    def refresh_merged_snapshot(self, logger_id: int) -> None:
        catalog = self.sensor_catalog.get(logger_id)
        if not catalog:
            return
        modbus_raw = self.last_modbus_raw.get(logger_id, [])
        prev = self.last_snapshot.get(logger_id) or {}
        payload = {
            "logger_id": logger_id,
            "timestamp": prev.get("timestamp", 0),
            "iso": prev.get("iso", now_iso()),
            "polling": prev.get("polling", False),
            "rtu_connected": prev.get("rtu_connected", False),
            "any_alarm": prev.get("any_alarm", False),
            "sensors": merge_sensor_rows(
                catalog,
                modbus_raw,
                self.last_rest_readings.get(logger_id),
                **self.merge_kwargs(logger_id),
            ),
            "has_catalog": True,
        }
        self.last_snapshot[logger_id] = payload
        self.last_sensors_updated_at[logger_id] = time.monotonic()
        self._on_sensors_updated(logger_id, json.dumps(payload, ensure_ascii=False))

    def cache_sensors(self, logger_id: int, snapshot: Any) -> None:
        modbus_sensors = self.modbus_sensors_from_snapshot(snapshot)
        self.last_modbus_raw[logger_id] = modbus_sensors
        if not self.sensor_catalog.get(logger_id):
            if self._request_catalog:
                self._request_catalog(logger_id)
        elif self._request_readings:
            self._request_readings(logger_id, force=False)
        payload = self.build_snapshot_payload(logger_id, snapshot, modbus_sensors)
        self.last_snapshot[logger_id] = payload
        self.append_poll_history(logger_id, modbus_sensors)
        self.last_sensors_updated_at[logger_id] = time.monotonic()
        self._on_sensors_updated(logger_id, json.dumps(payload, ensure_ascii=False))

    def append_poll_history(self, logger_id: int, sensors: list[dict[str, Any]]) -> None:
        tz = chart_queries.chart_timezone()
        now = datetime.now(timezone.utc)
        label = now.astimezone(tz).strftime("%H:%M:%S")
        values = {int(s["sensor_id"]): float(s["value"]) for s in sensors}
        hist = self.poll_history.setdefault(
            logger_id, deque(maxlen=chart_queries.POLL_HISTORY_MAX)
        )
        hist.append({"label": label, "values": values})
        self.poll_trending_json.pop(logger_id, None)
        self._on_invalidate_poll(logger_id)
        self._on_invalidate_ingestion()

    def latest_readings_json(self, logger_id: int) -> str:
        payload = self.last_snapshot.get(logger_id)
        return json.dumps(payload, ensure_ascii=False) if payload else ""

    def readings_stale(self, logger_id: int, within_s: float = 1.0) -> bool:
        return time.monotonic() - self.last_sensors_updated_at.get(logger_id, 0.0) < within_s

    def invalidate_poll_trending(self, logger_id: int) -> None:
        self.poll_trending_json.pop(logger_id, None)
