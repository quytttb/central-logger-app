# Kỹ năng: Tích hợp Backend (Python) với Frontend (QML) bằng mô hình MVVM

Tài liệu này hướng dẫn Agent cách xây dựng cầu nối (Controller/ViewModel) để đưa dữ liệu từ Python lên QML và nhận thao tác từ QML về Python.

## Khái niệm cốt lõi
- Mọi class Python muốn tương tác trực tiếp với QML phải kế thừa `QObject`.
- **Đưa dữ liệu sang QML:** Dùng `@Property`.
- **Bắn sự kiện/trigger từ Python sang QML:** Dùng `Signal`.
- **Nhận lệnh từ QML về Python:** Dùng `@Slot()`.

## Các bước thực hiện (Workflow)

### 1. Tạo Class ViewModel/Controller
- Đặt file mới vào `src/central_logger/controllers/` hoặc `viewmodels/`.
- Định nghĩa class kế thừa `QObject`.
- Khởi tạo `__init__(self, parent=None)` và gọi `super().__init__(parent)`.

### 2. Định nghĩa Properties
QML không thể đọc trực tiếp biến của Python. Phải bọc qua Property.
1. Khai báo Signal thông báo khi giá trị đổi (đặt tên có hậu tố `Changed`).
2. Khai báo biến `_private` lưu giá trị.
3. Viết hàm getter.
4. Viết hàm setter (chỉ emit signal nếu giá trị THỰC SỰ thay đổi để tránh lặp vô tận).
5. Sử dụng decorator `@Property(type, fget, fset, notify)`.

**Ví dụ chuẩn:**
```python
from PySide6.QtCore import QObject, Property, Signal, Slot

class SensorController(QObject):
    # 1. Define signal
    statusChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._status = "Idle" # Private variable

    # Getter
    def get_status(self) -> str:
        return self._status

    # Setter
    def set_status(self, val: str):
        if self._status != val:
            self._status = val
            self.statusChanged.emit() # Phát tín hiệu

    # 2. Expose as Property
    status = Property(str, get_status, set_status, notify=statusChanged)

    # 3. Expose action (Slot)
    @Slot(str)
    def start_reading(self, sensor_id: str):
        # Logic Python ở đây
        print(f"Bắt đầu đọc sensor: {sensor_id}")
        self.set_status("Reading")
```

### 3. Đăng ký Controller vào QML Engine
- Mở `main.py` (file khởi động ứng dụng).
- Import Controller vừa tạo.
- Khởi tạo instance của Controller đó.
- Lấy `rootContext` từ `QQmlApplicationEngine` và inject instance vào.
- Ví dụ:
  ```python
  sensor_ctrl = SensorController()
  engine.rootContext().setContextProperty("sensorController", sensor_ctrl)
  ```

### 4. Sử dụng từ QML
Bây giờ, tại bất kỳ file `.qml` nào, có thể gọi `sensorController` như một object toàn cục.
```qml
Text {
    // Binding: Tự động update khi statusChanged được emit từ Python
    text: "Current Status: " + sensorController.status 
}

Button {
    text: "Start"
    // Gọi hàm Python
    onClicked: sensorController.start_reading("SENSOR_01")
}
```
