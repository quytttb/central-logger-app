# Central Logger App - Global Agent Context

Đây là context chung (global) cho Agent khi tương tác với dự án này. Đọc file này để nắm được bức tranh tổng thể trước khi thực hiện các thay đổi.

## Tổng Quan (Overview)
`central-logger-app` là một phần mềm trung tâm thu thập dữ liệu (data logger). Ứng dụng kết nối với các thiết bị công nghiệp (như qua giao thức Modbus TCP/RTU), lưu trữ dữ liệu vào database cục bộ và hiển thị trạng thái lên giao diện người dùng.

## Kiến Trúc Hệ Thống (Architecture)
Hệ thống được thiết kế theo mô hình **MVVM (Model - View - ViewModel)**.
- **Model (Data Layer):** Nằm ở `src/central_logger/db/` và `src/central_logger/services/`. Xử lý lưu trữ SQLite, kết nối thiết bị (Modbus), lấy mẫu dữ liệu.
- **ViewModel (Controller Layer):** Nằm ở `src/central_logger/controllers/` và `src/central_logger/viewmodels/`. Lớp trung gian, quản lý state và tương tác giữa UI và Backend. Các class ở đây thường kế thừa `QObject` và sử dụng `Property`, `Signal`, `Slot` để giao tiếp với QML.
- **View (UI Layer):** Nằm ở thư mục `qml/`. Giao diện được xây dựng bằng QML và các component của thư viện Qaterial.

## Cấu trúc thư mục chính
- `/src/central_logger/`: Nơi chứa toàn bộ mã nguồn Python backend.
- `/qml/`: Nơi chứa toàn bộ mã nguồn QML cho giao diện.
- `/resources/`: Chứa các tài nguyên tĩnh như hình ảnh, file `qtquickcontrols2.conf`, `resources.qrc`.
- `/tests/`: Các bài test tự động chạy bằng `pytest`.
- `/scripts/`: Các bash script dùng để build, fetch resource, v.v.

## Quy trình khởi động
Entry point của ứng dụng là `main.py` ở thư mục gốc (hoặc `src/central_logger/main.py`).
1. Khởi tạo `QGuiApplication` (hoặc `QApplication`).
2. Khởi tạo cơ sở dữ liệu (`db_migration`).
3. Khởi tạo các Service và Controller/ViewModel.
4. Nạp file QML chính (`qml/main.qml`) thông qua `QQmlApplicationEngine`.
5. Đưa các Controller vào QML context (`rootContext().setContextProperty`).

## Hướng dẫn định hướng cho Agent
- Nếu task yêu cầu **sửa giao diện**, hãy xem file `qml/AGENT.md` và tìm code trong `qml/`.
- Nếu task yêu cầu **xử lý logic, database hoặc giao tiếp thiết bị**, hãy xem file `src/central_logger/AGENT.md`.
- Để biết cách **hiện thực hóa (implement)** một số quy trình mẫu, hãy kiểm tra thư mục `.agent/`.
- Luôn luôn tuân thủ các quy định tại file `RULE.md` ở thư mục gốc.
