"""REST endpoint helpers — shared by DashboardController and probes."""

from __future__ import annotations

from central_logger.db.models import LoggerInfo
from central_logger.services.rest_config_client import RestEndpoint


def normalize_host(host: str) -> str:
    """Prefer IPv4 loopback when host is ``localhost`` (some stacks resolve IPv6 first)."""
    h = host.strip()
    if h.lower() == "localhost":
        return "127.0.0.1"
    return h


def build_endpoint_from_row(row: LoggerInfo) -> RestEndpoint:
    return RestEndpoint(
        host=normalize_host(row.host),
        port=row.api_port or 8080,
        token=row.api_token,
        base_url_override=row.api_base_url,
    )


endpoint_from_row = build_endpoint_from_row
