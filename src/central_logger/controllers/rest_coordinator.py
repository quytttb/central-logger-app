"""REST scheduling, cache, and UI signal emission for logger remote config."""

from __future__ import annotations

import asyncio
import json
import logging
import time
from collections.abc import Callable
from typing import Any

from central_logger.controllers import logger_ops
from central_logger.controllers.rest_facade import RestEndpoint, endpoint_from_row
from central_logger.controllers.rest_scheduler import RestScheduler
from central_logger.controllers.sensor_state import SensorState
from central_logger.db import LoggerInfo, get_session
from central_logger.services import ConfigResponse, ReportDownloadResult
from central_logger.services.sensor_catalog import (
    extract_sensors_from_config_raw,
    extract_sensors_from_readings_raw,
    parse_catalog_from_rest,
)

log = logging.getLogger(__name__)


class RestCoordinator:
    def __init__(
        self,
        scheduler: RestScheduler,
        sensors: SensorState,
        *,
        get_loop: Callable[[], asyncio.AbstractEventLoop | None],
        emit_rest_result: Callable[[str, int, object], None],
        on_restart_modbus: Callable[[int], None],
        update_model_poll: Callable[[int, int], None],
        is_online: Callable[[int], bool | None] | None = None,
    ) -> None:
        self._scheduler = scheduler
        self._sensors = sensors
        self._get_loop = get_loop
        self._emit_rest_result = emit_rest_result
        self._on_restart_modbus = on_restart_modbus
        self._update_model_poll = update_model_poll
        self._is_online = is_online

        self._rest_cache: dict[int, RestEndpoint] = {}
        self._catalog_fetch_pending: set[int] = set()
        self._catalog_fetch_last: dict[int, float] = {}
        self._readings_fetch_pending: set[int] = set()
        self._readings_fetch_last: dict[int, float] = {}
        self._edge_poll_interval: dict[int, int] = {}

    def rest_cache(self) -> dict[int, RestEndpoint]:
        return self._rest_cache

    def set_endpoint(self, logger_id: int, endpoint: RestEndpoint) -> None:
        self._rest_cache[logger_id] = endpoint

    def pop_logger(self, logger_id: int) -> None:
        self._rest_cache.pop(logger_id, None)
        self.reset_fetch_state(logger_id)

    def reset_fetch_state(self, logger_id: int) -> None:
        """Clear pending REST fetch timers after connection/API changes."""
        self._catalog_fetch_pending.discard(logger_id)
        self._readings_fetch_pending.discard(logger_id)
        self._catalog_fetch_last.pop(logger_id, None)
        self._readings_fetch_last.pop(logger_id, None)
        self._edge_poll_interval.pop(logger_id, None)

    def _logger_is_online(self, logger_id: int) -> bool:
        if self._is_online is None:
            return True
        state = self._is_online(logger_id)
        return bool(state) if state is not None else False

    def reload_endpoint(self, logger_id: int) -> RestEndpoint | None:
        try:
            with get_session() as session:
                row = session.get(LoggerInfo, logger_id)
                if row is None:
                    return None
                ep = endpoint_from_row(row)
                self._rest_cache[logger_id] = ep
                return ep
        except Exception:  # noqa: BLE001
            log.exception("reload_endpoint logger_id=%s", logger_id)
            return None

    def schedule_rest(self, logger_id: int, kind: str, **kwargs: Any) -> None:
        endpoint = self._rest_cache.get(logger_id)
        if endpoint is None:
            endpoint = self.reload_endpoint(logger_id)
        if endpoint is None:
            self._emit_rest_result(
                kind,
                logger_id,
                ConfigResponse(
                    ok=False,
                    http_status=0,
                    errors=[{"field": "", "message": "Logger not loaded (REST cache empty)"}],
                ),
            )
            return
        if not endpoint.token and kind != "health":
            endpoint = self.reload_endpoint(logger_id) or endpoint
        if not endpoint.token and kind != "health":
            self._emit_rest_result(
                kind,
                logger_id,
                ConfigResponse(
                    ok=False,
                    http_status=401,
                    errors=[{"field": "api_token", "message": "API token is not configured"}],
                ),
            )
            return
        if kind == "get_readings" and not self._logger_is_online(logger_id):
            return
        loop = self._get_loop()
        if loop is None or not loop.is_running():
            self._emit_rest_result(
                kind,
                logger_id,
                ConfigResponse(
                    ok=False,
                    http_status=0,
                    errors=[{"field": "", "message": "Asyncio loop is not ready"}],
                ),
            )
            return
        asyncio.run_coroutine_threadsafe(self._run_rest(logger_id, endpoint, kind, **kwargs), loop)

    async def probe_edge(
        self, host: str, api_port: int, token: str, api_base_url: str | None
    ) -> tuple[bool, str]:
        return await self._scheduler.probe_edge(host, api_port, token, api_base_url)

    async def _run_rest(
        self, logger_id: int, endpoint: RestEndpoint, kind: str, **kwargs: Any
    ) -> None:
        try:
            if kind == "download_report":
                bin_result = await self._scheduler.run_job(endpoint, kind, **kwargs)
                if not isinstance(bin_result, ReportDownloadResult):
                    return
                save_path = str(kwargs.get("save_path", ""))
                if bin_result.ok and save_path:
                    try:
                        with open(save_path, "wb") as fh:
                            fh.write(bin_result.content)
                        msg = f"Saved {bin_result.filename}"
                        self._emit_rest_result(
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
                        self._emit_rest_result(
                            kind,
                            logger_id,
                            ReportDownloadResult(
                                ok=False,
                                http_status=0,
                                message=f"Could not write file: {exc}",
                            ),
                        )
                else:
                    self._emit_rest_result(kind, logger_id, bin_result)
                return
            result = await self._scheduler.run_job(endpoint, kind, **kwargs)
            if not isinstance(result, ConfigResponse):
                return
        except Exception as exc:  # noqa: BLE001
            log.exception("REST %s lỗi không mong đợi", kind)
            result = ConfigResponse(
                ok=False, http_status=0, errors=[{"field": "", "message": str(exc)}]
            )

        if kind in ("get_config", "apply_config") and result.ok:
            new_rev = result.applied_revision if kind == "apply_config" else result.revision
            if new_rev is not None:
                logger_ops.save_last_revision(logger_id, int(new_rev))

        if kind == "apply_config" and result.ok:
            self._on_restart_modbus(logger_id)

        self._emit_rest_result(kind, logger_id, result)

    def emit_rest_signal(
        self,
        kind: str,
        logger_id: int,
        result: object,
        *,
        emit_report: Callable[[int, bool, str], None],
        emit_health: Callable[[int, bool, int, str], None],
        emit_config_fetched: Callable[[int, bool, str], None],
        emit_config_applied: Callable[[int, bool, str], None],
        emit_readings_error: Callable[[int, str], None],
    ) -> None:
        if kind == "download_report":
            if isinstance(result, ReportDownloadResult):
                emit_report(logger_id, result.ok, result.message or "Download failed")
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
            base_payload.update(logger_ops.logger_api_fields(logger_id))
            if result.ok and result.raw:
                cfg_body = result.config or result.raw.get("config") or {}
                if isinstance(cfg_body, dict):
                    self._cache_edge_poll_from_config(logger_id, cfg_body)
                sensors_raw = extract_sensors_from_config_raw(result.raw)
                catalog = parse_catalog_from_rest(sensors_raw)
                self._sensors.sensor_catalog[logger_id] = catalog
                self._sensors.refresh_merged_snapshot(logger_id)
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
                self._sensors.last_rest_readings[logger_id] = sensors
                self._sensors.refresh_merged_snapshot(logger_id)
            else:
                msg = result.error_summary or result.message or "GET /readings failed"
                log.warning("GET /readings logger_id=%s: %s", logger_id, msg)
                emit_readings_error(logger_id, msg)
            return
        payload = json.dumps(base_payload, ensure_ascii=False)
        if kind == "health":
            emit_health(
                logger_id,
                result.ok,
                int(result.revision or -1),
                result.message or result.error_summary or "",
            )
        elif kind == "get_config":
            emit_config_fetched(logger_id, result.ok, payload)
        elif kind == "apply_config":
            if result.ok and isinstance(result.config, dict):
                self._cache_edge_poll_from_config(logger_id, result.config)
            emit_config_applied(logger_id, result.ok, payload)

    def request_sensor_catalog_if_needed(self, logger_id: int) -> None:
        if self._sensors.sensor_catalog.get(logger_id):
            return
        if logger_id in self._catalog_fetch_pending:
            return
        now = time.monotonic()
        if now - self._catalog_fetch_last.get(logger_id, 0.0) < 60.0:
            return
        endpoint = self._rest_cache.get(logger_id) or self.reload_endpoint(logger_id)
        if endpoint is None or not endpoint.token:
            return
        self._catalog_fetch_last[logger_id] = now
        self._catalog_fetch_pending.add(logger_id)
        self.schedule_rest(logger_id, "get_config")

    def _catalog_has_digital(self, logger_id: int) -> bool:
        cat = self._sensors.sensor_catalog.get(logger_id) or []
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
                    self._update_model_poll(logger_id, secs)
        except (TypeError, ValueError):
            pass

    def _request_readings_if_needed(self, logger_id: int, *, force: bool = False) -> None:
        if not self._logger_is_online(logger_id):
            return
        if not force and not self._catalog_has_digital(logger_id):
            return
        if logger_id in self._readings_fetch_pending:
            return
        now = time.monotonic()
        interval_s = self._edge_poll_interval_s(logger_id)
        if not force and now - self._readings_fetch_last.get(logger_id, 0.0) < interval_s:
            return
        endpoint = self._rest_cache.get(logger_id) or self.reload_endpoint(logger_id)
        if endpoint is None or not endpoint.token:
            return
        self._readings_fetch_last[logger_id] = now
        self._readings_fetch_pending.add(logger_id)
        self.schedule_rest(logger_id, "get_readings")
