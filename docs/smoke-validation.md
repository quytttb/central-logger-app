# Smoke validation (post Pass 4)

Ghi lại sau khi chạy bước validate — không thay thế smoke thủ công trên máy có GUI + logger thật.

## Automated (CI / headless)

```bash
pyside6-rcc resources/resources.qrc -o src/central_logger/resources_rc.py
QT_QPA_PLATFORM=offscreen uv run pytest -q
```

Bao gồm [`tests/test_smoke_integration.py`](../tests/test_smoke_integration.py):

- `start()` / `stop()` — modbus thread không treo
- CRUD logger + ingestion / poll chart JSON
- Regression: `cache_sensors` gọi REST readings với `force=` (keyword)

## Headless app launch

```bash
CENTRAL_LOGGER_DEBUG=1 QT_QPA_PLATFORM=offscreen timeout 8 uv run python -m central_logger.main
```

Kỳ vọng: QML load, không `Traceback` / `TypeError` khi Modbus snapshot (đã sửa `force=False` trong `sensor_state.cache_sensors`).

## Manual checklist (5–15 phút)

| Mục | Ghi chú |
|-----|---------|
| Dashboard + ingestion chart | Tab đổi không crash |
| Add / edit / remove logger | Stats `AppState` đúng |
| Logger Detail | Sensors, trending, `fetchReadingsIfStale` |
| REST (có token) | config / apply / health signals |
| Modbus (có thiết bị) | Online/offline, Recent Events |
| Thoát app | Không hang |

## Ingestion benchmark

```bash
uv run python scripts/bench_ingestion_chart.py --seed 100000 --runs 5
```

Số mẫu (máy dev, SQLite):

| Rows | avg (ms) |
|------|----------|
| 0 (empty DB) | ~11 |
| 100k | ~3.4 |

Query dùng `GROUP BY` bucket — thời gian ổn định với DB lớn.

## Packaging

```bash
chmod +x scripts/validate_packaging.sh
./scripts/validate_packaging.sh
```

- Luôn: kiểm tra syntax `build_deb.sh`, có `Product.wxs`
- Chỉ build `.deb` khi tồn tại thư mục `deploy/` (sau `pyside6-deploy`)
- `.msi`: chạy `scripts/build_msi.ps1` trên Windows với WiX

## Kết quả lần chạy gần nhất

- **pytest:** 75 passed (offscreen)
- **App headless:** không lỗi Python sau fix `force=`
- **`.deb`:** skipped — `deploy/` chưa có (cần build deploy trước)
