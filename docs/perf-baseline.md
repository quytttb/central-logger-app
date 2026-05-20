# Performance baseline (Central Logger App)

Ghi lại sau mỗi lần tối ưu lớn (Pass 2+). Chạy trên máy dev với DB mặc định hoặc seed test.

## Source size

```bash
wc -l src/central_logger/controllers/*.py src/central_logger/viewmodels/*.py
wc -l src/central_logger/controllers/dashboard_controller.py
```

| Pass | `dashboard_controller.py` | `controllers/*.py` total | pytest |
|------|---------------------------|-------------------------|--------|
| 2 | &lt; 700 (tách `logger_ops`, `chart_queries`, REST facade) | ~1.8k | 71 passed |
| 4 | **465** (facade; logic trong plain helpers) | **2114** | 75 passed (incl. smoke) |

Pass 4 helpers (không `@QmlElement`): `event_journal.py`, `sensor_state.py`, `rest_coordinator.py`, `modbus_bridge.py`. QML contract vẫn chỉ trên `DashboardController`. Smoke: [`smoke-validation.md`](smoke-validation.md).

## Tests

```bash
QT_QPA_PLATFORM=offscreen uv run pytest -q
```

## Ingestion chart query

Với DB lớn (~100k `sensor_reading`):

```bash
uv run python scripts/bench_ingestion_chart.py --seed 100000 --runs 5
```

Kết quả mẫu (2026-05-19, SQLite): empty DB ~11 ms avg; 100k rows ~3.4 ms avg (`GROUP BY` bucket).

SQLite plan (optional):

```sql
EXPLAIN QUERY PLAN
SELECT CAST((strftime('%s', recorded_at) - :start_epoch) / :bucket_sec AS INTEGER) AS bidx,
       COUNT(*) AS readings,
       COUNT(DISTINCT logger_id) AS active_loggers
FROM sensor_reading
WHERE recorded_at >= :start_utc
GROUP BY bidx;
```

## Deploy folder size (Windows / Linux)

Sau `pyside6-deploy`:

```bash
du -sh deploy/   # hoặc thư mục output Nuitka trên Windows
```
