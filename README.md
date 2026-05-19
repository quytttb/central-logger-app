# Central Logger App

Ứng dụng quản lý tập trung các Data Logger qua **Modbus TCP**, xây dựng bằng **PySide6 + Qt Quick (QML)** với **[Qaterial](https://github.com/OlivierLDff/Qaterial)** (Material-style components).

- **Dev:** Ubuntu (Linux)
- **Triển khai:** Windows (build bằng `pyside6-deploy` / Nuitka)

## Stack chính

| Thư viện | Phiên bản | Ghi chú |
|---|---|---|
| PySide6 | >= 6.11.0 | Qt 6.11, Python >= 3.10 |
| pymodbus | >= 3.13 | `AsyncModbusTcpClient` (asyncio) |
| SQLModel | >= 0.0.22 | Trên SQLAlchemy 2.x + Pydantic |
| pytest / pytest-qt | 8.x / 4.5+ | Headless test (`QT_QPA_PLATFORM=offscreen`) |

## Cấu trúc thư mục

```
central-logger-app/
├── pyproject.toml
├── src/central_logger/              # Python package
│   ├── main.py
│   ├── db/                 # SQLModel models + session
│   ├── services/           # ModbusManager (asyncio), QmlAsyncBridge
│   ├── viewmodels/         # @QmlElement / @QmlSingleton
│   ├── controllers/
│   ├── utils/
│   └── ui/                 # QML (Qaterial + Qt Quick Controls)
│       ├── main.qml
│       ├── components/
│       └── views/
├── resources/
│   ├── resources.qrc
│   ├── qtquickcontrols2.conf
│   ├── fonts/              # Lato, Roboto, Roboto Mono (bundled app fonts)
│   └── images/
├── tests/
└── .github/workflows/ci.yml
```

## Quickstart trên Ubuntu

```bash
# 1. Tạo venv + cài deps
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

# 2. Biên dịch tài nguyên QML/icons -> module Python
pyside6-rcc resources/resources.qrc -o src/central_logger/resources_rc.py

# 3. Chạy app (một trong hai)
python main.py
# hoặc: python -m central_logger.main

# 4. Test
QT_QPA_PLATFORM=offscreen pytest -q
```

Gỡ lỗi Modbus / UI cập nhật trạng thái: chạy với `CENTRAL_LOGGER_DEBUG=1` để xem log (`central_logger.services`, v.v.). Nếu Data Logger chỉ listen IPv4, dùng host `127.0.0.1` thay vì `localhost`.

**Pairing QR (API token):** Add/Edit Logger → **Scan QR…** (ảnh PNG/JPG từ data-logger). Schema: [`docs/provision-qr-v1.md`](docs/provision-qr-v1.md).

- **Linux dev:** `sudo apt install libzbar0`
- **Windows build:** copy `libzbar-64.dll` (+ `libiconv.dll`) vào [`resources/native/windows/`](resources/native/windows/README.md), rồi deploy — DLL được bundle cạnh `.exe` (`native/windows/`). Script: `scripts\stage_zbar_windows.ps1 -Source "C:\path\to\zbar\bin"`.

> Nếu dùng `uv` (nhanh hơn): `uv sync --extra dev` rồi `uv run python -m central_logger.main`.

## Giao diện Qaterial

- **Màu / typography:** `Qaterial.Style` và `Qaterial.Style.colorTheme` trong QML; brand primary `#000666`, accent `#4C56AF` được gán trong `main.qml` (`Component.onCompleted`).
- **Thanh tiêu đề:** cửa sổ **frameless** + nút Minimize / Maximize / Close trong `AppTopBar.qml`.
- **[Qaterial](https://github.com/OlivierLDff/Qaterial)** (Qt 6, C++ + QML): không có wheel pip; cần **CMake** build vào prefix cục bộ.
  1. `chmod +x scripts/fetch_qaterial.sh scripts/build_qaterial.sh`
  2. `./scripts/fetch_qaterial.sh` — clone vào `vendor/Qaterial/` (đã `.gitignore`, không bắt buộc commit).
  3. Cài toolchain Qt6 dev trên Ubuntu (đã dùng `pkexec`): `qt6-base-dev`, `qt6-declarative-dev`, `qt6-svg-dev`, `qt6-5compat-dev`, `qt6-shadertools-dev`, `cmake`, `ninja-build`, `g++`.
  4. `CMAKE_PREFIX_PATH=/usr ./scripts/build_qaterial.sh` — build với **Qt hệ thống** (PySide6 wheel **không** kèm `Qt6Config.cmake`). Script thêm `-DCMAKE_POSITION_INDEPENDENT_CODE=ON` để link `libQaterial.so` với QOlm tĩnh (`-fPIC`).
  5. Chạy app: `main.py` tự nạp `libQaterial.so` qua `ctypes`, thêm `LD_LIBRARY_PATH` → `vendor/qaterial-install/lib` **trước khi** import Qt, và `addImportPath` → `vendor/qaterial-build/qml` (nơi có `Qaterial/qmldir`). Hoặc đặt `QATERIAL_QML_PATH` trỏ tới thư mục cha của `Qaterial/`.
  6. Trong QML: `import Qaterial ...` theo [Quickstart](https://olivierldff.github.io/Qaterial/Quickstart.html).

**Lưu ý phiên bản Qt:** PySide6 trong `.venv` có thể là Qt **6.11**; thư viện hệ thống vừa cài là Qt **6.10**. `libQaterial.so` link với 6.10 — nếu gặp lỗi load plugin khi chạy app, cần **trùng major/minor** (cài Qt6 dev cùng bản với PySide, hoặc build Qaterial trong môi trường Qt trùng với wheel).

Nếu chưa build Qaterial, QML `import Qaterial` sẽ thất bại — cần build theo các bước trên.

## Modbus TCP Map v1 (hợp đồng đọc)

| Register | Nội dung |
|---|---|
| HR0 | Map version (= 1) |
| HR1 | Status bits (bit0=poll, bit1=RTU, bit2=any alarm) |
| HR2–HR3 | Unix timestamp uint32, big-endian |
| HR4 | Số sensor `N` |
| HR10 + i*8 | Khối sensor i: `+0` id, `+1` flags, `+2..+3` float32 ABCD, `+4..+7` reserved |

- Default port: **5020**
- Float endian cố định **ABCD** (big-endian)
- Unit ID mặc định: **1**

## Triển khai Windows

```cmd
:: Trên Windows (Python 3.12 + venv NEW, không copy từ Linux)
python -m venv .venv
.venv\Scripts\activate
pip install -e ".[build]"

:: QR scan: stage ZBar DLLs once (x64) — see resources\native\windows\README.md
powershell -ExecutionPolicy Bypass -File scripts\stage_zbar_windows.ps1 -Source "C:\path\to\zbar\bin"

pyside6-rcc resources\resources.qrc -o src\central_logger\resources_rc.py
pyside6-deploy src\central_logger\main.py
```

Sau build, thư mục deploy có `native\windows\libzbar-64.dll` — **không** cần operator cài apt/ZBar; chỉ chạy `.exe`.

Tham khảo `pysidedeploy.spec` (`--include-data-dir=resources/native/windows=native/windows`) và loại bỏ QML plugins thừa (`excluded_qml_plugins = WebEngine, Quick3D, ...`).

## License

Proprietary.
