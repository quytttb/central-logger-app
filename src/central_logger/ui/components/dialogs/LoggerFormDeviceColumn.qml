import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."
import "../common"

ColumnLayout {
    id: root

    required property var dialog

    property alias stationCodeField: stationCodeField
    property alias stationNameField: stationNameField
    property alias bindField: bindField
    property alias unitIdDeviceField: unitIdDeviceField
    property alias pollDeviceField: pollDeviceField
    property alias modbusTcpEnabledCheck: modbusTcpEnabledCheck

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 20
    opacity: root.dialog.deviceEditable ? 1.0 : 0.45

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    FormSectionLabel { text: "DEVICE — REST (Firmware)" }

    Rectangle {
        visible: !root.dialog.deviceEditable
        Layout.fillWidth: true
        implicitHeight: hintCol.implicitHeight + 24
        radius: 8
        color: Colors.surfaceMuted(root.dialog.isDark)
        border.width: 1
        border.color: Colors.border(root.dialog.isDark)
        ColumnLayout {
            id: hintCol
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 6
            Qaterial.Icon {
                Layout.alignment: Qt.AlignHCenter
                icon: Qaterial.Icons.informationOutline
                size: 24
                color: Colors.textMuted(root.dialog.isDark)
            }
            Qaterial.LabelCaption {
                Layout.fillWidth: true
                text: root.dialog.mode === "add"
                    ? "Click Connect & Load Config on the left to load station, poll interval, and Modbus TCP settings from the edge device."
                    : "Click Connect & Load Config on the left to refresh device settings from the edge."
                color: Colors.textMuted(root.dialog.isDark)
                font.family: "Inter"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    ColumnLayout {
        visible: root.dialog.deviceEditable
        Layout.fillWidth: true
        spacing: 12

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12
            LoggerFormField {
                id: stationCodeField
                label: "Station code"
                isDark: root.dialog.isDark
                inputEnabled: root.dialog.deviceEditable
            }
            LoggerFormField {
                id: stationNameField
                label: "Station name"
                isDark: root.dialog.isDark
                inputEnabled: root.dialog.deviceEditable
            }
            LoggerFormField {
                id: bindField
                label: "Modbus TCP bind"
                isDark: root.dialog.isDark
                inputEnabled: root.dialog.deviceEditable
            }
            LoggerFormField {
                id: unitIdDeviceField
                label: "Modbus TCP unit ID (edge)"
                isDark: root.dialog.isDark
                inputEnabled: root.dialog.deviceEditable
            }
        }
        LoggerFormField {
            id: pollDeviceField
            label: "Device poll interval (s)"
            isDark: root.dialog.isDark
            Layout.fillWidth: true
            inputEnabled: root.dialog.deviceEditable
        }
        RowLayout {
            enabled: root.dialog.deviceEditable
            Layout.fillWidth: true
            spacing: 10
            CheckBox { id: modbusTcpEnabledCheck }
            Qaterial.LabelBody2 {
                text: "Modbus TCP server enabled"
                color: Colors.textPrimary(root.dialog.isDark)
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.dialog.deviceEditable)
                            modbusTcpEnabledCheck.toggle()
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
