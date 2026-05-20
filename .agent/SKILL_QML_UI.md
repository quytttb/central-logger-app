# Kỹ năng: Tạo và tích hợp component QML

Tài liệu này hướng dẫn Agent cách suy nghĩ và thực hiện việc thêm một Component QML mới vào dự án.

## Bối cảnh (Context)
UI của ứng dụng dùng QML. Thay vì nhồi nhét mọi thứ vào một trang (page) lớn, ta phải tách thành các component nhỏ, có thể tái sử dụng (như nút bấm, thẻ hiển thị, popup).

## Các bước thực hiện (Workflow)

### 1. Phân tích & Đặt tên
- Quyết định xem component này thuộc loại chung (đặt vào `qml/components/`) hay cụ thể của một trang (đặt vào thư mục riêng hoặc `qml/pages/`).
- Tên file bắt buộc viết hoa chữ cái đầu (PascalCase), ví dụ: `CustomButton.qml`.

### 2. Viết mã QML
- Tạo file `.qml` tại thư mục đã chọn.
- Bắt đầu với: `import QtQuick`, `import QtQuick.Controls`, `import components` (cho `UiLabel`, `UiIcon`).
- Đặt `id` đầu tiên, sau đó là định nghĩa các `property`, `signal`.
- Ưu tiên layout động (anchors, Layouts) hơn là kích thước tĩnh (x, y, width cố định).

**Ví dụ cấu trúc chuẩn:**
```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    // 1. Properties
    property string titleText: "Default Title"
    property color activeColor: "blue"

    // 2. Signals
    signal clicked()

    // 3. UI logic / Styling
    width: 200
    height: 50
    color: "white"

    // 4. Child elements
    Text {
        anchors.centerIn: parent
        text: root.titleText
        color: root.activeColor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
```

### 3. Đăng ký vào qmldir (Rất quan trọng)
Nếu component đặt trong `qml/components/`:
- Mở file `qml/components/qmldir`.
- Thêm dòng khai báo để component có thể import được ở nơi khác.
- Cú pháp: `[TênComponent] 1.0 [TênFile.qml]`
- Ví dụ: `CustomButton 1.0 CustomButton.qml`

### 4. Tích hợp và Kiểm tra
- Tại file QML cần dùng component mới, đảm bảo đã import module chứa component (ví dụ: `import "components"` hoặc module tương ứng).
- Khởi tạo component và truyền đủ property cần thiết.
- Không tự ý chạy test UI bằng cách mở app trừ khi được yêu cầu, nhưng cần review mã tĩnh cẩn thận.
