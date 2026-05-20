# Kỹ năng: Thao tác với Database và Modbus

Tài liệu này hướng dẫn Agent cách thực hiện các tác vụ liên quan đến tầng Data (SQLite và Modbus TCP/RTU).

## 1. Tương tác với Database (SQLite)

### Khái niệm cơ bản
Dự án có module `db/` để xử lý kết nối và các câu lệnh query.
- Không bao giờ gọi query thẳng trên main thread vì nó làm đứng giao diện.
- Nên đóng gói các thao tác CRUD vào các class Service chuyên biệt (Ví dụ: `LoggerService`).

### Quy trình thêm/sửa bảng (Table)
1. **Migration:** Nếu cần thêm bảng mới hoặc sửa schema, không tự ý dùng `CREATE TABLE IF NOT EXISTS` ở đâu đó lung tung. Phải kiểm tra cơ chế `db_migration` của dự án xem có quản lý version không. Nếu có, thêm script migration mới.
2. **Models:** Tạo hoặc update class Data Model (dataclass hoặc model class) để map với table tương ứng. Ví dụ: `class SensorData: ...`
3. **Repository/DAO:** Thêm hàm query tương ứng (INSERT, SELECT) vào file thao tác DB.
4. Xử lý logic lỗi (try-catch) khi truy vấn và log lỗi cẩn thận bằng Tiếng Anh.

## 2. Giao tiếp Modbus

### Khái niệm cơ bản
Dự án sử dụng thư viện `pymodbus` hoặc một biến thể để đọc dữ liệu từ thiết bị IoT/PLC qua cổng nối tiếp (RTU) hoặc mạng (TCP).

### Quy trình thêm thanh ghi (Register) Modbus mới
1. **Xác định loại thanh ghi:** Coil (RW), Discrete Input (RO), Holding Register (RW), Input Register (RO).
2. **Cập nhật Map:** Có thể dự án có file map Modbus (như `test_modbus_map.py` gợi ý). Cần khai báo địa chỉ (address), độ dài (count), kiểu dữ liệu (Float32, Int16...).
3. **Little/Big Endian:** Thiết bị Modbus thường có vấn đề về byte order. Phải dùng các struct unpack hoặc tiện ích của module có sẵn trong `utils/` hoặc `services/` để decode chính xác.
4. **Không chạy trên main thread:** Việc đọc/ghi Modbus (polling) luôn luôn phải chạy trong một `QThread` vòng lặp `while` riêng biệt, hoặc `QTimer` gắn trên worker thread. Cấm tuyệt đối `time.sleep()` trên main GUI thread.

## 3. Quản lý Thread an toàn
Mô hình chuẩn cho background worker:
- Tạo 1 class `Worker` kế thừa `QObject`. Cấu hình vòng lặp hoặc timer trong class này.
- Tạo 1 `QThread`.
- Chuyển worker sang thread phụ: `worker.moveToThread(thread)`.
- Chạy thread: `thread.start()`.
- Giao tiếp với Worker: Thông qua Signals (để worker gửi dữ liệu lên UI) và Slots (để UI cấu hình worker). Thêm `@Slot` để đảm bảo lệnh từ thread này gọi an toàn sang thread kia qua hệ thống event queue của Qt.
