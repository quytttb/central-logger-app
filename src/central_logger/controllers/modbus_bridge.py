"""Asyncio thread + ModbusManager lifecycle and snapshot handling."""
from __future__ import annotations

import asyncio
import logging
import threading
from collections.abc import Callable
from typing import Any

from central_logger.controllers.rest_facade import normalize_host
from central_logger.controllers.sensor_state import SensorState
from central_logger.db import LoggerInfo, SensorReading, get_session
from central_logger.services import LoggerConfig, ModbusManager, ReadOutcome, now_iso
from central_logger.viewmodels.logger_list_model import LoggerItem, LoggerListModel

log = logging.getLogger(__name__)


class ModbusBridge:
    def __init__(
        self,
        sensors: SensorState,
        *,
        on_snapshot_for_ui: Callable[[object, object], None],
        is_online: Callable[[int], bool | None],
        log_event: Callable[..., None],
        log_event_dedup: Callable[..., None],
        sync_header_stats: Callable[[], None],
        emit_snapshot_applied: Callable[[int, bool, str], None],
        build_endpoint: Callable[[LoggerInfo], Any],
    ) -> None:
        self._sensors = sensors
        self._on_snapshot_for_ui = on_snapshot_for_ui
        self._is_online = is_online
        self._log_event = log_event
        self._log_event_dedup = log_event_dedup
        self._sync_header_stats = sync_header_stats
        self._emit_snapshot_applied = emit_snapshot_applied
        self._build_endpoint = build_endpoint

        self._manager = ModbusManager(on_snapshot=self._on_snapshot)
        self._loop: asyncio.AbstractEventLoop | None = None
        self._thread: threading.Thread | None = None
        self._model: LoggerListModel | None = None

    @property
    def manager(self) -> ModbusManager:
        return self._manager

    @property
    def loop(self) -> asyncio.AbstractEventLoop | None:
        return self._loop

    def set_model(self, model: LoggerListModel | None) -> None:
        self._model = model

    def start_loop(self) -> None:
        ready = threading.Event()

        def runner() -> None:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            self._loop = loop
            ready.set()
            try:
                loop.call_soon(self._manager.start)
                loop.run_forever()
            finally:
                pending = asyncio.all_tasks(loop)
                for task in pending:
                    task.cancel()
                if pending:
                    loop.run_until_complete(
                        asyncio.gather(*pending, return_exceptions=True)
                    )
                loop.close()

        self._thread = threading.Thread(target=runner, name="modbus-loop", daemon=True)
        self._thread.start()
        ready.wait(timeout=5)

    def stop_loop(self) -> None:
        if self._loop is not None:
            fut = asyncio.run_coroutine_threadsafe(self._manager.stop(), self._loop)
            try:
                fut.result(timeout=5)
            except Exception:  # noqa: BLE001
                log.exception("stop manager error")
            self._loop.call_soon_threadsafe(self._loop.stop)
        if self._thread is not None:
            self._thread.join(timeout=5)

    def _on_snapshot(self, config: LoggerConfig, outcome: ReadOutcome) -> None:
        self._on_snapshot_for_ui(config, outcome)

    def apply_snapshot_ui(self, config: object, outcome: object) -> None:
        if not isinstance(config, LoggerConfig) or not isinstance(outcome, ReadOutcome):
            log.warning("apply_snapshot_ui: invalid payload types")
            return
        if self._model is None:
            return
        if outcome.ok and outcome.snapshot is not None:
            hdr = outcome.snapshot.header
            prev_online = self._is_online(config.id)
            self._model.update_status(
                config.id,
                online=True,
                polling=hdr.polling,
                rtu_connected=hdr.rtu_connected,
                any_alarm=hdr.any_alarm,
                sensor_count=hdr.sensor_count,
                last_update=now_iso(),
                last_error="",
            )
            self.persist_readings(config.id, outcome)
            self._sensors.cache_sensors(config.id, outcome.snapshot)
            if prev_online is False:
                self._log_event(config.id, config.name, "Online", "Logger online", "info")
            if hdr.any_alarm:
                alarm_count = sum(1 for s in outcome.snapshot.sensors if s.alarm)
                if alarm_count > 0:
                    self._log_event_dedup(
                        config.id,
                        config.name,
                        "Alarm",
                        f"Alarm active on {alarm_count} sensor(s)",
                        "critical",
                    )
            self._emit_snapshot_applied(config.id, True, now_iso())
        else:
            prev_online = self._is_online(config.id)
            self._model.update_status(
                config.id,
                online=outcome.tcp_connected,
                polling=False,
                last_error=outcome.error,
            )
            if prev_online is True:
                self._log_event(
                    config.id,
                    config.name,
                    "Offline",
                    outcome.error or "Logger went offline",
                    "error",
                )
            self._emit_snapshot_applied(config.id, False, outcome.error or "")
        self._sync_header_stats()

    @staticmethod
    def persist_readings(logger_id: int, outcome: ReadOutcome) -> None:
        if outcome.snapshot is None or not outcome.snapshot.sensors:
            return
        try:
            with get_session() as session:
                ts = outcome.snapshot.header.timestamp
                rows = [
                    SensorReading(
                        logger_id=logger_id,
                        sensor_id=s.sensor_id,
                        value=s.value,
                        valid=s.valid,
                        alarm=s.alarm,
                        stale=s.stale,
                        logger_timestamp=ts,
                    )
                    for s in outcome.snapshot.sensors
                ]
                session.add_all(rows)
                session.commit()
        except Exception:  # noqa: BLE001
            log.exception("persist readings failed for logger %s", logger_id)

    def add_runtime_logger(self, row: LoggerInfo, rest_cache: dict[int, Any]) -> None:
        assert row.id is not None
        rest_cache[row.id] = self._build_endpoint(row)
        config = LoggerConfig(
            id=row.id,
            name=row.name,
            host=normalize_host(row.host),
            port=row.port,
            unit_id=row.unit_id,
            poll_interval_s=row.poll_interval_s,
            timeout_s=row.timeout_s,
        )
        if self._model is not None:
            self._model.add_logger(
                LoggerItem(
                    id=row.id,
                    name=row.name,
                    host=normalize_host(row.host),
                    port=row.port,
                    unit_id=row.unit_id,
                    poll_interval_s=row.poll_interval_s,
                    enabled=row.enabled,
                    timeout_s=row.timeout_s,
                    note=row.note or "",
                    api_port=row.api_port,
                    api_base_url=row.api_base_url or "",
                )
            )
        try:
            self._manager.add_logger(config)
        except ValueError:
            log.warning("logger id %s đã có trong manager", row.id)
            return
        if self._loop is not None and self._loop.is_running():
            self._loop.call_soon_threadsafe(self._manager._ensure_task, row.id)

    def remove_logger_async(self, logger_id: int) -> None:
        if self._loop is not None and self._loop.is_running():
            fut = asyncio.run_coroutine_threadsafe(
                self._manager.remove_logger_async(logger_id), self._loop
            )
            try:
                fut.result(timeout=15)
            except Exception:  # noqa: BLE001
                log.exception("remove_logger_async")

    def restart_connection(self, logger_id: int, new_config: LoggerConfig) -> None:
        if self._loop is None or not self._loop.is_running():
            return

        async def _restart() -> None:
            await self._manager.remove_logger_async(logger_id)
            self._manager.add_logger(new_config)
            self._loop.call_soon_threadsafe(self._manager._ensure_task, logger_id)

        asyncio.run_coroutine_threadsafe(_restart(), self._loop)

    def restart_modbus_for(self, logger_id: int) -> None:
        if self._loop is None:
            return
        client = self._manager._clients.get(logger_id)
        if client is None:
            return

        async def _kick() -> None:
            try:
                await client.close()
            except Exception:  # noqa: BLE001
                log.debug("kick close error", exc_info=True)

        asyncio.run_coroutine_threadsafe(_kick(), self._loop)
