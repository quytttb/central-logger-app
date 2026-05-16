"""Controller cầu nối UI <-> ModbusManager <-> Database.

Chạy `ModbusManager` trong asyncio loop riêng (background thread),
chuyển snapshot về Qt main thread qua `QMetaObject.invokeMethod`/Signals
để update `LoggerListModel` an toàn về thread.
"""
from __future__ import annotations

import asyncio
import json
import logging
import threading
from typing import Any

from PySide6.QtCore import Property, QObject, Qt, Signal, Slot
from PySide6.QtQml import QmlElement
from sqlmodel import select

from central_logger.db import LoggerInfo, SensorReading, get_session, init_db
from central_logger.services import (
    ConfigResponse,
    LoggerConfig,
    LoggerConfigClient,
    ModbusManager,
    ReadOutcome,
    RestEndpoint,
    now_iso,
)
from central_logger.viewmodels.logger_list_model import LoggerItem, LoggerListModel

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1

log = logging.getLogger(__name__)


def _normalize_host(host: str) -> str:
    """Tránh một số máy resolve `localhost` -> IPv6 trước trong khi server chỉ listen IPv4."""
    h = host.strip()
    if h.lower() == "localhost":
        return "127.0.0.1"
    return h


@QmlElement
class DashboardController(QObject):
    """Bridge giữa Modbus async loop và UI.

    Sử dụng QML:
        DashboardController {
            id: controller
            model: loggersModel
            Component.onCompleted: controller.start()
        }
    """

    snapshotApplied = Signal(int, bool, str)  # loggerId, ok, errorOrTimestamp
    sensorsUpdated = Signal(int, "QString")   # loggerId, sensorsJson
    started = Signal()
    stopped = Signal()
    modelChanged = Signal()
    appStatsChanged = Signal()
    loggerRemoved = Signal(int)

    # REST signals (gửi JSON string để QML decode dễ; tránh QVariantMap nested phức tạp)
    configFetched = Signal(int, bool, "QString")  # loggerId, ok, payloadJson
    configApplied = Signal(int, bool, "QString")  # loggerId, ok, payloadJson
    healthChecked = Signal(int, bool, int, "QString")  # loggerId, ok, revision, message

    # Chuyển snapshot từ thread asyncio Modbus về main thread Qt (QueuedConnection).
    # Không dùng QTimer.singleShot từ worker thread — có thể không bao giờ chạy → UI mãi offline.
    _snapshotForUi = Signal(object, object)
    _restResultForUi = Signal(str, int, object)  # kind, loggerId, ConfigResponse

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._model: LoggerListModel | None = None
        self._manager = ModbusManager(on_snapshot=self._on_snapshot)
        self._loop: asyncio.AbstractEventLoop | None = None
        self._thread: threading.Thread | None = None
        self._running = False
        # Cache nhanh row LoggerInfo theo id để build RestEndpoint mà không query DB liên tục.
        self._rest_cache: dict[int, RestEndpoint] = {}
        # Snapshot Modbus gần nhất theo logger_id — UI có thể đọc tức thì để render SensorCard.
        self._last_snapshot: dict[int, dict[str, Any]] = {}
        self._snapshotForUi.connect(self._apply_snapshot, Qt.ConnectionType.QueuedConnection)
        self._restResultForUi.connect(self._emit_rest_signal, Qt.ConnectionType.QueuedConnection)

    def _sync_header_stats(self) -> None:
        """Báo QML cập nhật AppState (total/online/alarm) từ model."""
        self.appStatsChanged.emit()

    # ----- QML properties -----
    @Property(QObject, notify=modelChanged)
    def model(self) -> QObject | None:  # type: ignore[override]
        return self._model

    @model.setter
    def model(self, value: QObject) -> None:
        if self._model is value:
            return
        self._model = value  # type: ignore[assignment]
        self.modelChanged.emit()

    # ----- public API -----
    @Slot()
    def start(self) -> None:
        if self._running:
            return
        init_db()
        self._load_configs_from_db()
        self._start_loop()
        self._running = True
        self.started.emit()
        self._sync_header_stats()

    @Slot()
    def stop(self) -> None:
        if not self._running:
            return
        self._running = False
        if self._loop is not None:
            fut = asyncio.run_coroutine_threadsafe(self._manager.stop(), self._loop)
            try:
                fut.result(timeout=5)
            except Exception:  # noqa: BLE001
                log.exception("stop manager error")
            self._loop.call_soon_threadsafe(self._loop.stop)
        if self._thread is not None:
            self._thread.join(timeout=5)
        self.stopped.emit()

    @Slot(str, str, int, int, int, int, str)
    def addLogger(
        self,
        name: str,
        host: str,
        port: int = 5020,
        unit_id: int = 1,
        poll_interval_ms: int = 2000,
        api_port: int = 8080,
        api_token: str = "",
    ) -> None:
        with get_session() as session:
            row = LoggerInfo(
                name=name,
                host=_normalize_host(host),
                port=port,
                unit_id=unit_id,
                poll_interval_ms=poll_interval_ms,
                api_port=api_port or 8080,
                api_token=api_token or None,
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            self._add_runtime_logger(row)
            self._sync_header_stats()

    @Slot(int, str, int)
    def updateLoggerApi(self, logger_id: int, token: str, api_port: int) -> None:
        """Cập nhật API token/port cho một logger (dùng từ Detail Dialog)."""
        with get_session() as session:
            row = session.get(LoggerInfo, logger_id)
            if row is None:
                log.warning("updateLoggerApi: logger %s không tồn tại", logger_id)
                return
            row.api_token = token or None
            row.api_port = api_port or row.api_port
            session.add(row)
            session.commit()
            session.refresh(row)
            self._rest_cache[logger_id] = self._build_endpoint(row)

    @Slot(int)
    def removeLogger(self, logger_id: int) -> None:
        """Xóa logger khỏi Central: dừng Modbus poll, xóa DB (sensor_reading + logger_info), UI."""
        if self._loop is not None and self._loop.is_running():
            fut = asyncio.run_coroutine_threadsafe(
                self._manager.remove_logger_async(logger_id), self._loop
            )
            try:
                fut.result(timeout=15)
            except Exception:  # noqa: BLE001
                log.exception("removeLogger: teardown Modbus")
        self._rest_cache.pop(logger_id, None)
        try:
            with get_session() as session:
                for r in session.exec(
                    select(SensorReading).where(SensorReading.logger_id == logger_id)
                ).all():
                    session.delete(r)
                row = session.get(LoggerInfo, logger_id)
                if row is not None:
                    session.delete(row)
                session.commit()
        except Exception:  # noqa: BLE001
            log.exception("removeLogger: DB delete")
        if self._model is not None:
            self._model.remove_logger(logger_id)
        self._last_snapshot.pop(logger_id, None)
        self.loggerRemoved.emit(logger_id)
        self._sync_header_stats()

    # ----- REST remote config (async) -----
    @Slot(int)
    def checkHealth(self, logger_id: int) -> None:
        self._schedule_rest(logger_id, "health")

    @Slot(int)
    def fetchConfig(self, logger_id: int) -> None:
        self._schedule_rest(logger_id, "get_config")

    @Slot(int, int, "QString")
    def applyConfig(self, logger_id: int, expected_revision: int, config_json: str) -> None:
        """Apply config tới logger. `config_json` là chuỗi JSON cho field `config`."""
        try:
            cfg = json.loads(config_json) if config_json.strip() else {}
            if not isinstance(cfg, dict):
                raise ValueError("config phải là JSON object")
        except Exception as exc:  # noqa: BLE001
            self._restResultForUi.emit(
                "apply_config",
                logger_id,
                ConfigResponse(
                    ok=False,
                    http_status=0,
                    errors=[{"field": "config", "message": f"JSON parse: {exc}"}],
                ),
            )
            return
        self._schedule_rest(logger_id, "apply_config", expected_revision=expected_revision, config=cfg)

    def _schedule_rest(self, logger_id: int, kind: str, **kwargs: Any) -> None:
        endpoint = self._rest_cache.get(logger_id)
        if endpoint is None:
            self._restResultForUi.emit(
                kind,
                logger_id,
                ConfigResponse(
                    ok=False,
                    http_status=0,
                    errors=[{"field": "", "message": "Logger chưa load (rest cache trống)"}],
                ),
            )
            return
        if not endpoint.token and kind != "health":
            self._restResultForUi.emit(
                kind,
                logger_id,
                ConfigResponse(
                    ok=False,
                    http_status=401,
                    errors=[{"field": "api_token", "message": "Chưa cấu hình API token"}],
                ),
            )
            return
        if self._loop is None or not self._loop.is_running():
            self._restResultForUi.emit(
                kind,
                logger_id,
                ConfigResponse(
                    ok=False,
                    http_status=0,
                    errors=[{"field": "", "message": "asyncio loop chưa sẵn sàng"}],
                ),
            )
            return
        coro = self._run_rest(logger_id, endpoint, kind, **kwargs)
        asyncio.run_coroutine_threadsafe(coro, self._loop)

    async def _run_rest(
        self, logger_id: int, endpoint: RestEndpoint, kind: str, **kwargs: Any
    ) -> None:
        client = LoggerConfigClient(endpoint)
        try:
            if kind == "health":
                result = await client.health()
            elif kind == "get_config":
                result = await client.get_config()
            elif kind == "apply_config":
                result = await client.apply_config(
                    expected_revision=int(kwargs["expected_revision"]),
                    config=kwargs["config"],
                )
            else:
                log.warning("REST kind không hỗ trợ: %s", kind)
                return
        except Exception as exc:  # noqa: BLE001
            log.exception("REST %s lỗi không mong đợi", kind)
            result = ConfigResponse(
                ok=False, http_status=0, errors=[{"field": "", "message": str(exc)}]
            )

        # Lưu revision (last_revision) khi đọc OK
        if kind in ("get_config", "apply_config") and result.ok:
            new_rev = result.applied_revision if kind == "apply_config" else result.revision
            if new_rev is not None:
                self._save_last_revision(logger_id, int(new_rev))

        # Nếu apply OK: edge sẽ restart Modbus worker -> reconnect proactively từ Central.
        if kind == "apply_config" and result.ok:
            self._restart_modbus_for(logger_id)

        self._restResultForUi.emit(kind, logger_id, result)

    @Slot(str, int, object)
    def _emit_rest_signal(self, kind: str, logger_id: int, result: object) -> None:
        if not isinstance(result, ConfigResponse):
            return
        payload = json.dumps(
            {
                "ok": result.ok,
                "http_status": result.http_status,
                "applied_revision": result.applied_revision,
                "revision": result.revision,
                "request_id": result.request_id,
                "errors": result.errors,
                "message": result.message,
                "config": result.config,
            },
            ensure_ascii=False,
        )
        if kind == "health":
            self.healthChecked.emit(
                logger_id,
                result.ok,
                int(result.revision or -1),
                result.message or result.error_summary,
            )
        elif kind == "get_config":
            self.configFetched.emit(logger_id, result.ok, payload)
        elif kind == "apply_config":
            self.configApplied.emit(logger_id, result.ok, payload)

    def _save_last_revision(self, logger_id: int, revision: int) -> None:
        try:
            with get_session() as session:
                row = session.get(LoggerInfo, logger_id)
                if row is None:
                    return
                if row.last_revision == revision:
                    return
                row.last_revision = revision
                session.add(row)
                session.commit()
        except Exception:  # noqa: BLE001
            log.exception("save last_revision failed for %s", logger_id)

    def _restart_modbus_for(self, logger_id: int) -> None:
        """Sau khi edge apply config thành công, edge sẽ restart Modbus server vài
        trăm ms. Ép Central drop client và poll lại để reconnect nhanh."""
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

    # ----- internals -----
    def _load_configs_from_db(self) -> None:
        with get_session() as session:
            from sqlmodel import select

            rows = session.exec(select(LoggerInfo).where(LoggerInfo.enabled == True)).all()  # noqa: E712
        for row in rows:
            self._add_runtime_logger(row)

    def _build_endpoint(self, row: LoggerInfo) -> RestEndpoint:
        return RestEndpoint(
            host=_normalize_host(row.host),
            port=row.api_port or 8080,
            token=row.api_token,
            base_url_override=row.api_base_url,
        )

    def _add_runtime_logger(self, row: LoggerInfo) -> None:
        assert row.id is not None
        self._rest_cache[row.id] = self._build_endpoint(row)
        config = LoggerConfig(
            id=row.id,
            name=row.name,
            host=_normalize_host(row.host),
            port=row.port,
            unit_id=row.unit_id,
            poll_interval_ms=row.poll_interval_ms,
            timeout_s=row.timeout_s,
        )
        if self._model is not None:
            self._model.add_logger(
                LoggerItem(
                    id=row.id,
                    name=row.name,
                    host=_normalize_host(row.host),
                    port=row.port,
                    unit_id=row.unit_id,
                )
            )
        try:
            self._manager.add_logger(config)
        except ValueError:
            log.warning("logger id %s đã có trong manager", row.id)
            return
        # nếu loop đang chạy: schedule task ngay
        if self._loop is not None and self._loop.is_running():
            self._loop.call_soon_threadsafe(self._manager._ensure_task, row.id)

    def _start_loop(self) -> None:
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

    # ----- callback từ ModbusManager -----
    def _on_snapshot(self, config: LoggerConfig, outcome: ReadOutcome) -> None:
        # Worker thread (asyncio): chỉ emit signal — slot chạy trên main thread.
        self._snapshotForUi.emit(config, outcome)

    @Slot(object, object)
    def _apply_snapshot(self, config: object, outcome: object) -> None:
        if not isinstance(config, LoggerConfig) or not isinstance(outcome, ReadOutcome):
            log.warning("_apply_snapshot: kiểu payload không hợp lệ")
            return
        if self._model is None:
            return
        if outcome.ok and outcome.snapshot is not None:
            hdr = outcome.snapshot.header
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
            self._persist_readings(config.id, outcome)
            self._cache_sensors(config.id, outcome.snapshot)
            self.snapshotApplied.emit(config.id, True, now_iso())
        else:
            self._model.update_status(
                config.id,
                online=outcome.tcp_connected,
                polling=False,
                last_error=outcome.error,
            )
            self.snapshotApplied.emit(config.id, False, outcome.error)
        self._sync_header_stats()

    def _cache_sensors(self, logger_id: int, snapshot: Any) -> None:
        """Lưu snapshot gần nhất + emit signal để UI Detail cập nhật realtime."""
        sensors = [
            {
                "sensor_id": s.sensor_id,
                "value": float(s.value),
                "valid": bool(s.valid),
                "alarm": bool(s.alarm),
                "stale": bool(s.stale),
            }
            for s in snapshot.sensors
        ]
        payload = {
            "logger_id": logger_id,
            "timestamp": int(snapshot.header.timestamp),
            "iso": now_iso(),
            "polling": bool(snapshot.header.polling),
            "rtu_connected": bool(snapshot.header.rtu_connected),
            "any_alarm": bool(snapshot.header.any_alarm),
            "sensors": sensors,
        }
        self._last_snapshot[logger_id] = payload
        self.sensorsUpdated.emit(logger_id, json.dumps(payload, ensure_ascii=False))

    @Slot(int, result="QString")
    def latestReadings(self, logger_id: int) -> str:
        """JSON snapshot gần nhất; QML gọi khi mở Detail để render ngay không chờ poll."""
        payload = self._last_snapshot.get(logger_id)
        return json.dumps(payload, ensure_ascii=False) if payload else ""

    def _persist_readings(self, logger_id: int, outcome: ReadOutcome) -> None:
        if outcome.snapshot is None or not outcome.snapshot.sensors:
            return
        try:
            with get_session() as session:
                from central_logger.db import SensorReading

                ts = outcome.snapshot.header.timestamp
                for s in outcome.snapshot.sensors:
                    session.add(
                        SensorReading(
                            logger_id=logger_id,
                            sensor_id=s.sensor_id,
                            value=s.value,
                            valid=s.valid,
                            alarm=s.alarm,
                            stale=s.stale,
                            logger_timestamp=ts,
                        )
                    )
                session.commit()
        except Exception:  # noqa: BLE001
            log.exception("persist readings failed for logger %s", logger_id)
