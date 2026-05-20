# Backend Python Context

Bạn đang ở thư mục chứa logic cốt lõi (Backend) của dự án `central-logger-app`, viết bằng Python.

## Cấu trúc và Trách nhiệm
1. **`db/` (Database Layer):**
   - Chứa code tương tác với SQLite thông qua thư viện thuần hoặc ORM (nếu có).
   - Mọi thay đổi về cấu trúc bảng (schema) phải được thực hiện qua file `db_migration` hoặc file khởi tạo tương tự.
   - Các class model hoặc phương thức CRUD nằm ở đây.

2. **`services/` (Business Logic Layer):**
   - Chứa các class độc lập xử lý logic nền (background worker, modbus client, data aggregation).
   - Thường sử dụng `QThread` hoặc thread pool để chạy ngầm mà không làm đơ giao diện (GUI thread).
   - Tương tác với thiết bị vật lý nằm ở tầng này.

3. **`controllers/` & `viewmodels/` (Presentation Layer):**
   - Cầu nối giữa giao diện (QML) và tầng Service/Database.
   - Bắt buộc kế thừa `QObject` cho type đăng ký QML (`@QmlElement`).
   - `DashboardController` là facade QML duy nhất; logic nặng nằm ở plain Python helpers cùng thư mục (`event_journal`, `sensor_state`, `rest_coordinator`, `modbus_bridge`, `logger_ops`, `chart_queries`) — không thêm `@QmlElement` mới trừ khi có contract UI mới.
   - Phải định nghĩa các `Property` (kèm setter/getter và `NOTIFY` signal) để QML có thể bind vào.
   - Các `Slot` dùng để nhận lệnh (click button, input text) từ QML.

4. **`utils/` (Tiện ích):**
   - Các hàm trợ giúp dùng chung (chuyển đổi định dạng, xử lý chuỗi, đọc ghi file config).

## Nguyên tắc thiết kế (Design Principles)
- **Asynchronous/Non-blocking:** GUI của PySide6 chạy trên main thread. Bất kỳ thao tác nào tốn thời gian (query database lớn, ping mạng, đọc Modbus) PHẢI được đẩy xuống background thread/worker.
- **Tín hiệu an toàn (Thread-safe signals):** Để gửi dữ liệu từ thread phụ (Service) lên main thread (ViewModel/QML), luôn luôn sử dụng Signal/Slot của Qt thay vì gọi hàm trực tiếp. Điều này đảm bảo an toàn luồng (thread-safety).
- **Loose Coupling:** Controllers không nên truy cập trực tiếp cấu trúc nội bộ của Services. Giao tiếp qua interface rõ ràng hoặc Event/Signals.

## Kỹ năng liên quan
- Xem `.agent/SKILL_MVVM_INTEGRATION.md` để hiểu cách kết nối Controller/ViewModel với QML.
- Xem `.agent/SKILL_DATABASE_MODBUS.md` để biết cách làm việc với Data Layer.
