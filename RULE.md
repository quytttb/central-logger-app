# Bộ Quy Tắc Dành Cho Agent (Global Rules)

Tài liệu này định nghĩa các quy tắc bắt buộc mà Agent phải tuân thủ khi làm việc trên dự án này.

## 1. Công nghệ & Stack
- **Python:** Bắt buộc sử dụng chuẩn Python 3.10+ và hệ thống quản lý package `uv`.
- **UI Framework:** Bắt buộc sử dụng `PySide6` và `QML` (Qt 6). **Tuyệt đối không dùng PyQt5, PyQt6 hay PySide2**.
- **Kiến trúc UI:** Luôn sử dụng `Qaterial` cho các thành phần UI thay vì tự custom từ đầu bằng QtQuick Controls nguyên bản nếu có thể.

## 2. Quy chuẩn Viết Code
- **PEP 8:** Tuân thủ PEP 8 cho mã nguồn Python. Sử dụng `ruff` (đã được cấu hình trong dự án) để format và lint code.
- **QML Formatting:** Thụt lề 4 spaces. Các thuộc tính `id` phải ở trên cùng của component. Các `signal` và `property` custom phải ở ngay dưới `id`.
- **Type Hinting:** Code Python MỚI bắt buộc phải có type hints đầy đủ (ví dụ: `def do_something(val: int) -> bool:`).

## 3. Quản lý Thay đổi
- **Không phá vỡ code cũ:** Trừ khi user yêu cầu refactor rõ ràng, tuyệt đối không sửa đổi logic đang hoạt động tốt hoặc xóa các đoạn code/comment không liên quan đến tác vụ hiện tại.
- **Cấu trúc File:** Giữ nguyên cấu trúc thư mục hiện hành. Code UI phải ở `qml/`, code logic Python ở `src/central_logger/`.
- **Dependencies:** Không tự ý thêm thư viện mới vào `pyproject.toml` nếu chưa hỏi ý kiến user.

## 4. Ngôn ngữ & Logging
- **Console Log/Exception:** Toàn bộ log console và error messages trong code Python phải được viết bằng **Tiếng Anh** (English) để đồng bộ.
- **UI Text:** Văn bản hiển thị trên giao diện người dùng (QML) tuân theo ngôn ngữ hiện tại của ứng dụng.
- **Giao tiếp với User:** Agent giao tiếp với user bằng **Tiếng Việt**.

## 5. Tự động hóa & Kiểm thử
- **Test:** Nếu thêm feature mới quan trọng ở backend, cân nhắc tạo thêm file test trong `tests/` sử dụng `pytest`.
- **Không tự động chạy code nguy hiểm:** Không tự động chạy các script `sudo` hoặc lệnh thay đổi cấu hình hệ thống máy chủ mà không có sự đồng ý của user.
