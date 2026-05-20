"""ModbusManager - 1 asyncio.Task / device + exponential backoff khi mất kết nối.

Phát signal về Qt main thread thông qua callbacks (do controller cấu hình)
hoặc trực tiếp tới `LoggerListModel`. Manager chính nó *không* phụ thuộc Qt
để dễ unit test bằng pytest-asyncio.
"""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from datetime import datetime, timezone

from central_logger.services.modbus_client import LoggerConfig, LoggerModbusClient, ReadOutcome

log = logging.getLogger(__name__)

SnapshotCallback = Callable[[LoggerConfig, ReadOutcome], None | Awaitable[None]]


class ModbusManager:
    """Quản lý nhiều logger - mỗi logger 1 task polling độc lập."""

    def __init__(self, on_snapshot: SnapshotCallback | None = None) -> None:
        self._tasks: dict[int, asyncio.Task] = {}
        self._clients: dict[int, LoggerModbusClient] = {}
        self._configs: dict[int, LoggerConfig] = {}
        self._on_snapshot = on_snapshot
        self._stopped = asyncio.Event()

    # ----- lifecycle -----
    def add_logger(self, config: LoggerConfig) -> None:
        if config.id in self._configs:
            raise ValueError(f"Logger id {config.id} đã tồn tại")
        self._configs[config.id] = config
        self._clients[config.id] = LoggerModbusClient(config)

    def remove_logger(self, logger_id: int) -> None:
        """Đồng bộ — chỉ dùng trong tests hoặc khi đã chắc đang trên cùng event loop với manager."""
        task = self._tasks.pop(logger_id, None)
        if task and not task.done():
            task.cancel()
        client = self._clients.pop(logger_id, None)
        if client:
            asyncio.create_task(client.close())
        self._configs.pop(logger_id, None)

    async def remove_logger_async(self, logger_id: int) -> None:
        """Gỡ logger khỏi manager: hủy task poll, đóng client, xóa config.

        Phải gọi trên **cùng** event loop với các coroutine Modbus (thread Modbus của Central).
        """
        task = self._tasks.pop(logger_id, None)
        if task is not None:
            if not task.done():
                task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
            except Exception:  # noqa: BLE001
                log.debug("remove_logger_async await task", exc_info=True)
        client = self._clients.pop(logger_id, None)
        if client is not None:
            try:
                await client.close()
            except Exception:  # noqa: BLE001
                log.exception("remove_logger_async close client")
        self._configs.pop(logger_id, None)

    def start(self) -> None:
        self._stopped.clear()
        for logger_id in list(self._configs):
            self._ensure_task(logger_id)

    def _ensure_task(self, logger_id: int) -> None:
        existing = self._tasks.get(logger_id)
        if existing and not existing.done():
            return
        self._tasks[logger_id] = asyncio.create_task(
            self._run_poll_loop(logger_id), name=f"modbus-poll-{logger_id}"
        )

    async def stop(self) -> None:
        self._stopped.set()
        for task in self._tasks.values():
            task.cancel()
        if self._tasks:
            await asyncio.gather(*self._tasks.values(), return_exceptions=True)
        for client in self._clients.values():
            await client.close()
        self._tasks.clear()

    # ----- polling -----
    async def _run_poll_loop(self, logger_id: int) -> None:
        config = self._configs[logger_id]
        client = self._clients[logger_id]
        backoff = config.backoff_start_s
        interval = max(float(config.poll_interval_s), 0.05)

        try:
            while not self._stopped.is_set():
                outcome = await client.read_snapshot()
                await self._dispatch(config, outcome)

                if outcome.ok:
                    backoff = config.backoff_start_s
                    await self._sleep(interval)
                else:
                    log.info(
                        "logger %s read failed: %s (tcp=%s) backoff=%.1fs",
                        config.name,
                        outcome.error,
                        outcome.tcp_connected,
                        backoff,
                    )
                    await self._sleep(backoff)
                    backoff = min(backoff * 2, config.backoff_max_s)
        except asyncio.CancelledError:
            raise
        except Exception:  # noqa: BLE001
            log.exception("poll loop crashed for %s", config.name)
        finally:
            await client.close()

    async def _sleep(self, seconds: float) -> None:
        try:
            await asyncio.wait_for(self._stopped.wait(), timeout=seconds)
        except asyncio.TimeoutError:
            pass

    async def _dispatch(self, config: LoggerConfig, outcome: ReadOutcome) -> None:
        if self._on_snapshot is None:
            return
        try:
            result = self._on_snapshot(config, outcome)
            if asyncio.iscoroutine(result):
                await result
        except Exception:  # noqa: BLE001
            log.exception("snapshot callback failed for %s", config.name)


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M:%S")
