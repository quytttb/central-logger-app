import QtQuick

LoggerFormDialog {
    id: editWrapper
    mode: "edit"
    property alias config: editWrapper.detail
    property alias dashboardController: editWrapper.dashboardController
}
