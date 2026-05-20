# QML Frontend Context

Bạn đang ở khu vực View (UI Layer) của dự án. Giao diện được xây dựng bằng **QML** của framework Qt 6 (PySide6).

## Đặc điểm của khu vực này
1. **UI components:** Dùng `UiLabel`, `UiIcon`, `Snackbar` (`import components`) và `Colors.qml` cho theme. Style Material qua `qtquickcontrols2.conf`.
2. **Cấu trúc thư mục QML (tương đối với `src/central_logger/ui/`):**
   - `main.qml`: Root `ApplicationWindow`; khai báo `LoggerListModel`, `RecentEventsModel`, `DashboardController`, `SettingsController` và alias xuống các view; routing giữa các view qua `currentView`.
   - `views/`: Các màn hình lớn — `dashboard/DashboardView.qml`, `loggers/LoggersView.qml`, `loggerDetail/LoggerDetailView.qml`, `settings/SettingsView.qml`, kèm các sub-view (chart, table, sidebar) đặt cùng thư mục.
   - `components/`: Custom UI tái sử dụng:
     - `common/`: Badge, SensorStatusBadge, LabeledField, DialogButton, PageHeader, TableHeaderCell, ListRowDelegate, HoverHighlight, FormSectionLabel
     - `cards/`: StatCard (extends PanelCard), PanelCard
     - `navigation/`: AppSidebar, AppTopBar
     - `dialogs/`: BaseDialog, LoggerFormDialog, AddLoggerDialog, ConfirmDialog, EditConfigDialog
     - `charts/`: BaseChart, ChartPanel, ChartTooltipOverlay
     - `utils/`: FrameResizeHandles
   - `logic/`: `LoggerFormLogic.js`, `LoggerDetailLogic.js` — orchestration tách khỏi layout QML
   - `Colors.qml`, `UiMotion.qml` (singleton): design tokens và animation; `qmldir` cùng cấp khai báo singleton.

## Cách tiếp cận khi code QML
- **Data Binding:** Tận dụng tối đa data binding của QML để UI tự cập nhật khi property thay đổi.
- **Kết nối Backend:** Đăng ký Python types qua `@QmlElement` với `QML_IMPORT_NAME = "CentralLogger.Core"`. QML dùng `import CentralLogger.Core 1.0` rồi khởi tạo trực tiếp (ví dụ `DashboardController { id: dashboardController }`) thay vì context property. `AppState` là `@QmlSingleton`.
- **Design tokens:** Ưu tiên `Colors.*` và `PanelCard` thay vì hex literals / card chrome copy-paste.
- **qmldir:** Mỗi thư mục `components/`, `components/<sub>/` và `views/<sub>/` đều có `qmldir` riêng. Component/View mới phải được khai báo trong `qmldir` tương ứng để import được.
- **Tài nguyên:** Đường dẫn ảnh/icon lấy từ QRC hoặc đường dẫn tương đối (ví dụ `"qrc:/images/..."` hoặc qua context property `logoUrl`).

## Kỹ năng liên quan
Xem `.agent/SKILL_QML_UI.md` và `.agent/SKILL_MVVM_INTEGRATION.md` ở root để biết cách tạo component và cầu nối Python ↔ QML.
