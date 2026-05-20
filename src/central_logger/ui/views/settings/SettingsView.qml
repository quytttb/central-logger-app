import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/common"
import "../../components/cards"

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

            PageHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                isDark: view.isDark
                titleFontFamily: "Roboto"
                title: "Application Settings"
                subtitle: "Global preferences for Central Logger instance."
                actionText: "Save Changes"
                onActionClicked: view.saveAll()
            }

            PanelCard {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                isDark: view.isDark
                hoverable: false
                title: "General configuration"
                titleFontFamily: "Roboto"
                bodyMargins: 24

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 24

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 24
                        rowSpacing: 16

                        LabeledField { id: themeField; label: "Default Theme"; value: view.theme; isDark: view.isDark }
                        LabeledField { id: timezoneField; label: "System Timezone"; value: view.systemTimezone; isDark: view.isDark }
                        LabeledField { id: retentionField; label: "Data Retention (Days)"; value: String(view.dataRetentionDays); isDark: view.isDark }
                        LabeledField { id: mapZoomField; label: "Default Map Zoom"; value: String(view.defaultMapZoom); isDark: view.isDark }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Colors.divider(view.isDark)
                    }

                    Qaterial.LabelBody1 {
                        text: "Alerting & Notifications"
                        color: Colors.textPrimary(view.isDark)
                        font.family: "Roboto"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Qaterial.LabelBody2 {
                            text: "Alert Email Contacts"
                            color: Colors.textPrimary(view.isDark)
                            font.family: "Roboto"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            radius: 6
                            color: Colors.surfaceMuted(view.isDark)
                            border.width: 1
                            border.color: Colors.border(view.isDark)
                            TextArea {
                                id: emailsArea
                                anchors.fill: parent
                                anchors.margins: 8
                                text: view.alertEmailContacts
                                font.family: "Roboto"
                                font.pixelSize: 14
                                color: Colors.textPrimary(view.isDark)
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
                            color: Colors.textPrimary(view.isDark)
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

            Item { Layout.preferredHeight: 32 }
        }
    }
}
