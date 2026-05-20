# Central Logger App

Ứng dụng quản lý tập trung các Data Logger qua **Modbus TCP**, xây dựng bằng **PySide6 + Qt Quick (QML)** với **Qt Quick Controls 2 (Material)** và wrapper nội bộ (`UiLabel`, `UiIcon`, `Snackbar`).

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
│   └── ui/                 # QML (QQC2 Material + UiLabel/UiIcon)
│       ├── main.qml
│       ├── components/
│       └── views/
├── resources/
│   ├── resources.qrc
│   ├── qtquickcontrols2.conf
│   ├── fonts/              # Roboto, Roboto Mono, Material Symbols Outlined
│   └── images/
├── scripts/
│   ├── build_deb.sh          # .deb từ thư mục deploy
│   ├── build_msi.ps1         # .msi (Windows, cần WiX)
│   └── stage_zbar_windows.ps1
├── packaging/windows/        # WiX Product.wxs
├── docs/perf-baseline.md
├── tests/
└── .github/workflows/ci.yml
```

## Quickstart trên Ubuntu

```bash
# 1. Tạo venv + cài deps
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev,test]"

# 2. Biên dịch tài nguyên QML/icons -> module Python
pyside6-rcc resources/resources.qrc -o src/central_logger/resources_rc.py

# 3. Chạy app (một trong các cách sau)
python -m central_logger
# hoặc: python -m central_logger.main
# hoặc: central-logger
# hoặc: python main.py   # shim ở thư mục gốc repo (cần pip install -e .)

# 4. Test
QT_QPA_PLATFORM=offscreen pytest tests/test_smoke_integration.py::test_qml_main_loads_headless -q
# toàn bộ suite: QT_QPA_PLATFORM=offscreen pytest -q
```

Gỡ lỗi Modbus / UI cập nhật trạng thái: chạy với `CENTRAL_LOGGER_DEBUG=1` để xem log (`central_logger.services`, v.v.). Nếu Data Logger chỉ listen IPv4, dùng host `127.0.0.1` thay vì `localhost`.

**Pairing QR (API token):** Add/Edit Logger → **Scan QR…** (ảnh PNG/JPG từ data-logger). Schema: [`docs/provision-qr-v1.md`](docs/provision-qr-v1.md).

- **Linux dev:** `sudo apt install libzbar0`
- **Windows build:** copy `libzbar-64.dll` (+ `libiconv.dll`) vào [`resources/native/windows/`](resources/native/windows/README.md), rồi deploy — DLL được bundle cạnh `.exe` (`native/windows/`). Script: `scripts\stage_zbar_windows.ps1 -Source "C:\path\to\zbar\bin"`.

> Nếu dùng `uv` (nhanh hơn): `uv sync --extra dev --extra test` rồi `uv run python -m central_logger`.

## Giao diện (QML)

- **Style:** `QQuickStyle.setStyle("Material")` + [`resources/qtquickcontrols2.conf`](resources/qtquickcontrols2.conf) (primary `#000666`, accent `#4C56AF`).
- **Theme:** `window.isDark` + [`Colors.qml`](src/central_logger/ui/Colors.qml) (zinc/shadcn palette); `Material.theme` đồng bộ tại root `main.qml`.
- **Components:** `UiLabel`, `UiIcon`, `Snackbar` trong [`src/central_logger/ui/components/common/`](src/central_logger/ui/components/common/) — `import components`.
- **Icons:** font **Material Symbols Outlined** (`resources/fonts/MaterialSymbols/`), map trong `MaterialIcons.qml`.
- **Typography / fonts:** Roboto + Roboto Mono load trong `main.py`; không cần build native QML plugin.
- **Thanh tiêu đề:** cửa sổ **frameless** + nút Minimize / Close trong `AppTopBar.qml`.

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

Tham khảo `pysidedeploy.spec` (`--include-data-dir=resources/native/windows=native/windows`, `--nofollow-import-to=pytest,tests`) và loại bỏ QML plugins thừa (`excluded_qml_plugins = WebEngine, Quick3D, ...`).

**Build nhỏ hơn (không QR):** bỏ qua `stage_zbar_windows.ps1` và không copy `resources/native/windows/`; QR scan trong Add Logger sẽ báo lỗi thiếu thư viện — phù hợp môi trường không cần provisioning qua ảnh.

## Phát hành (Release packages)

| Nền tảng | File phát hành | Cài đặt |
|----------|----------------|---------|
| Ubuntu | `dist/central-logger-app_<ver>_amd64.deb` | `sudo apt install ./...deb` |
| Windows | `dist/CentralLogger-<ver>-win64.msi` | double-click hoặc `msiexec /i` |
| Windows (dev) | thư mục deploy + `CentralLogger.exe` | portable, không installer |

### MSI và `.exe` — khác nhau thế nào?

- **`.exe` (portable):** Nuitka / `pyside6-deploy` tạo `CentralLogger.exe` cùng thư mục DLL/Qt — chạy trực tiếp hoặc copy folder.
- **`.msi`:** Gói **cài đặt** Windows Installer — copy vào `Program Files`, shortcut, gỡ qua Settings. MSI **không thay** `.exe`; nó **bọc** cùng thư mục deploy.
- **MSIX** (tương lai): định dạng Store-style, ký số bắt buộc — chưa dùng trong repo này.

### Đóng gói Ubuntu (`.deb`)

Prerequisite: thư mục deploy sau `pyside6-deploy`, và trên máy cài `libzbar0` (runtime, không bundle như Windows).

```bash
# Cách 1 (khuyến nghị): menu tương tác — chọn .deb rồi PATCH / MINOR / MAJOR
./scripts/build.sh
# Hoặc không tương tác: ./scripts/build.sh deb patch
# Tách bước:
# uv run python scripts/bump_version.py bump patch
# ./scripts/build_deploy_venv.sh && ./scripts/build_deb.sh deploy

# Cách 2: Nuitka / pyside6-deploy (nhỏ hơn; cần Python 3.13 + patchelf hệ thống)
pyside6-rcc resources/resources.qrc -o src/central_logger/resources_rc.py
uv run python scripts/bump_version.py bump patch
pyside6-deploy src/central_logger/main.py
./scripts/build_deb.sh deploy

sudo apt install ./dist/central-logger-app_*_amd64.deb
```

App cài tại `/opt/central-logger/`, lệnh `central-logger`, shortcut trong menu ứng dụng.

### Đóng gói Windows (`.msi`)

1. Build portable như mục **Triển khai Windows** (`pyside6-deploy` → thư mục có `CentralLogger.exe`).
2. Cài [WiX Toolset](https://wixtoolset.org/) (`heat.exe`, `candle.exe`, `light.exe` trên PATH).
3. Chạy:

```powershell
.\scripts\build.ps1
# Hoặc: .\scripts\build.ps1 msi patch -DeployDir deploy
```

Output: `dist\CentralLogger-<version>-win64.msi` (version từ `pyproject.toml` sau bump).

Hoặc đã bump tay: `.\scripts\build_msi.ps1 -DeployDir deploy` (tùy chọn `-Version` override).

### Kiểm tra sau cài (smoke test)

- App mở, đổi theme light/dark
- Thêm/sửa logger, mở Logger Detail
- Modbus poll (online/offline)
- Windows full build: quét QR trong Add Logger

### Tăng version (SemVer)

Một nguồn: `version` trong [`pyproject.toml`](pyproject.toml). Build release **bắt buộc** chọn mức bump:

| Tham số | Ý nghĩa | Ví dụ `0.1.0` → |
|---------|---------|------------------|
| `patch` | Bản vá | `0.1.1` |
| `minor` | Tính năng tương thích ngược | `0.2.0` |
| `major` | Breaking change | `1.0.0` |

```bash
./scripts/build.sh              # menu: .deb → chọn PATCH / MINOR / MAJOR
uv run python scripts/bump_version.py show
```

```powershell
.\scripts\build.ps1             # menu: MSI → chọn PATCH / MINOR / MAJOR
```

Vẫn hỗ trợ dòng lệnh: `./scripts/build.sh deb patch`, `.\scripts\build.ps1 msi minor -DeployDir deploy`

Chỉ tạo `deploy/` (không đóng gói): chọn mục 2 trong menu, hoặc `./scripts/build.sh deploy-venv`

Chi tiết đo hiệu năng / LOC: [`docs/perf-baseline.md`](docs/perf-baseline.md).

## License

Proprietary.
