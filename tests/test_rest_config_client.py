"""Tests cho LoggerConfigClient — mock transport bằng httpx.MockTransport."""

from __future__ import annotations

import json

import httpx
import pytest

from central_logger.services.rest_config_client import (
    LoggerConfigClient,
    RestEndpoint,
)


@pytest.fixture
def endpoint():
    return RestEndpoint(host="127.0.0.1", port=8080, token="dev-token", timeout_s=2.0)


def _mock_client(handler):
    """Patch httpx.AsyncClient để dùng MockTransport(handler)."""

    class _Patched(httpx.AsyncClient):
        def __init__(self, *args, **kwargs):
            kwargs.setdefault("transport", httpx.MockTransport(handler))
            super().__init__(*args, **kwargs)

    return _Patched


@pytest.mark.asyncio
async def test_health_ok(monkeypatch, endpoint):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "GET"
        assert request.url.path == "/api/v1/health"
        assert "Authorization" not in request.headers
        return httpx.Response(200, json={"ok": True, "revision": 5, "message": "ok"})

    monkeypatch.setattr(
        "central_logger.services.rest_config_client.httpx.AsyncClient",
        _mock_client(handler),
    )
    res = await LoggerConfigClient(endpoint).health()
    assert res.ok and res.http_status == 200 and res.revision == 5


@pytest.mark.asyncio
async def test_get_config_uses_bearer(monkeypatch, endpoint):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer dev-token"
        return httpx.Response(
            200,
            json={
                "ok": True,
                "revision": 7,
                "config": {"poll_interval": 10, "station_code": "TRAM-001"},
            },
        )

    monkeypatch.setattr(
        "central_logger.services.rest_config_client.httpx.AsyncClient",
        _mock_client(handler),
    )
    res = await LoggerConfigClient(endpoint).get_config()
    assert res.ok and res.revision == 7
    assert res.config["poll_interval"] == 10


@pytest.mark.asyncio
async def test_apply_config_conflict_409(monkeypatch, endpoint):
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["body"] = json.loads(request.content.decode())
        return httpx.Response(
            409,
            json={
                "ok": False,
                "request_id": captured["body"]["request_id"],
                "applied_revision": 6,
                "errors": [{"field": "expected_revision", "message": "conflict"}],
            },
        )

    monkeypatch.setattr(
        "central_logger.services.rest_config_client.httpx.AsyncClient",
        _mock_client(handler),
    )
    res = await LoggerConfigClient(endpoint).apply_config(
        expected_revision=5, config={"poll_interval": 10}
    )
    assert not res.ok
    assert res.http_status == 409
    assert res.applied_revision == 6
    assert "conflict" in res.error_summary
    body = captured["body"]
    assert body["api_version"] == 1
    assert body["expected_revision"] == 5
    assert body["config"] == {"poll_interval": 10}
    assert body["request_id"].startswith("central-")


@pytest.mark.asyncio
async def test_apply_config_validation_400(monkeypatch, endpoint):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            400,
            json={
                "ok": False,
                "errors": [{"field": "config.modbus_tcp_bind", "message": "required"}],
            },
        )

    monkeypatch.setattr(
        "central_logger.services.rest_config_client.httpx.AsyncClient",
        _mock_client(handler),
    )
    res = await LoggerConfigClient(endpoint).apply_config(expected_revision=6, config={})
    assert not res.ok and res.http_status == 400
    assert res.errors[0]["field"] == "config.modbus_tcp_bind"


@pytest.mark.asyncio
async def test_network_error_returns_structured(monkeypatch, endpoint):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("refused", request=request)

    monkeypatch.setattr(
        "central_logger.services.rest_config_client.httpx.AsyncClient",
        _mock_client(handler),
    )
    res = await LoggerConfigClient(endpoint).get_config()
    assert not res.ok and res.http_status == 0
    assert "network" in res.error_summary
