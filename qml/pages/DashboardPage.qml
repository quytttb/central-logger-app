import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import CentralLogger.Core 1.0
import "../components"

Item {
    id: page

    property LoggerListModel loggersModel: LoggerListModel {}
    property string searchQuery: ""
    property alias dashController: controller

    signal openDetailRequested(int loggerId, string name, string host, int port,
                               int unitId, int sensorCount,
                               bool online, bool polling, bool rtuConnected, bool anyAlarm)

    property int modelCount: 0

    DashboardController {
        id: controller
        model: page.loggersModel
        Component.onCompleted: {
            controller.start()
            page.modelCount = page.loggersModel.count()
        }
        onSnapshotApplied: function (loggerId, ok, msg) {
            AppState.setStatus(ok
                ? ("Logger " + loggerId + " @ " + msg)
                : ("Error logger " + loggerId + ": " + msg))
        }
    }

    Connections {
        target: controller
        function onAppStatsChanged() {
            AppState.totalLoggers = loggersModel.count()
            AppState.onlineLoggers = loggersModel.onlineCount()
            AppState.alarmCount = loggersModel.alarmCount()
            page.modelCount = loggersModel.count()
        }
        function onLoggerRemoved(id) {
            page.modelCount = loggersModel.count()
            if (typeof window !== "undefined" && window.notify)
                window.notify("Logger #" + id + " removed.", "success")
        }
    }

    Connections {
        target: page.loggersModel
        ignoreUnknownSignals: true
        function onCountChanged() { page.modelCount = page.loggersModel.count() }
    }

    Qaterial.Dialog {
        id: removeConfirmDlg
        property int targetId: -1
        property string targetName: ""

        title: "Remove Logger"
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        anchors.centerIn: parent
        width: 440

        function openFor(id, name) {
            targetId = id
            targetName = name
            open()
        }

        onAccepted: {
            if (targetId >= 0)
                controller.removeLogger(targetId)
            targetId = -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            Qaterial.LabelBody1 {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Remove logger \"" + removeConfirmDlg.targetName + "\" from Central?"
                color: Qaterial.Style.colorTheme.primaryText
            }
            Qaterial.LabelBody2 {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Qaterial.Style.colorTheme.secondaryText
                text: "All sensor history stored in Central for this logger will be deleted."
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.topMargin: 24
        anchors.bottomMargin: 24
        spacing: 24

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            RoundedSearchBar {
                id: searchField
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                Layout.minimumWidth: 260
                placeholderText: "Search by name or host…"
                onQueryChanged: function (q) {
                    page.searchQuery = q
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Qaterial.Button {
                text: "+  Add Logger"
                font.family: "JetBrains Mono"
                palette.highlight: "#2E7D32"
                onClicked: addDialog.open()
            }
        }

        Qaterial.ScrollView {
            id: cardScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridLayout {
                id: grid
                width: cardScroll.availableWidth
                columns: Math.max(1, Math.floor(width / 300))
                columnSpacing: 16
                rowSpacing: 16

                Repeater {
                    model: page.loggersModel
                    delegate: LoggerCard {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 400
                        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                        visible: page.searchQuery === ""
                            || (model.name || "").toLowerCase().indexOf(page.searchQuery) >= 0
                            || (model.host || "").toLowerCase().indexOf(page.searchQuery) >= 0

                        loggerId: model.loggerId
                        loggerName: model.name
                        host: model.host
                        port: model.port
                        online: model.online
                        polling: model.polling
                        rtuConnected: model.rtuConnected
                        anyAlarm: model.anyAlarm
                        sensorCount: model.sensorCount
                        lastUpdate: model.lastUpdate
                        lastError: model.lastError

                        onClicked: page.openDetailRequested(
                            model.loggerId, model.name, model.host, model.port,
                            model.unitId, model.sensorCount,
                            model.online, model.polling, model.rtuConnected, model.anyAlarm)
                        onDeleteRequested: removeConfirmDlg.openFor(model.loggerId, model.name)
                    }
                }
            }
        }

        Qaterial.LabelBody1 {
            visible: page.modelCount === 0
            Layout.alignment: Qt.AlignHCenter
            text: "No loggers configured. Click '+  Add Logger' to get started."
            color: Qaterial.Style.colorTheme.secondaryText
        }
    }

    AddLoggerDialog {
        id: addDialog
        onLoggerSubmitted: function (name, host, port, unitId, pollMs, apiPort, apiToken) {
            if (name === "" || host === "")
                return
            controller.addLogger(name, host, port, unitId, pollMs, apiPort, apiToken)
            addDialog.resetFields()
            if (typeof window !== "undefined" && window.notify)
                window.notify("Logger added: " + name, "success")
        }
    }
}
