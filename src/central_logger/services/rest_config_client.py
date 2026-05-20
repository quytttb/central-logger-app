"""REST client cho Remote Config API v1 trên Data Logger.

Contract (theo `docs/rest-config-contract-v1`):
    - Base URL mặc định: http://<host>:<port>/api/v1
    - GET  /health               (no auth)  -> {ok, revision, ...}
    - GET  /config               (Bearer)   -> {api_version, revision, config: {...}}
    - GET  /readings             (Bearer)   -> live sensor values (DI/DO + analog fallback)
    - GET  /reports/latest       (Bearer)   -> latest TXT report file
    - POST /config               (Bearer)   -> body: {api_version, request_id,
                                                     expected_revision, config: {...}}
                                              200 -> {ok, applied_revision, errors, ...}
                                              4xx/409 -> body cùng format, ok=false

Mọi method đều **async** (dùng `httpx.AsyncClient`); chạy bên trong asyncio loop
của Modbus thread thông qua `run_coroutine_threadsafe` từ Qt.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from typing import Any

import httpx

log = logging.getLogger(__name__)


@dataclass(slots=True)
class RestEndpoint:
    """Cấu hình điểm cuối REST của một Data Logger."""

    host: str
    port: int = 8080
    token: str | None = None
    base_url_override: str | None = None  # vd. https://logger.local/api/v1
    timeout_s: float = 20.0
    verify_tls: bool = True

    def base_url(self) -> str:
        if self.base_url_override:
            return self.base_url_override.rstrip("/")
        return f"http://{self.host}:{self.port}/api/v1"


@dataclass
class ReportDownloadResult:
    ok: bool
    http_status: int
    content: bytes = b""
    filename: str = ""
    message: str = ""
    errors: list[dict[str, Any]] = field(default_factory=list)


@dataclass
class ConfigResponse:
    """Bao gói response chuẩn `{ok, errors, applied_revision, ...}`."""

    ok: bool
    http_status: int
    applied_revision: int | None = None
    revision: int | None = None  # cho GET /config / /health
    request_id: str | None = None
    errors: list[dict[str, Any]] = field(default_factory=list)
    message: str = ""
    config: dict[str, Any] = field(default_factory=dict)
    raw: dict[str, Any] | None = None

    @property
    def error_summary(self) -> str:
        if not self.errors:
            return self.message or ""
        return "; ".join(f"{e.get('field', '?')}: {e.get('message', '')}" for e in self.errors)


def _parse_response(resp: httpx.Response) -> ConfigResponse:
    """Parse response từ edge - hợp lệ cả khi 4xx/409 nếu body đúng schema."""
    body: dict[str, Any] = {}
    try:
        body = resp.json()
        if not isinstance(body, dict):
            body = {}
    except Exception:  # noqa: BLE001
        body = {}

    errors_raw = body.get("errors") or []
    errors: list[dict[str, Any]] = []
    if isinstance(errors_raw, list):
        for e in errors_raw:
            if isinstance(e, dict):
                errors.append(e)
            else:
                errors.append({"field": "", "message": str(e)})

    return ConfigResponse(
        ok=bool(body.get("ok", resp.is_success)),
        http_status=resp.status_code,
        applied_revision=body.get("applied_revision"),
        revision=body.get("revision"),
        request_id=body.get("request_id"),
        errors=errors,
        message=str(body.get("message", "")),
        config=body.get("config") or {},
        raw=body,
    )


class LoggerConfigClient:
    """REST client cho 1 Data Logger.

    Khuyến nghị tạo client per-request (httpx.AsyncClient lifecycle ngắn) — đơn
    giản hóa, tránh cache connection cũ khi token/host thay đổi.
    """

    def __init__(self, endpoint: RestEndpoint) -> None:
        self.endpoint = endpoint

    # ----- helpers -----
    def _headers(self, auth: bool = True) -> dict[str, str]:
        h = {"Accept": "application/json"}
        if auth and self.endpoint.token:
            h["Authorization"] = f"Bearer {self.endpoint.token}"
        return h

    async def _request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict[str, Any] | None = None,
        auth: bool = True,
    ) -> ConfigResponse:
        url = f"{self.endpoint.base_url()}{path}"
        try:
            async with httpx.AsyncClient(
                timeout=self.endpoint.timeout_s,
                verify=self.endpoint.verify_tls,
            ) as cli:
                resp = await cli.request(
                    method,
                    url,
                    json=json_body,
                    headers=self._headers(auth=auth),
                )
        except httpx.HTTPError as exc:
            log.warning("REST %s %s failed: %s", method, url, exc)
            return ConfigResponse(
                ok=False,
                http_status=0,
                errors=[{"field": "", "message": f"network: {exc}"}],
            )
        return _parse_response(resp)

    # ----- public API -----
    async def health(self) -> ConfigResponse:
        """GET /health — không cần auth."""
        return await self._request("GET", "/health", auth=False)

    async def get_config(self) -> ConfigResponse:
        """GET /config — full snapshot."""
        return await self._request("GET", "/config")

    async def get_readings(self) -> ConfigResponse:
        """GET /readings — live values snapshot from edge monitor."""
        return await self._request("GET", "/readings")

    async def download_latest_report(self) -> ReportDownloadResult:
        """GET /reports/latest — binary TXT file."""
        url = f"{self.endpoint.base_url()}/reports/latest"
        try:
            async with httpx.AsyncClient(
                timeout=self.endpoint.timeout_s,
                verify=self.endpoint.verify_tls,
            ) as cli:
                resp = await cli.get(url, headers=self._headers(auth=True))
        except httpx.HTTPError as exc:
            log.warning("REST GET %s failed: %s", url, exc)
            return ReportDownloadResult(
                ok=False,
                http_status=0,
                message=str(exc),
                errors=[{"field": "", "message": f"network: {exc}"}],
            )
        if resp.status_code == 404:
            return ReportDownloadResult(
                ok=False,
                http_status=404,
                message="No report file available",
            )
        if not resp.is_success:
            return ReportDownloadResult(
                ok=False,
                http_status=resp.status_code,
                message=resp.text[:200] if resp.text else f"HTTP {resp.status_code}",
            )
        filename = "report.txt"
        cd = resp.headers.get("content-disposition", "")
        if "filename=" in cd:
            part = cd.split("filename=", 1)[1].strip().strip('"')
            if part:
                filename = part
        return ReportDownloadResult(
            ok=True,
            http_status=resp.status_code,
            content=resp.content,
            filename=filename,
        )

    async def apply_config(
        self,
        *,
        expected_revision: int,
        config: dict[str, Any],
        request_id: str | None = None,
    ) -> ConfigResponse:
        """POST /config — partial cho root, replace cho `sensors[]`."""
        payload: dict[str, Any] = {
            "api_version": 1,
            "request_id": request_id or f"central-{uuid.uuid4()}",
            "expected_revision": expected_revision,
            "config": config,
        }
        return await self._request("POST", "/config", json_body=payload)
