"""REST job execution with concurrency limit (asyncio semaphore)."""
from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

from central_logger.controllers.rest_facade import (
    RestEndpoint,
    build_endpoint_from_row,
)
from central_logger.db.models import LoggerInfo
from central_logger.services import (
    ConfigResponse,
    LoggerConfigClient,
    ReportDownloadResult,
)
from central_logger.services.sensor_catalog import (
    extract_sensors_from_config_raw,
    parse_catalog_from_rest,
)

log = logging.getLogger(__name__)

MAX_REST_CONCURRENT = 4


class RestScheduler:
    """Runs LoggerConfigClient calls under a per-event-loop semaphore."""

    def __init__(self, max_concurrent: int = MAX_REST_CONCURRENT) -> None:
        self._max = max(1, max_concurrent)
        self._semaphores: dict[int, asyncio.Semaphore] = {}

    def _sem(self) -> asyncio.Semaphore:
        loop = asyncio.get_running_loop()
        key = id(loop)
        if key not in self._semaphores:
            self._semaphores[key] = asyncio.Semaphore(self._max)
        return self._semaphores[key]

    async def run_job(
        self,
        endpoint: RestEndpoint,
        kind: str,
        **kwargs: Any,
    ) -> ConfigResponse | ReportDownloadResult:
        async with self._sem():
            client = LoggerConfigClient(endpoint)
            if kind == "health":
                return await client.health()
            if kind == "get_config":
                return await client.get_config()
            if kind == "apply_config":
                return await client.apply_config(
                    expected_revision=int(kwargs["expected_revision"]),
                    config=kwargs["config"],
                )
            if kind == "get_readings":
                return await client.get_readings()
            if kind == "download_report":
                return await client.download_latest_report()
            log.warning("REST kind không hỗ trợ: %s", kind)
            return ConfigResponse(
                ok=False,
                http_status=0,
                errors=[{"field": "", "message": f"Unsupported REST kind: {kind}"}],
            )

    async def probe_edge(
        self,
        host: str,
        api_port: int,
        token: str,
        api_base_url: str | None,
    ) -> tuple[bool, str]:
        endpoint = RestEndpoint(
            host=host,
            port=api_port,
            token=token,
            base_url_override=api_base_url,
        )
        async with self._sem():
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
                    return False, payload
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
                return bool(config.ok), payload
            except Exception as exc:  # noqa: BLE001
                log.exception("probe_edge failed")
                return False, json.dumps({"ok": False, "message": str(exc)}, ensure_ascii=False)


def endpoint_from_row(row: LoggerInfo) -> RestEndpoint:
    return build_endpoint_from_row(row)
