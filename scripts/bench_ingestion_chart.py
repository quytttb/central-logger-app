#!/usr/bin/env python3
"""Benchmark build_ingestion_chart_24h; optional --seed N rows into temp DB."""
from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))


def _seed(db_url: str, count: int, logger_id: int = 1) -> None:
    from central_logger.db import SensorReading, get_session, init_db
    from central_logger.db import session as db_session

    os.environ["CENTRAL_LOGGER_DB_URL"] = db_url
    db_session._engine = None  # noqa: SLF001
    init_db()
    now = datetime.now(timezone.utc)
    with get_session() as session:
        for i in range(count):
            session.add(
                SensorReading(
                    logger_id=logger_id,
                    sensor_id=1 + (i % 10),
                    value=float(i % 100),
                    recorded_at=now - timedelta(seconds=i * 30),
                )
            )
        session.commit()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=0, help="Insert N sensor_reading rows first")
    parser.add_argument("--runs", type=int, default=5)
    args = parser.parse_args()

    db_path = ROOT / "dist" / "bench_ingestion.db"
    db_path.parent.mkdir(parents=True, exist_ok=True)
    db_url = f"sqlite:///{db_path}"
    os.environ["CENTRAL_LOGGER_DB_URL"] = db_url

    from central_logger.db import init_db
    from central_logger.db import session as db_session

    db_session._engine = None  # noqa: SLF001
    init_db()
    if args.seed > 0:
        print(f"Seeding {args.seed} rows into {db_path}...")
        _seed(db_url, args.seed)
        db_session._engine = None  # noqa: SLF001

    from central_logger.controllers import chart_queries
    times_ms: list[float] = []
    for _ in range(args.runs):
        t0 = time.perf_counter()
        chart_queries.build_ingestion_chart_24h()
        times_ms.append((time.perf_counter() - t0) * 1000)
    avg = sum(times_ms) / len(times_ms)
    print(f"build_ingestion_chart_24h: avg={avg:.1f} ms  min={min(times_ms):.1f}  max={max(times_ms):.1f}")
    if args.seed:
        print(f"  (DB ~{args.seed} readings in {db_path})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
