"""Controller cầu nối UI <-> ModbusManager <-> Database (facade cho QML)."""

from __future__ import annotations

import asyncio
import json
import logging

from PySide6.QtCore import Property, QObject, Qt, QTimer, Signal, Slot
from PySide6.QtQml import QmlElement
from PySide6.QtWidgets import QFileDialog

from central_logger.controllers import chart_queries, logger_ops
from central_logger.controllers.event_journal import EventJournal
from central_logger.controllers.modbus_bridge import ModbusBridge
from central_logger.controllers.rest_coordinator import RestCoordinator
from central_logger.controllers.rest_facade import build_endpoint_from_row, normalize_host
from central_logger.controllers.rest_scheduler import RestScheduler
from central_logger.controllers.sensor_state import SensorState
from central_logger.db import init_db
from central_logger.db.retention import purge_old_data
from central_logger.services import ConfigResponse, LoggerConfig
from central_logger.services.qr_provision import import_provision_from_qr_image
from central_logger.utils.native_libs import is_qr_scan_available
from central_logger.viewmodels.logger_list_model import LoggerItem, LoggerListModel

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1

log = logging.getLogger(__name__)

INGESTION_BUCKET_MINUTES = 5

_IMAGE_FILTER = "Images (*.png *.jpg *.jpeg *.bmp);;All files (*)"
_REPORT_SAVE_FILTER = "Text files (*.txt);;All files (*)"


@QmlElement
class DashboardController(QObject):
    """Bridge giữa Modbus async loop và UI."""

    snapshotApplied = Signal(int, bool, str)
    sensorsUpdated = Signal(int, "QString")
    started = Signal()
    stopped = Signal()
    modelChanged = Signal()
    appStatsChanged = Signal()
    loggerRemoved = Signal(int)
    eventsChanged = Signal()
    ingestionChartJsonChanged = Signal()
    pollTrendingChartJsonChanged = Signal(int)

    configFetched = Signal(int, bool, "QString")
    configApplied = Signal(int, bool, "QString")
    healthChecked = Signal(int, bool, int, "QString")
    reportDownloaded = Signal(int, bool, "QString")
    readingsError = Signal(int, "QString")
    edgeConfigProbed = Signal(bool, "QString")

    _snapshotForUi = Signal(object, object)
    _restResultForUi = Signal(str, int, object)
    _probeForUi = Signal(bool, "QString")

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._model: LoggerListModel | None = None
        self._running = False
        self._ingestion_chart_json = ""
        self._rest_scheduler = RestScheduler()

        self._events = EventJournal(
            on_events_changed=self.eventsChanged.emit,
            on_invalidate_ingestion=self._invalidate_ingestion_chart,
        )
        self._sensors = SensorState(
            is_online=self._is_online,
            on_sensors_updated=self.sensorsUpdated.emit,
            on_invalidate_poll_trending=self._invalidate_poll_trending,
            on_invalidate_ingestion=self._invalidate_ingestion_chart,
        )
        self._rest = RestCoordinator(
            self._rest_scheduler,
            self._sensors,
            get_loop=lambda: self._modbus.loop,
            emit_rest_result=self._restResultForUi.emit,
            on_restart_modbus=lambda lid: self._modbus.restart_modbus_for(lid),
            update_model_poll=self._update_model_poll_interval,
        )
        self._modbus = ModbusBridge(
            self._sensors,
            on_snapshot_for_ui=self._snapshotForUi.emit,
            is_online=self._is_online,
            log_event=self._events.log_event,
            log_event_dedup=self._events.log_event_dedup,
            sync_header_stats=self._sync_header_stats,
            emit_snapshot_applied=self.snapshotApplied.emit,
            build_endpoint=build_endpoint_from_row,
        )
        self._sensors.set_rest_hooks(
            self._rest.request_sensor_catalog_if_needed,
            self._rest._request_readings_if_needed,
        )

        self._retention_timer = QTimer(self)
        self._retention_timer.setInterval(3_600_000)
        self._retention_timer.timeout.connect(self.purgeOldData)
        self._snapshotForUi.connect(
            self._modbus.apply_snapshot_ui, Qt.ConnectionType.QueuedConnection
        )
        self._restResultForUi.connect(self._on_rest_result, Qt.ConnectionType.QueuedConnection)
        self._probeForUi.connect(self._on_probe_result, Qt.ConnectionType.QueuedConnection)

    def _sync_header_stats(self) -> None:
        self.appStatsChanged.emit()

    def _update_model_poll_interval(self, logger_id: int, secs: int) -> None:
        if self._model is not None:
            self._model.update_connection(logger_id, poll_interval_s=secs)

    @Property(QObject, notify=modelChanged)
    def model(self) -> QObject | None:  # type: ignore[override]
        return self._model

    @model.setter
    def model(self, value: QObject) -> None:
        if self._model is value:
            return
        self._model = value  # type: ignore[assignment]
        self._modbus.set_model(self._model)
        self.modelChanged.emit()

    @Slot()
    def start(self) -> None:
        if self._running:
            return
        init_db()
        for row in logger_ops.load_enabled_loggers():
            self._modbus.add_runtime_logger(row, self._rest.rest_cache())
        self._modbus.start_loop()
        self._running = True
        self.started.emit()
        self._sync_header_stats()
        if self.purgeOldData():
            self._invalidate_ingestion_chart()
        self._retention_timer.start()

    @Slot(result=int)
    def purgeOldData(self) -> int:
        try:
            deleted = purge_old_data()
            if deleted:
                self._invalidate_ingestion_chart()
            return deleted
        except Exception:  # noqa: BLE001
            log.exception("purgeOldData failed")
            return 0

    def _invalidate_ingestion_chart(self) -> None:
        self._ingestion_chart_json = ""

    def _refresh_ingestion_chart(self) -> None:
        self._ingestion_chart_json = chart_queries.build_ingestion_chart_24h(
            bucket_minutes=INGESTION_BUCKET_MINUTES
        )
        self.ingestionChartJsonChanged.emit()

    @Property(str, notify=ingestionChartJsonChanged)
    def ingestionChartJson(self) -> str:  # type: ignore[override]
        if not self._ingestion_chart_json:
            self._refresh_ingestion_chart()
        return self._ingestion_chart_json

    def _invalidate_poll_trending(self, logger_id: int) -> None:
        self._sensors.invalidate_poll_trending(logger_id)
        self.pollTrendingChartJsonChanged.emit(logger_id)

    @Slot()
    def stop(self) -> None:
        if not self._running:
            return
        self._running = False
        self._modbus.stop_loop()
        self.stopped.emit()

    @Slot(str, result="QString")
    def importProvisionFromQrImage(self, image_path: str) -> str:
        return json.dumps(import_provision_from_qr_image(image_path), ensure_ascii=False)

    @Slot(result="QString")
    def importProvisionFromQrImageWithDialog(self) -> str:
        """Native open-file dialog, then decode provisioning QR from the image."""
        path, _ = QFileDialog.getOpenFileName(
            None,
            "Select provisioning QR image",
            "",
            _IMAGE_FILTER,
        )
        if not path:
            return json.dumps({"ok": False, "cancelled": True})
        return self.importProvisionFromQrImage(path)

    @Slot(result=bool)
    def qrScanAvailable(self) -> bool:
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
        row = logger_ops.insert_logger(
            name=(name or "").strip(),
            host=(host or "").strip(),
            port=port,
            unit_id=unit_id,
            poll_interval_s=poll_interval_s,
            api_port=api_port,
            api_token=api_token,
            enabled=enabled,
            timeout_s=timeout_s,
            note=note,
            api_base_url=api_base_url,
        )
        if row is None:
            return
        if row.enabled:
            self._modbus.add_runtime_logger(row, self._rest.rest_cache())
        else:
            self._rest.set_endpoint(row.id, build_endpoint_from_row(row))
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
        self._events.log_event(
            row.id, row.name, "Info", f"Logger added ({row.host}:{row.port})", "info"
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
        row = logger_ops.update_connection(
            logger_id,
            name=(name or "").strip(),
            host=(host or "").strip(),
            port=port,
            unit_id=unit_id,
            poll_interval_s=poll_interval_s,
            timeout_s=timeout_s,
            note=note,
        )
        if row is None:
            return
        self._rest.set_endpoint(logger_id, build_endpoint_from_row(row))
        if self._model is not None:
            self._model.update_connection(
                logger_id,
                name=row.name,
                host=row.host,
                port=port,
                unit_id=unit_id,
                poll_interval_s=max(1, int(poll_interval_s)),
                timeout_s=row.timeout_s,
                note=note.strip() or None,
            )
        if row.enabled:
            self._modbus.restart_connection(
                logger_id,
                LoggerConfig(
                    id=logger_id,
                    name=row.name,
                    host=row.host,
                    port=port,
                    unit_id=unit_id,
                    poll_interval_s=max(1, int(poll_interval_s)),
                    timeout_s=row.timeout_s,
                ),
            )

    @Slot(int, str, int, str)
    def updateLoggerApi(
        self, logger_id: int, token: str, api_port: int, api_base_url: str = ""
    ) -> None:
        row = logger_ops.update_api(
            logger_id, token=token, api_port=api_port, api_base_url=api_base_url
        )
        if row is not None:
            self._rest.set_endpoint(logger_id, build_endpoint_from_row(row))

    @Slot(int, result="QString")
    def getLoggerFormData(self, logger_id: int) -> str:
        return logger_ops.logger_form_json(logger_id)

    @Slot(int)
    def removeLogger(self, logger_id: int) -> None:
        self._modbus.remove_logger_async(logger_id)
        self._rest.pop_logger(logger_id)
        try:
            logger_ops.delete_logger_and_readings(logger_id)
        except Exception:  # noqa: BLE001
            log.exception("removeLogger: DB delete")
        if self._model is not None:
            self._model.remove_logger(logger_id)
        self._sensors.clear_logger(logger_id)
        self._events.log_event(None, "", "Info", f"Logger {logger_id} removed", "info")
        self.loggerRemoved.emit(logger_id)
        self._sync_header_stats()

    @Slot(int)
    def checkHealth(self, logger_id: int) -> None:
        self._rest.schedule_rest(logger_id, "health")

    @Slot(int)
    def fetchConfig(self, logger_id: int) -> None:
        self._rest.schedule_rest(logger_id, "get_config")

    @Slot(str, int, str, str)
    def probeEdgeConfig(
        self, host: str, api_port: int, api_token: str, api_base_url: str = ""
    ) -> None:
        clean_host = normalize_host((host or "").strip())
        token = (api_token or "").strip()
        if not clean_host or not token:
            self.edgeConfigProbed.emit(
                False,
                json.dumps(
                    {"ok": False, "message": "Host and API token are required"},
                    ensure_ascii=False,
                ),
            )
            return
        loop = self._modbus.loop
        if loop is None or not loop.is_running():
            self.edgeConfigProbed.emit(
                False,
                json.dumps(
                    {"ok": False, "message": "Background loop is not ready"},
                    ensure_ascii=False,
                ),
            )
            return
        port = api_port if api_port > 0 else 8080
        base = (api_base_url or "").strip() or None
        asyncio.run_coroutine_threadsafe(
            self._probe_edge_async(clean_host, port, token, base), loop
        )

    async def _probe_edge_async(
        self, host: str, api_port: int, token: str, api_base_url: str | None
    ) -> None:
        ok, payload = await self._rest.probe_edge(host, api_port, token, api_base_url)
        self._probeForUi.emit(ok, payload)

    @Slot(bool, "QString")
    def _on_probe_result(self, ok: bool, payload_json: str) -> None:
        self.edgeConfigProbed.emit(ok, payload_json)

    @Slot(int)
    def fetchReadings(self, logger_id: int) -> None:
        self._rest._request_readings_if_needed(logger_id, force=True)

    @Slot(int)
    def fetchReadingsIfStale(self, logger_id: int) -> None:
        if self._sensors.readings_stale(logger_id):
            return
        self._rest._request_readings_if_needed(logger_id, force=False)

    @Slot(int)
    def downloadLatestReportWithDialog(self, logger_id: int) -> None:
        """Native save dialog, then download the latest edge report."""
        path, _ = QFileDialog.getSaveFileName(
            None,
            "Save report file",
            "report.txt",
            _REPORT_SAVE_FILTER,
        )
        if not path:
            return
        path = path.strip()
        if not path:
            self.reportDownloaded.emit(logger_id, False, "Invalid save path")
            return
        self._rest.schedule_rest(logger_id, "download_report", save_path=path)

    @Slot(int, int, "QString")
    def applyConfig(self, logger_id: int, expected_revision: int, config_json: str) -> None:
        try:
            cfg = json.loads(config_json) if config_json.strip() else {}
            if not isinstance(cfg, dict):
                raise ValueError("config must be a JSON object")
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
        self._rest.schedule_rest(
            logger_id, "apply_config", expected_revision=expected_revision, config=cfg
        )

    @Slot(str, int, object)
    def _on_rest_result(self, kind: str, logger_id: int, result: object) -> None:
        self._rest.emit_rest_signal(
            kind,
            logger_id,
            result,
            emit_report=self.reportDownloaded.emit,
            emit_health=self.healthChecked.emit,
            emit_config_fetched=self.configFetched.emit,
            emit_config_applied=self.configApplied.emit,
            emit_readings_error=self.readingsError.emit,
        )

    def _is_online(self, logger_id: int) -> bool | None:
        if self._model is None:
            return None
        for it in self._model._items:  # noqa: SLF001
            if it.id == logger_id:
                return it.online
        return None

    @Slot(int)
    def refreshSensorList(self, logger_id: int) -> None:
        self._sensors.refresh_merged_snapshot(logger_id)

    @Slot(int, result="QString")
    def latestReadings(self, logger_id: int) -> str:
        return self._sensors.latest_readings_json(logger_id)

    @Slot(int, result="QString")
    def pollTrendingChartJson(self, logger_id: int) -> str:
        return self.getSensorTrendingPollChart(logger_id, chart_queries.POLL_HISTORY_MAX)

    @Slot(result="QString")
    def getIngestionChart24h(self) -> str:
        return self.ingestionChartJson

    @Slot(int, int, result="QString")
    def getSensorTrendingPollChart(
        self, logger_id: int, max_points: int = chart_queries.POLL_HISTORY_MAX
    ) -> str:
        if max_points <= 0:
            max_points = chart_queries.POLL_HISTORY_MAX
        max_points = min(max_points, chart_queries.POLL_HISTORY_MAX)
        cached = self._sensors.poll_trending_json.get(logger_id)
        if cached:
            return cached
        hist = self._sensors.poll_history.get(logger_id)
        points = list(hist)[-max_points:] if hist and len(hist) > 0 else None
        payload = chart_queries.build_sensor_trending_poll_chart(
            logger_id,
            points,
            max_points=max_points,
            sensor_catalog=self._sensors.sensor_catalog.get(logger_id),
        )
        self._sensors.poll_trending_json[logger_id] = payload
        return payload
