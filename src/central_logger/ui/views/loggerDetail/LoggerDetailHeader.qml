import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../"
import "../../components/common"
import components

Rectangle {
    id: root

    property bool isDark: true
    property var detail: ({})
    property var dashboardController: null
    property int loggerId: -1

    readonly property bool canDownloadReport: detail.online
        && dashboardController !== null
        && loggerId >= 0
    readonly property string trimmedNote: (detail.note || "").trim()
    readonly property int titleNameMaxWidth: Math.max(160, root.width - 300)

    signal goBack()
    signal editClicked()
    signal deleteClicked()

    implicitHeight: 72
    color: isDark ? Qt.rgba(0.035, 0.035, 0.043, 0.9) : Qt.rgba(0.98, 0.98, 0.98, 0.9)

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.06)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 16

        Rectangle {
            width: 36
            height: 36
            radius: 6
            color: "transparent"
            HoverHighlight {
                anchors.fill: parent
                cornerRadius: 6
                hovered: backMouse.containsMouse
                isDark: root.isDark
            }
            UiIcon {
                anchors.centerIn: parent
                name: "arrowLeft"
                size: 20
                iconColor: Colors.textSecondary(root.isDark)
            }
            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goBack()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                UiLabel {
                    textType: UiLabel.Headline5
                    text: detail.loggerName || "—"
                    color: Colors.textPrimary(root.isDark)
                    font.family: "Inter"
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    Layout.fillWidth: root.trimmedNote.length === 0
                    Layout.maximumWidth: root.trimmedNote.length > 0 ? root.titleNameMaxWidth : -1
                    maximumLineCount: 1
                }
                UiLabel {
                    visible: root.trimmedNote.length > 0
                    text: root.trimmedNote.length > 0 ? ("(" + root.trimmedNote + ")") : ""
                    color: Colors.textSecondary(root.isDark)
                    font.family: "Inter"
                    font.pixelSize: 16
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 1
                }
            }

            UiLabel {
                textType: UiLabel.Caption
                Layout.fillWidth: true
                text: {
                    var h = detail.host || "—"
                    var modbus = detail.port !== undefined ? detail.port : 5020
                    var rest = detail.apiPort !== undefined ? detail.apiPort : 8080
                    var line = h + " · MB:" + modbus + " · REST:" + rest
                    var sc = detail.sensorCount !== undefined ? detail.sensorCount : 0
                    if (sc > 0)
                        line += " · " + sc + " sensors"
                    return line
                }
                color: Colors.textSecondary(root.isDark)
                font.family: "Inter"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Rectangle {
            width: 36
            height: 36
            radius: 6
            opacity: root.canDownloadReport ? 1.0 : 0.45
            color: "transparent"
            HoverHighlight {
                anchors.fill: parent
                cornerRadius: 6
                hovered: dlMouse.containsMouse && root.canDownloadReport
                isDark: root.isDark
            }
            UiIcon {
                anchors.centerIn: parent
                name: "download"
                size: 20
                iconColor: Colors.textSecondary(root.isDark)
            }
            MouseArea {
                id: dlMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.canDownloadReport ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!root.canDownloadReport || !root.dashboardController || root.loggerId < 0)
                        return
                    root.dashboardController.downloadLatestReportWithDialog(root.loggerId)
                }
            }
            ToolTip.visible: dlMouse.containsMouse
            ToolTip.text: root.canDownloadReport
                ? "Download Report"
                : "Logger must be online with API token configured"
        }

        Rectangle {
            width: 36
            height: 36
            radius: 6
            color: "transparent"
            HoverHighlight {
                anchors.fill: parent
                cornerRadius: 6
                hovered: editMouse.containsMouse
                isDark: root.isDark
            }
            UiIcon {
                anchors.centerIn: parent
                name: "pencil"
                size: 20
                iconColor: Colors.textSecondary(root.isDark)
            }
            MouseArea {
                id: editMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editClicked()
            }
            ToolTip.visible: editMouse.containsMouse
            ToolTip.text: "Edit Logger"
        }

        Rectangle {
            width: 36
            height: 36
            radius: 6
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: root.isDark ? "#450505" : "#fef2f2"
                opacity: delMouse.containsMouse ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: UiMotion.durationFast
                        easing.type: UiMotion.easingOut
                    }
                }
            }
            UiIcon {
                anchors.centerIn: parent
                name: "trashCan"
                size: 20
                iconColor: delMouse.containsMouse ? "#ef4444" : Colors.textSecondary(root.isDark)
            }
            MouseArea {
                id: delMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deleteClicked()
            }
            ToolTip.visible: delMouse.containsMouse
            ToolTip.text: "Delete Logger"
        }
    }
}
