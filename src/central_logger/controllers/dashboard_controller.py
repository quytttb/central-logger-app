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
from collections import deque
from typing import Any

from PySide6.QtCore import Property, QObject, Qt, Signal, Slot
from PySide6.QtQml import QmlElement
from sqlmodel import select

from central_logger.db import AppSettings, LoggerInfo, SensorReading, SystemEvent, get_session, init_db
from central_logger.db.models import DEFAULT_SYSTEM_TIMEZONE
from central_logger.services import (
    ConfigResponse,
    LoggerConfig,
    LoggerConfigClient,
    ModbusManager,
    ReadOutcome,
    ReportDownloadResult,
    RestEndpoint,
    now_iso,
)
from central_logger.services.qr_provision import import_provision_from_qr_image
from central_logger.services.sensor_catalog import (
    display_name_for_sensor,
    extract_sensors_from_config_raw,
    extract_sensors_from_readings_raw,
    merge_sensor_rows,
    parse_catalog_from_rest,
)
from central_logger.utils.native_libs import is_qr_scan_available
from central_logger.viewmodels.logger_list_model import LoggerItem, LoggerListModel

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1

log = logging.getLogger(__name__)

POLL_HISTORY_MAX = 120
INGESTION_BUCKET_MINUTES = 5


def _humanize_age(then: Any) -> str:
    """Trả về chuỗi 'X mins ago' / 'X hours ago' / 'just now'."""
    from datetime import datetime, timezone

    if then is None:
        return ""
    try:
        ts = then
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        delta = datetime.now(timezone.utc) - ts
        secs = int(delta.total_seconds())
    except Exception:  # noqa: BLE001
        return ""
    if secs < 30:
        return "just now"
    if secs < 3600:
        m = max(1, secs // 60)
        return f"{m} min{'s' if m > 1 else ''} ago"
    if secs < 86400:
        h = secs // 3600
        return f"{h} hour{'s' if h > 1 else ''} ago"
    d = secs // 86400
    return f"{d} day{'s' if d > 1 else ''} ago"


def _chart_timezone():
    """Timezone cho nhãn trục chart (từ AppSettings, mặc định Việt Nam UTC+7)."""
    from zoneinfo import ZoneInfo

    tz_name = DEFAULT_SYSTEM_TIMEZONE
    try:
        with get_session() as session:
            row = session.get(AppSettings, 1)
            if row and row.system_timezone:
                tz_name = row.system_timezone.strip() or DEFAULT_SYSTEM_TIMEZONE
        return ZoneInfo(tz_name)
    except Exception:  # noqa: BLE001
        return ZoneInfo(DEFAULT_SYSTEM_TIMEZONE)


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
    eventsChanged = Signal()

    # REST signals (gửi JSON string để QML decode dễ; tránh QVariantMap nested phức tạp)
    configFetched = Signal(int, bool, "QString")  # loggerId, ok, payloadJson
    configApplied = Signal(int, bool, "QString")  # loggerId, ok, payloadJson
    healthChecked = Signal(int, bool, int, "QString")  # loggerId, ok, revision, message
    reportDownloaded = Signal(int, bool, "QString")  # loggerId, ok, message
    readingsError = Signal(int, "QString")  # loggerId, message
    edgeConfigProbed = Signal(bool, "QString")  # ok, payloadJson (no logger_id yet in Add)

    # Chuyển snapshot từ thread asyncio Modbus về main thread Qt (QueuedConnection).
    # Không dùng QTimer.singleShot từ worker thread — có thể không bao giờ chạy → UI mãi offline.
    _snapshotForUi = Signal(object, object)
    _restResultForUi = Signal(str, int, object)  # kind, loggerId, ConfigResponse
    _probeForUi = Signal(bool, "QString")  # ok, payloadJson

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
        # REST GET /config — sensor metadata (name, unit, type) per logger.
        self._sensor_catalog: dict[int, list[dict[str, Any]]] = {}
        self._last_modbus_raw: dict[int, list[dict[str, Any]]] = {}
        self._catalog_fetch_pending: set[int] = set()
        self._catalog_fetch_last: dict[int, float] = {}
        self._last_rest_readings: dict[int, list[dict[str, Any]]] = {}
        self._readings_fetch_pending: set[int] = set()
        self._readings_fetch_last: dict[int, float] = {}
        self._edge_poll_interval: dict[int, int] = {}
        # Lịch sử poll gần nhất cho trending chart (một điểm mỗi lần poll).
        self._poll_history: dict[int, deque[dict[str, Any]]] = {}
        # Dedupe events: (logger_id, event_type) -> last message
        self._last_event_key: dict[tuple[int, str], str] = {}
        self._snapshotForUi.connect(self._apply_snapshot, Qt.ConnectionType.QueuedConnection)
        self._restResultForUi.connect(self._emit_rest_signal, Qt.ConnectionType.QueuedConnection)
        self._probeForUi.connect(self._on_probe_result, Qt.ConnectionType.QueuedConnection)

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
        # Dọn lịch sử theo retention ngay khi khởi động để bảng không phình
        # vô hạn giữa các session.
        self.purgeOldData()

    @Slot(result=int)
    def purgeOldData(self) -> int:
        """Xóa `sensor_reading` và `system_event` cũ hơn `data_retention_days`.

        Trả về tổng số dòng bị xóa (để test / log). 0 nghĩa là không có gì dọn.
        """
        from datetime import datetime, timedelta, timezone

        try:
            with get_session() as session:
                settings = session.get(AppSettings, 1)
                days = int(settings.data_retention_days) if settings else 30
                if days <= 0:
                    return 0
                cutoff = datetime.now(timezone.utc) - timedelta(days=days)
                deleted = 0
                for row in session.exec(
                    select(SensorReading).where(SensorReading.recorded_at < cutoff)
                ).all():
                    session.delete(row)
                    deleted += 1
                for row in session.exec(
                    select(SystemEvent).where(SystemEvent.created_at < cutoff)
                ).all():
                    session.delete(row)
                    deleted += 1
                session.commit()
                if deleted:
                    log.info("purgeOldData: removed %s old rows", deleted)
                return deleted
        except Exception:  # noqa: BLE001
            log.exception("purgeOldData failed")
            return 0

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

    @Slot(str, result="QString")
    def importProvisionFromQrImage(self, image_path: str) -> str:
        """Decode provisioning QR image; return JSON {ok, fields?, error?} for QML."""
        return json.dumps(import_provision_from_qr_image(image_path), ensure_ascii=False)

    @Slot(result=bool)
    def qrScanAvailable(self) -> bool:
        """True when pyzbar + platform libs (bundled ZBar DLL on Windows) are loadable."""
        return is_qr_scan_available()

    @Slot(str, str, int, int, int, int, str, bool, float, str, str)
    def addLogger(
        self,
        name: str,
        host: str,
        port: int = 5020,
        unit_id: int = 1,
        poll_interval_s: int = 2,
        api_port: int = 8080,
        api_token: str = "",
        enabled: bool = True,
        timeout_s: float = 2.0,
        note: str = "",
        api_base_url: str = "",
    ) -> None:
        # Validate input để không tạo logger rác (name/host trống, port=0).
        clean_name = (name or "").strip()
        clean_host = (host or "").strip()
        if not clean_name or not clean_host or port <= 0 or unit_id <= 0:
            log.warning(
                "addLogger rejected: name=%r host=%r port=%s unit_id=%s",
                clean_name,
                clean_host,
                port,
                unit_id,
            )
            return
        with get_session() as session:
            row = LoggerInfo(
                name=clean_name,
                host=_normalize_host(clean_host),
                port=port,
                unit_id=unit_id,
                poll_interval_s=max(1, int(poll_interval_s)),
                api_port=api_port or 8080,
                api_token=api_token or None,
                enabled=enabled,
                timeout_s=float(timeout_s) if timeout_s and float(timeout_s) > 0 else 2.0,
                note=note.strip() or None,
                api_base_url=api_base_url.strip() or None,
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            if row.enabled:
                self._add_runtime_logger(row)
            else:
                # Chỉ thêm vào model/cache, không start poll task.
                self._rest_cache[row.id] = self._build_endpoint(row)
                if self._model is not None:
                    self._model.add_logger(
                        LoggerItem(
                            id=row.id,
                            name=row.name,
                            host=_normalize_host(row.host),
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
            self._log_event(
                logger_id=row.id,
                logger_name=row.name,
                event_type="Info",
                message=f"Logger added ({row.host}:{row.port})",
                level="info",
            )
            self._sync_header_stats()

    @Slot(int, str, str, int, int, int, float, str)
    def updateLoggerConnection(
        self,
        logger_id: int,
        name: str,
        host: str,
        port: int,
        unit_id: int,
        poll_interval_s: int,
        timeout_s: float = 2.0,
        note: str = "",
    ) -> None:
        """Cập nhật name/host/port/unit/poll/timeout/note trong DB; restart Modbus nếu logger enabled."""
        clean_name = (name or "").strip()
        clean_host = (host or "").strip()
        if not clean_name or not clean_host or port <= 0 or unit_id <= 0:
            log.warning("updateLoggerConnection rejected for logger %s", logger_id)
            return
        norm_host = _normalize_host(clean_host)
        saved_timeout_s = 2.0
        is_enabled = True
        with get_session() as session:
            row = session.get(LoggerInfo, logger_id)
            if row is None:
                log.warning("updateLoggerConnection: logger %s không tồn tại", logger_id)
                return
            is_enabled = bool(row.enabled)
            row.name = clean_name
            row.host = norm_host
            row.port = port
            row.unit_id = unit_id
            row.poll_interval_s = max(1, int(poll_interval_s))
            row.timeout_s = float(timeout_s) if timeout_s and float(timeout_s) > 0 else row.timeout_s
            row.note = note.strip() or None
            saved_timeout_s = row.timeout_s
            session.add(row)
            session.commit()
            session.refresh(row)
            self._rest_cache[logger_id] = self._build_endpoint(row)

        if self._model is not None:
            self._model.update_connection(
                logger_id,
                name=clean_name,
                host=norm_host,
                port=port,
                unit_id=unit_id,
                poll_interval_s=max(1, int(poll_interval_s)),
                timeout_s=saved_timeout_s,
                note=note.strip() or None,
            )

        if self._loop is None or not self._loop.is_running() or not is_enabled:
            return

        new_config = LoggerConfig(
            id=logger_id,
            name=clean_name,
            host=norm_host,
            port=port,
            unit_id=unit_id,
            poll_interval_s=max(1, int(poll_interval_s)),
            timeout_s=saved_timeout_s,
        )

        async def _restart() -> None:
            await self._manager.remove_logger_async(logger_id)
            self._manager.add_logger(new_config)
            self._loop.call_soon_threadsafe(self._manager._ensure_task, logger_id)

        asyncio.run_coroutine_threadsafe(_restart(), self._loop)

    @Slot(int, str, int, str)
    def updateLoggerApi(
        self, logger_id: int, token: str, api_port: int, api_base_url: str = ""
    ) -> None:
        """Cập nhật API token/port/base_url cho một logger."""
        with get_session() as session:
            row = session.get(LoggerInfo, logger_id)
            if row is None:
                log.warning("updateLoggerApi: logger %s không tồn tại", logger_id)
                return
            row.api_token = token or None
            row.api_port = api_port or row.api_port
            row.api_base_url = api_base_url.strip() or None
            session.add(row)
            session.commit()
            session.refresh(row)
            self._rest_cache[logger_id] = self._build_endpoint(row)

    @Slot(int, result="QString")
    def getLoggerFormData(self, logger_id: int) -> str:
        """Trả JSON đủ field Central từ DB để Edit form load offline."""
        try:
            with get_session() as session:
                row = session.get(LoggerInfo, logger_id)
                if row is None:
                    return "{}"
                return json.dumps(
                    {
                        "loggerId": row.id,
                        "name": row.name,
                        "host": row.host,
                        "port": row.port,
                        "unitId": row.unit_id,
                        "pollIntervalS": row.poll_interval_s,
                        "timeoutS": row.timeout_s,
                        "enabled": row.enabled,
                        "note": row.note or "",
                        "apiPort": row.api_port,
                        "apiToken": row.api_token or "",
                        "apiBaseUrl": row.api_base_url or "",
                        "lastRevision": row.last_revision,
                    },
                    ensure_ascii=False,
                )
        except Exception:  # noqa: BLE001
            log.exception("getLoggerFormData failed for %s", logger_id)
            return "{}"

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
        self._last_modbus_raw.pop(logger_id, None)
        self._sensor_catalog.pop(logger_id, None)
        self._catalog_fetch_pending.discard(logger_id)
        self._last_rest_readings.pop(logger_id, None)
        self._edge_poll_interval.pop(logger_id, None)
        self._readings_fetch_pending.discard(logger_id)
        self._poll_history.pop(logger_id, None)
        self._log_event(
            logger_id=None,
            logger_name="",
            event_type="Info",
            message=f"Logger {logger_id} removed",
            level="info",
        )
        self.loggerRemoved.emit(logger_id)
        self._sync_header_stats()

    # ----- REST remote config (async) -----
    @Slot(int)
    def checkHealth(self, logger_id: int) -> None:
        self._schedule_rest(logger_id, "health")

    @Slot(int)
    def fetchConfig(self, logger_id: int) -> None:
        self._schedule_rest(logger_id, "get_config")

    @Slot(str, int, str, str)
    def probeEdgeConfig(
        self, host: str, api_port: int, api_token: str, api_base_url: str = ""
    ) -> None:
        """Add mode: GET /health + /config trước khi lưu logger."""
        clean_host = _normalize_host((host or "").strip())
        token = (api_token or "").strip()
        if not clean_host or not token:
            self.edgeConfigProbed.emit(
                False,
                json.dumps(
                    {"ok": False, "message": "Host và API token là bắt buộc"},
                    ensure_ascii=False,
                ),
            )
            return
        if self._loop is None or not self._loop.is_running():
            self.edgeConfigProbed.emit(
                False,
                json.dumps(
                    {"ok": False, "message": "Background loop chưa sẵn sàng"},
                    ensure_ascii=False,
                ),
            )
            return
        port = api_port if api_port > 0 else 8080
        base = (api_base_url or "").strip() or None
        asyncio.run_coroutine_threadsafe(
            self._probe_edge_async(clean_host, port, token, base),
            self._loop,
        )

    @Slot(bool, "QString")
    def _on_probe_result(self, ok: bool, payload_json: str) -> None:
        self.edgeConfigProbed.emit(ok, payload_json)

    async def _probe_edge_async(
        self, host: str, api_port: int, token: str, api_base_url: str | None
    ) -> None:
        endpoint = RestEndpoint(
            host=host,
            port=api_port,
            token=token,
            base_url_override=api_base_url,
        )
        client = LoggerConfigClient(endpoint)
        try:
            health = await client.health()
            if not health.ok:
                payload = json.dumps(
                    {
                        "ok": False,
                        "message": health.error_summary or "Health check failed",
                        "revision": health.revision,
                    },
                    ensure_ascii=False,
                )
                self._probeForUi.emit(False, payload)
                return
            config = await client.get_config()
            cfg = config.config or {}
            if config.raw and isinstance(config.raw.get("config"), dict):
                cfg = config.raw.get("config") or cfg
            sensors_raw = extract_sensors_from_config_raw(config.raw)
            catalog = parse_catalog_from_rest(sensors_raw) if sensors_raw else []
            payload = json.dumps(
                {
                    "ok": config.ok,
                    "message": config.message or config.error_summary,
                    "revision": config.revision,
                    "config": cfg,
                    "sensors": catalog,
                    "errors": config.errors,
                },
                ensure_ascii=False,
            )
            self._probeForUi.emit(bool(config.ok), payload)
        except Exception as exc:  # noqa: BLE001
            log.exception("probeEdgeConfig failed")
            self._probeForUi.emit(
                False,
                json.dumps({"ok": False, "message": str(exc)}, ensure_ascii=False),
            )

    @Slot(int)
    def fetchReadings(self, logger_id: int) -> None:
        """QML: poll GET /readings for DI/DO values + analog status from edge."""
        self._request_readings_if_needed(logger_id, force=True)

    @Slot(int, str)
    def downloadLatestReport(self, logger_id: int, save_path: str) -> None:
        """Download newest TXT report from edge to save_path."""
        path = (save_path or "").strip()
        if not path:
            self.reportDownloaded.emit(logger_id, False, "Đường dẫn lưu file không hợp lệ")
            return
        self._schedule_rest(logger_id, "download_report", save_path=path)

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

    def _reload_rest_endpoint(self, logger_id: int) -> RestEndpoint | None:
        """Đồng bộ RestEndpoint từ DB (token/port có thể vừa lưu từ form)."""
        try:
            with get_session() as session:
                row = session.get(LoggerInfo, logger_id)
                if row is None:
                    return None
                ep = self._build_endpoint(row)
                self._rest_cache[logger_id] = ep
                return ep
        except Exception:  # noqa: BLE001
            log.exception("_reload_rest_endpoint logger_id=%s", logger_id)
            return None

    def _request_sensor_catalog_if_needed(self, logger_id: int) -> None:
        """Poll Modbus không có tên — tự GET /config khi chưa có catalog (tối đa 1 lần / 60s)."""
        import time

        if self._sensor_catalog.get(logger_id):
            return
        if logger_id in self._catalog_fetch_pending:
            return
        now = time.monotonic()
        if now - self._catalog_fetch_last.get(logger_id, 0.0) < 60.0:
            return
        endpoint = self._rest_cache.get(logger_id) or self._reload_rest_endpoint(logger_id)
        if endpoint is None or not endpoint.token:
            return
        self._catalog_fetch_last[logger_id] = now
        self._catalog_fetch_pending.add(logger_id)
        self._schedule_rest(logger_id, "get_config")

    def _catalog_has_digital(self, logger_id: int) -> bool:
        cat = self._sensor_catalog.get(logger_id) or []
        return any((c.get("sensor_type") or "").upper() in ("DI", "DO") for c in cat)

    def _edge_poll_interval_s(self, logger_id: int) -> float:
        cached = self._edge_poll_interval.get(logger_id)
        if cached is not None and cached > 0:
            return float(max(0.5, min(60, cached)))
        try:
            with get_session() as session:
                row = session.get(LoggerInfo, logger_id)
                if row is not None and row.poll_interval_s > 0:
                    return float(max(0.5, min(60, row.poll_interval_s)))
        except Exception:  # noqa: BLE001
            pass
        return 2.0

    def _cache_edge_poll_from_config(self, logger_id: int, cfg: dict[str, Any] | None) -> None:
        if not cfg or not isinstance(cfg, dict):
            return
        pi = cfg.get("poll_interval")
        if pi is None:
            return
        try:
            secs = max(1, int(pi))
            self._edge_poll_interval[logger_id] = secs
            with get_session() as session:
                row = session.get(LoggerInfo, logger_id)
                if row is not None and row.poll_interval_s != secs:
                    row.poll_interval_s = secs
                    session.add(row)
                    session.commit()
                    if self._model is not None:
                        self._model.update_connection(logger_id, poll_interval_s=secs)
        except (TypeError, ValueError):
            pass

    def _request_readings_if_needed(self, logger_id: int, *, force: bool = False) -> None:
        import time

        if not force and not self._catalog_has_digital(logger_id):
            return
        if logger_id in self._readings_fetch_pending:
            return
        now = time.monotonic()
        interval_s = self._edge_poll_interval_s(logger_id)
        if not force and now - self._readings_fetch_last.get(logger_id, 0.0) < interval_s:
            return
        endpoint = self._rest_cache.get(logger_id) or self._reload_rest_endpoint(logger_id)
        if endpoint is None or not endpoint.token:
            return
        self._readings_fetch_last[logger_id] = now
        self._readings_fetch_pending.add(logger_id)
        self._schedule_rest(logger_id, "get_readings")

    def _merge_kwargs(self, logger_id: int, snapshot: Any | None = None) -> dict[str, bool]:
        online = self._is_online(logger_id)
        polling = False
        if snapshot is not None:
            polling = bool(snapshot.header.polling)
        elif logger_id in self._last_snapshot:
            polling = bool(self._last_snapshot[logger_id].get("polling", False))
        return {
            "logger_online": bool(online) if online is not None else False,
            "logger_polling": polling,
        }

    def _schedule_rest(self, logger_id: int, kind: str, **kwargs: Any) -> None:
        endpoint = self._rest_cache.get(logger_id)
        if endpoint is None:
            endpoint = self._reload_rest_endpoint(logger_id)
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
            endpoint = self._reload_rest_endpoint(logger_id) or endpoint
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
            elif kind == "get_readings":
                result = await client.get_readings()
            elif kind == "download_report":
                bin_result = await client.download_latest_report()
                save_path = str(kwargs.get("save_path", ""))
                if bin_result.ok and save_path:
                    try:
                        with open(save_path, "wb") as fh:
                            fh.write(bin_result.content)
                        msg = f"Đã lưu {bin_result.filename}"
                        self._restResultForUi.emit(
                            kind,
                            logger_id,
                            ReportDownloadResult(
                                ok=True,
                                http_status=bin_result.http_status,
                                filename=bin_result.filename,
                                message=msg,
                            ),
                        )
                    except OSError as exc:
                        self._restResultForUi.emit(
                            kind,
                            logger_id,
                            ReportDownloadResult(
                                ok=False,
                                http_status=0,
                                message=f"Không ghi được file: {exc}",
                            ),
                        )
                else:
                    self._restResultForUi.emit(kind, logger_id, bin_result)
                return
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

    def _logger_api_fields(self, logger_id: int) -> dict[str, Any]:
        """Lấy api_token/api_port/api_base_url từ DB để enrich configFetched."""
        try:
            with get_session() as session:
                row = session.get(LoggerInfo, logger_id)
                if row is None:
                    return {}
                return {
                    "api_token": row.api_token or "",
                    "api_port": row.api_port,
                    "api_base_url": row.api_base_url or "",
                }
        except Exception:  # noqa: BLE001
            return {}

    @Slot(str, int, object)
    def _emit_rest_signal(self, kind: str, logger_id: int, result: object) -> None:
        if kind == "download_report":
            if isinstance(result, ReportDownloadResult):
                self.reportDownloaded.emit(
                    logger_id, result.ok, result.message or "Download failed"
                )
            return
        if not isinstance(result, ConfigResponse):
            return
        base_payload: dict[str, Any] = {
            "ok": result.ok,
            "http_status": result.http_status,
            "applied_revision": result.applied_revision,
            "revision": result.revision,
            "request_id": result.request_id,
            "errors": result.errors,
            "message": result.message,
            "config": result.config,
        }
        if kind == "get_config":
            # Merge DB fields so QML Edit form always loads correct token/port/url.
            base_payload.update(self._logger_api_fields(logger_id))
            if result.ok and result.raw:
                cfg_body = result.config or result.raw.get("config") or {}
                if isinstance(cfg_body, dict):
                    self._cache_edge_poll_from_config(logger_id, cfg_body)
                sensors_raw = extract_sensors_from_config_raw(result.raw)
                catalog = parse_catalog_from_rest(sensors_raw)
                self._sensor_catalog[logger_id] = catalog
                self._refresh_merged_snapshot(logger_id)
                base_payload["sensors"] = catalog
                if not catalog:
                    log.warning(
                        "GET /config OK nhưng không parse được sensors[] logger_id=%s",
                        logger_id,
                    )
                self._request_readings_if_needed(logger_id, force=True)
            self._catalog_fetch_pending.discard(logger_id)
        elif kind == "get_readings":
            self._readings_fetch_pending.discard(logger_id)
            if result.ok and result.raw:
                sensors = extract_sensors_from_readings_raw(result.raw)
                self._last_rest_readings[logger_id] = sensors
                self._refresh_merged_snapshot(logger_id)
            else:
                msg = result.error_summary or result.message or "GET /readings failed"
                log.warning("GET /readings logger_id=%s: %s", logger_id, msg)
                self.readingsError.emit(logger_id, msg)
            return
        payload = json.dumps(base_payload, ensure_ascii=False)
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
            if result.ok and isinstance(result.config, dict):
                self._cache_edge_poll_from_config(logger_id, result.config)
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
        """Load enabled loggers từ DB, đồng thời xóa các row 'rác'.

        Các phiên bản trước có thể tạo logger với name/host trống hoặc port=0
        do dialog Add chưa validate. Khi khởi động ta dọn sạch chúng để UI
        không hiển thị hàng `":0 (Unit: 0)"` vô nghĩa.
        """
        with get_session() as session:
            from sqlmodel import select

            rows = list(session.exec(select(LoggerInfo)).all())
            valid: list[LoggerInfo] = []
            removed = 0
            for row in rows:
                if (
                    not (row.name or "").strip()
                    or not (row.host or "").strip()
                    or (row.port or 0) <= 0
                    or (row.unit_id or 0) <= 0
                ):
                    log.warning(
                        "removing invalid logger row id=%s name=%r host=%r port=%s unit=%s",
                        row.id,
                        row.name,
                        row.host,
                        row.port,
                        row.unit_id,
                    )
                    session.delete(row)
                    removed += 1
                    continue
                if not row.enabled:
                    continue
                valid.append(row)
            if removed:
                session.commit()
        for row in valid:
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
            poll_interval_s=row.poll_interval_s,
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
            self._persist_readings(config.id, outcome)
            self._cache_sensors(config.id, outcome.snapshot)
            if prev_online is False:
                self._log_event(
                    config.id, config.name, "Online", "Logger online", "info"
                )
            if hdr.any_alarm and outcome.snapshot is not None:
                alarm_count = sum(1 for s in outcome.snapshot.sensors if s.alarm)
                if alarm_count > 0:
                    self._log_event_dedup(
                        config.id,
                        config.name,
                        "Alarm",
                        f"Alarm active on {alarm_count} sensor(s)",
                        "critical",
                    )
            self.snapshotApplied.emit(config.id, True, now_iso())
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
                    config.id, config.name, "Offline",
                    outcome.error or "Logger went offline", "error",
                )
            self.snapshotApplied.emit(config.id, False, outcome.error)
        self._sync_header_stats()

    def _is_online(self, logger_id: int) -> bool | None:
        if self._model is None:
            return None
        for it in self._model._items:  # noqa: SLF001
            if it.id == logger_id:
                return it.online
        return None

    def _modbus_sensors_from_snapshot(self, snapshot: Any) -> list[dict[str, Any]]:
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

    def _build_snapshot_payload(
        self, logger_id: int, snapshot: Any, modbus_sensors: list[dict[str, Any]]
    ) -> dict[str, Any]:
        catalog = self._sensor_catalog.get(logger_id)
        rest = self._last_rest_readings.get(logger_id)
        merged = merge_sensor_rows(
            catalog,
            modbus_sensors,
            rest,
            **self._merge_kwargs(logger_id, snapshot),
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

    def _refresh_merged_snapshot(self, logger_id: int) -> None:
        """Re-merge last Modbus raw readings with updated REST catalog."""
        catalog = self._sensor_catalog.get(logger_id)
        if not catalog:
            return
        modbus_raw = self._last_modbus_raw.get(logger_id, [])
        prev = self._last_snapshot.get(logger_id) or {}
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
                self._last_rest_readings.get(logger_id),
                **self._merge_kwargs(logger_id),
            ),
            "has_catalog": True,
        }
        self._last_snapshot[logger_id] = payload
        self.sensorsUpdated.emit(logger_id, json.dumps(payload, ensure_ascii=False))

    @Slot(int)
    def refreshSensorList(self, logger_id: int) -> None:
        """QML: re-apply catalog merge after GET /config (names without waiting for poll)."""
        self._refresh_merged_snapshot(logger_id)

    def _cache_sensors(self, logger_id: int, snapshot: Any) -> None:
        """Lưu snapshot gần nhất + emit signal để UI Detail cập nhật realtime."""
        modbus_sensors = self._modbus_sensors_from_snapshot(snapshot)
        self._last_modbus_raw[logger_id] = modbus_sensors
        if not self._sensor_catalog.get(logger_id):
            self._request_sensor_catalog_if_needed(logger_id)
        else:
            self._request_readings_if_needed(logger_id)
        payload = self._build_snapshot_payload(logger_id, snapshot, modbus_sensors)
        self._last_snapshot[logger_id] = payload
        self._append_poll_history(logger_id, modbus_sensors)
        self.sensorsUpdated.emit(logger_id, json.dumps(payload, ensure_ascii=False))

    def _append_poll_history(self, logger_id: int, sensors: list[dict[str, Any]]) -> None:
        from datetime import datetime, timezone

        tz = _chart_timezone()
        now = datetime.now(timezone.utc)
        label = now.astimezone(tz).strftime("%H:%M:%S")
        values = {int(s["sensor_id"]): float(s["value"]) for s in sensors}
        hist = self._poll_history.setdefault(
            logger_id, deque(maxlen=POLL_HISTORY_MAX)
        )
        hist.append({"label": label, "values": values})

    @Slot(int, result="QString")
    def latestReadings(self, logger_id: int) -> str:
        """JSON snapshot gần nhất; QML gọi khi mở Detail để render ngay không chờ poll."""
        payload = self._last_snapshot.get(logger_id)
        return json.dumps(payload, ensure_ascii=False) if payload else ""

    # ----- events -----
    # Khi maintenance_mode bật, các event "Alarm" / "Offline" / "Warning"
    # sẽ bị bỏ qua để tránh nhiễu khi vận hành; chỉ giữ event "Info" / "Online".
    _SUPPRESSIBLE_EVENT_TYPES = {"Alarm", "Offline", "Warning"}

    def _maintenance_mode_enabled(self) -> bool:
        try:
            with get_session() as session:
                row = session.get(AppSettings, 1)
                return bool(row.maintenance_mode) if row else False
        except Exception:  # noqa: BLE001
            return False

    def _log_event(
        self,
        logger_id: int | None,
        logger_name: str,
        event_type: str,
        message: str,
        level: str,
    ) -> None:
        if event_type in self._SUPPRESSIBLE_EVENT_TYPES and self._maintenance_mode_enabled():
            return
        try:
            with get_session() as session:
                session.add(
                    SystemEvent(
                        logger_id=logger_id,
                        logger_name=logger_name or "",
                        event_type=event_type,
                        message=message,
                        level=level,
                    )
                )
                session.commit()
            if logger_id is not None:
                self._last_event_key[(logger_id, event_type)] = message
            self.eventsChanged.emit()
        except Exception:  # noqa: BLE001
            log.exception("log_event failed: %s/%s", event_type, message)

    def _log_event_dedup(
        self,
        logger_id: int,
        logger_name: str,
        event_type: str,
        message: str,
        level: str,
    ) -> None:
        key = (logger_id, event_type)
        if self._last_event_key.get(key) == message:
            return
        self._log_event(logger_id, logger_name, event_type, message, level)

    @Slot(int, result="QString")
    def getRecentEvents(self, limit: int = 20) -> str:
        """Trả về JSON array các sự kiện mới nhất (sắp xếp giảm dần theo thời gian)."""
        if limit <= 0:
            limit = 20
        try:
            with get_session() as session:
                rows = session.exec(
                    select(SystemEvent)
                    .order_by(SystemEvent.created_at.desc())  # type: ignore[union-attr]
                    .limit(limit)
                ).all()
        except Exception:  # noqa: BLE001
            log.exception("getRecentEvents failed")
            return "[]"
        events = [
            {
                "id": r.id,
                "type": r.event_type,
                "logger": r.logger_name,
                "loggerId": r.logger_id,
                "message": r.message,
                "level": r.level,
                "time": _humanize_age(r.created_at),
                "iso": r.created_at.isoformat() if r.created_at else "",
            }
            for r in rows
        ]
        return json.dumps(events, ensure_ascii=False)

    # ----- charts -----
    @Slot(result="QString")
    def getIngestionChart24h(self) -> str:
        """Ingestion chart 24h: readings + active loggers mỗi bucket 5 phút."""
        from datetime import datetime, timedelta, timezone

        tz = _chart_timezone()
        bucket_minutes = INGESTION_BUCKET_MINUTES
        hours = 24
        bucket_count = hours * 60 // bucket_minutes
        bucket_seconds = bucket_minutes * 60
        now_local = datetime.now(tz).replace(second=0, microsecond=0)
        minute_floor = (now_local.minute // bucket_minutes) * bucket_minutes
        now_local = now_local.replace(minute=minute_floor)
        start_local = now_local - timedelta(minutes=bucket_minutes * (bucket_count - 1))
        start_utc = start_local.astimezone(timezone.utc)
        buckets: list[dict[str, Any]] = []
        try:
            with get_session() as session:
                rows = session.exec(
                    select(SensorReading.logger_id, SensorReading.recorded_at).where(
                        SensorReading.recorded_at >= start_utc
                    )
                ).all()
        except Exception:  # noqa: BLE001
            log.exception("getIngestionChart24h failed")
            rows = []
        counts: dict[int, int] = {i: 0 for i in range(bucket_count)}
        active: dict[int, set[int]] = {i: set() for i in range(bucket_count)}
        for lid, ts in rows:
            if ts is None:
                continue
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            ts_local = ts.astimezone(tz)
            delta_b = int((ts_local - start_local).total_seconds() // bucket_seconds)
            if 0 <= delta_b < bucket_count:
                counts[delta_b] += 1
                active[delta_b].add(lid)
        for i in range(bucket_count):
            label = (start_local + timedelta(minutes=bucket_minutes * i)).strftime("%H:%M")
            buckets.append(
                {
                    "hour": label,
                    "readings": counts[i],
                    "activeLoggers": len(active[i]),
                }
            )
        return json.dumps(
            {
                "buckets": buckets,
                "timezone": str(tz),
                "hours": hours,
                "bucketMinutes": bucket_minutes,
            },
            ensure_ascii=False,
        )

    @Slot(int, int, result="QString")
    def getSensorTrendingChart(self, logger_id: int, hours: int = 24) -> str:
        """Trả về series 24 điểm (giá trị trung bình mỗi giờ) cho top 4 sensors."""
        from datetime import datetime, timedelta, timezone

        if hours <= 0:
            hours = 24
        tz = _chart_timezone()
        now_local = datetime.now(tz).replace(minute=0, second=0, microsecond=0)
        start_local = now_local - timedelta(hours=hours - 1)
        start_utc = start_local.astimezone(timezone.utc)
        try:
            with get_session() as session:
                rows = session.exec(
                    select(
                        SensorReading.sensor_id,
                        SensorReading.value,
                        SensorReading.recorded_at,
                    )
                    .where(SensorReading.logger_id == logger_id)
                    .where(SensorReading.recorded_at >= start_utc)
                ).all()
        except Exception:  # noqa: BLE001
            log.exception("getSensorTrendingChart failed")
            rows = []

        # bucket: sensor_id -> [ (sum, count) per hour ]
        per_sensor: dict[int, list[list[float]]] = {}
        sensor_total: dict[int, int] = {}
        for sid, value, ts in rows:
            if ts is None:
                continue
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            ts_local = ts.astimezone(tz)
            h = int((ts_local - start_local).total_seconds() // 3600)
            if not (0 <= h < hours):
                continue
            agg = per_sensor.setdefault(sid, [[0.0, 0.0] for _ in range(hours)])
            agg[h][0] += float(value)
            agg[h][1] += 1.0
            sensor_total[sid] = sensor_total.get(sid, 0) + 1

        # Merge live snapshot vào bucket giờ hiện tại (cộng dồn, không ghi đè).
        current_h = hours - 1
        payload = self._last_snapshot.get(logger_id)
        if payload:
            for s in payload.get("sensors") or []:
                sid = int(s.get("sensor_id", -1))
                if sid < 0:
                    continue
                agg = per_sensor.setdefault(sid, [[0.0, 0.0] for _ in range(hours)])
                agg[current_h][0] += float(s.get("value", 0))
                agg[current_h][1] += 1.0
                sensor_total[sid] = sensor_total.get(sid, 0) + 1

        top_sensors = sorted(sensor_total.items(), key=lambda kv: kv[1], reverse=True)[:4]
        series = []
        for sid, _count in top_sensors:
            agg = per_sensor[sid]
            values = [(s / c) if c > 0 else 0.0 for s, c in agg]
            series.append({"sensorId": sid, "label": f"Sensor {sid}", "values": values})

        labels = [(start_local + timedelta(hours=i)).strftime("%H:00") for i in range(hours)]
        return json.dumps(
            {"labels": labels, "series": series, "timezone": str(tz), "hours": hours},
            ensure_ascii=False,
        )

    def _seed_poll_history_from_db(
        self, logger_id: int, max_points: int
    ) -> list[dict[str, Any]]:
        """Nạp lịch sử poll từ DB khi deque trống (sau restart / mở Detail)."""
        from datetime import datetime, timezone

        tz = _chart_timezone()
        try:
            with get_session() as session:
                rows = session.exec(
                    select(
                        SensorReading.sensor_id,
                        SensorReading.value,
                        SensorReading.recorded_at,
                    )
                    .where(SensorReading.logger_id == logger_id)
                    .order_by(SensorReading.recorded_at.desc())  # type: ignore[union-attr]
                    .limit(max_points * 8)
                ).all()
        except Exception:  # noqa: BLE001
            log.exception("_seed_poll_history_from_db failed")
            return []

        # Group theo recorded_at (một poll = nhiều sensor cùng timestamp).
        by_ts: dict[datetime, dict[int, float]] = {}
        for sid, value, ts in reversed(rows):
            if ts is None:
                continue
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            bucket = by_ts.setdefault(ts, {})
            bucket[int(sid)] = float(value)

        points: list[dict[str, Any]] = []
        for ts, values in sorted(by_ts.items()):
            label = ts.astimezone(tz).strftime("%H:%M:%S")
            points.append({"label": label, "values": values})
        return points[-max_points:]

    def _build_poll_trending_series(
        self, logger_id: int, points: list[dict[str, Any]]
    ) -> tuple[list[str], list[dict[str, Any]]]:
        """Chọn top 4 sensor và align values theo từng poll."""
        sensor_total: dict[int, int] = {}
        for pt in points:
            for sid in pt.get("values") or {}:
                sensor_total[int(sid)] = sensor_total.get(int(sid), 0) + 1
        top_sensors = sorted(sensor_total.items(), key=lambda kv: kv[1], reverse=True)[:4]
        labels = [str(pt.get("label", "")) for pt in points]
        catalog = self._sensor_catalog.get(logger_id)
        series: list[dict[str, Any]] = []
        for sid, _count in top_sensors:
            values = [
                float((pt.get("values") or {}).get(sid, 0.0)) for pt in points
            ]
            series.append({
                "sensorId": sid,
                "label": display_name_for_sensor(catalog, sid),
                "values": values,
            })
        return labels, series

    @Slot(int, int, result="QString")
    def getSensorTrendingPollChart(self, logger_id: int, max_points: int = 120) -> str:
        """Trending theo từng poll (~max_points điểm gần nhất)."""
        if max_points <= 0:
            max_points = POLL_HISTORY_MAX
        max_points = min(max_points, POLL_HISTORY_MAX)

        hist = self._poll_history.get(logger_id)
        if hist and len(hist) > 0:
            points = list(hist)[-max_points:]
        else:
            points = self._seed_poll_history_from_db(logger_id, max_points)

        tz = _chart_timezone()
        if not points:
            return json.dumps(
                {
                    "mode": "poll",
                    "labels": [],
                    "series": [],
                    "pointCount": 0,
                    "timezone": str(tz),
                },
                ensure_ascii=False,
            )

        labels, series = self._build_poll_trending_series(logger_id, points)
        return json.dumps(
            {
                "mode": "poll",
                "labels": labels,
                "series": series,
                "pointCount": len(labels),
                "timezone": str(tz),
            },
            ensure_ascii=False,
        )

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
