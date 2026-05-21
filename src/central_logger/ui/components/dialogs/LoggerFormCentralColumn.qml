import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "../common"
import components

ColumnLayout {
    id: root

    required property var dialog

    property alias nameField: nameField
    property alias noteField: noteField
    property alias hostField: hostField
    property alias portField: portField
    property alias unitField: unitField
    property alias timeoutField: timeoutField
    property alias apiPortField: apiPortField
    property alias tokenField: tokenField
    property alias apiBaseUrlField: apiBaseUrlField

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 20

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        FormSectionLabel { text: "BASIC" }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12
            LoggerFormField {
                id: nameField
                label: "Name *"
                isDark: root.dialog.isDark
            }
            LoggerFormField {
                id: noteField
                label: "Note (optional)"
                isDark: root.dialog.isDark
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        FormSectionLabel { text: "CENTRAL — MODBUS" }
        LoggerFormField {
            id: hostField
            label: "Host IP *"
            isDark: root.dialog.isDark
            Layout.fillWidth: true
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12
            LoggerFormField { id: portField; label: "Modbus Port"; isDark: root.dialog.isDark }
            LoggerFormField { id: unitField; label: "Unit ID"; isDark: root.dialog.isDark }
            LoggerFormField { id: timeoutField; label: "Modbus timeout (s)"; isDark: root.dialog.isDark }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        FormSectionLabel { text: "CENTRAL — REST API" }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12
            LoggerFormField { id: apiPortField; label: "API Port"; isDark: root.dialog.isDark }
            LoggerFormField {
                id: tokenField
                label: "API Token"
                isDark: root.dialog.isDark
                isPassword: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.preferredWidth: scanQrRow.implicitWidth + 24
                Layout.preferredHeight: 32
                radius: 6
                opacity: root.dialog.qrScanEnabled ? 1.0 : 0.45
                color: scanQrMouse.containsMouse && root.dialog.qrScanEnabled
                    ? Colors.buttonSecondaryHover(root.dialog.isDark)
                    : Colors.surfaceMuted(root.dialog.isDark)
                border.width: 1
                border.color: Colors.borderMuted(root.dialog.isDark)
                RowLayout {
                    id: scanQrRow
                    anchors.centerIn: parent
                    spacing: 6
                    UiIcon {
                        name: "qrCode"
                        size: 14
                        iconColor: Colors.textMuted(root.dialog.isDark)
                    }
                    UiLabel {
                        textType: UiLabel.Caption
                        text: "Scan QR…"
                        color: Colors.textMuted(root.dialog.isDark)
                        font.family: "Inter"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
                MouseArea {
                    id: scanQrMouse
                    anchors.fill: parent
                    hoverEnabled: root.dialog.qrScanEnabled
                    cursorShape: root.dialog.qrScanEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.dialog.qrScanEnabled)
                            root.dialog.importQrFromFile()
                        else if (typeof window !== "undefined" && window && window.notify)
                            window.notify("QR scan unavailable (see README — ZBar DLL on Windows)", "warning")
                    }
                }
            }
            UiLabel {
        textType: UiLabel.Caption
                Layout.fillWidth: true
                text: root.dialog.qrScanEnabled
                    ? "Import pairing QR from data-logger (PNG/JPG)"
                    : "QR scan unavailable — enter API token manually"
                color: Colors.textMuted(root.dialog.isDark)
                font.family: "Inter"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
        LoggerFormField {
            id: apiBaseUrlField
            label: "API Base URL (optional)"
            isDark: root.dialog.isDark
            Layout.fillWidth: true
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 6
            color: connectMouse.containsMouse ? Colors.primaryHover(root.dialog.isDark) : Colors.primary(root.dialog.isDark)
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                UiIcon {
                    name: "link"
                    size: 16
                    iconColor: "#ffffff"
                }
                UiLabel {
                    textType: UiLabel.Body2
                    text: "Connect & Load Config"
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }
            MouseArea {
                id: connectMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dialog.connectAndLoadConfig()
            }
        }
    }
}
