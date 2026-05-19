import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/common"

/*
 * Application settings page — Shadcn style.
 */
Item {
    id: view

    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark
    property var settingsController: null

    property string theme: settingsController ? settingsController.theme : "dark"
    property string systemTimezone: settingsController ? settingsController.systemTimezone : "Asia/Ho_Chi_Minh"
    property int dataRetentionDays: settingsController ? settingsController.dataRetentionDays : 30
    property int defaultMapZoom: settingsController ? settingsController.defaultMapZoom : 12
    property bool maintenanceMode: settingsController ? settingsController.maintenanceMode : false
    property string alertEmailContacts: settingsController ? settingsController.alertEmailContacts : ""

    signal themeApplied(string theme)

    function saveAll() {
        if (!settingsController) return
        var retention = parseInt(retentionField.value)
        var zoom = parseInt(mapZoomField.value)
        var themeValue = (themeField.value || "dark").toLowerCase()
        settingsController.save(
            themeValue,
            timezoneField.value,
            isNaN(retention) ? view.dataRetentionDays : retention,
            isNaN(zoom) ? view.defaultMapZoom : zoom,
            maintenanceCheck.checked,
            emailsArea.text
        )
        view.themeApplied(themeValue)
    }

    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 64
        clip: true

        ColumnLayout {
            id: mainCol
            width: Math.min(parent.width, 900)
            spacing: 24

            Item { Layout.preferredHeight: 8 }

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Qaterial.LabelHeadline5 {
                        text: "Application Settings"
                        color: view.isDark ? "#fafafa" : "#18181b"
                        font.family: "Roboto"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }
                    Qaterial.LabelBody2 {
                        text: "Global preferences for Central Logger instance."
                        color: view.isDark ? "#a1a1aa" : "#71717a"
                        font.family: "Roboto"
                        font.pixelSize: 14
                    }
                }

                Rectangle {
                    Layout.preferredWidth: saveRow.implicitWidth + 32
                    Layout.preferredHeight: 36
                    radius: 6
                    color: saveMouse.pressed ? "#1d4ed8"
                         : saveMouse.containsMouse ? "#3b82f6"
                         : "#2563eb"
                    RowLayout {
                        id: saveRow
                        anchors.centerIn: parent
                        spacing: 6
                        Qaterial.LabelBody2 {
                            text: "Save Changes"
                            color: "#ffffff"
                            font.family: "Roboto"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.saveAll()
                    }
                }
            }

            // ── Settings Card ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                radius: 12
                color: view.isDark ? "#09090b" : "#ffffff"
                implicitHeight: settingsCol.implicitHeight

                // Overlay border
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.width: 1
                    border.color: view.isDark ? "#27272a" : "#e4e4e7"
                    z: 10
                }

                ColumnLayout {
                    id: settingsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    // Card header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        color: "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 1
                            color: view.isDark ? "#27272a" : "#f4f4f5"
                        }
                        Qaterial.LabelBody1 {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: "General configuration"
                            color: view.isDark ? "#fafafa" : "#18181b"
                            font.family: "Roboto"
                            font.pixelSize: 18
                            font.weight: Font.Medium
                        }
                    }

                    // Form fields
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: 24
                        spacing: 24

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 24
                            rowSpacing: 16

                            SettingsField { id: themeField;     label: "Default Theme";         value: view.theme;                       isDark: view.isDark }
                            SettingsField { id: timezoneField;  label: "System Timezone";       value: view.systemTimezone;              isDark: view.isDark }
                            SettingsField { id: retentionField; label: "Data Retention (Days)"; value: String(view.dataRetentionDays);   isDark: view.isDark }
                            SettingsField { id: mapZoomField;   label: "Default Map Zoom";      value: String(view.defaultMapZoom);      isDark: view.isDark }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: view.isDark ? "#27272a" : "#f4f4f5"
                        }

                        // Alerting section
                        Qaterial.LabelBody1 {
                            text: "Alerting & Notifications"
                            color: view.isDark ? "#fafafa" : "#18181b"
                            font.family: "Roboto"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Qaterial.LabelBody2 {
                                text: "Alert Email Contacts"
                                color: view.isDark ? "#fafafa" : "#18181b"
                                font.family: "Roboto"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 96
                                radius: 6
                                color: view.isDark ? "#18181b" : "#fafafa"
                                border.width: 1
                                border.color: view.isDark ? "#27272a" : "#d4d4d8"
                                TextArea {
                                    id: emailsArea
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    text: view.alertEmailContacts
                                    font.family: "Roboto"
                                    font.pixelSize: 14
                                    color: view.isDark ? "#fafafa" : "#18181b"
                                    wrapMode: Text.WordWrap
                                    background: null
                                }
                            }
                        }

                        RowLayout {
                            spacing: 12
                            CheckBox {
                                id: maintenanceCheck
                                checked: view.maintenanceMode
                            }
                            Qaterial.LabelBody2 {
                                text: "Enable Maintenance Mode (suppress all alerts)"
                                color: view.isDark ? "#fafafa" : "#18181b"
                                font.family: "Roboto"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: maintenanceCheck.toggle()
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 32 }
        }
    }
}
