import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import "../../"
import "../../components/common"
import "../../components/cards"
import components

/*
 * Application settings page — Shadcn style.
 */
Item {
    id: view

    property bool isDark: true
    property var settingsController: null

    readonly property var timezoneOptions: [
        "Asia/Ho_Chi_Minh",
        "UTC",
        "Asia/Bangkok",
        "Asia/Singapore",
        "Asia/Tokyo",
        "Asia/Shanghai",
        "Europe/London",
        "Europe/Berlin",
        "America/New_York",
        "America/Los_Angeles",
        "Australia/Sydney"
    ]

    property var activeTimezoneOptions: timezoneOptions

    signal themeApplied(string theme)
    signal settingsSaved()

    function _themeIndex(theme) {
        return theme === "light" ? 1 : 0
    }

    function _timezoneModelFor(tz) {
        var opts = timezoneOptions.slice()
        if (tz && opts.indexOf(tz) < 0)
            opts.unshift(tz)
        return opts
    }

    function syncFromController() {
        if (!settingsController)
            return
        themeCombo.currentIndex = _themeIndex(settingsController.theme)
        var tz = settingsController.systemTimezone
        activeTimezoneOptions = _timezoneModelFor(tz)
        timezoneCombo.currentIndex = Math.max(0, activeTimezoneOptions.indexOf(tz))
        retentionSpin.value = settingsController.dataRetentionDays
        maintenanceCheck.checked = settingsController.maintenanceMode
    }

    function saveAll() {
        if (!settingsController)
            return
        var themeValue = themeCombo.currentIndex === 1 ? "light" : "dark"
        var tz = activeTimezoneOptions[timezoneCombo.currentIndex]
        settingsController.save(
            themeValue,
            tz,
            retentionSpin.value,
            maintenanceCheck.checked
        )
    }

    Connections {
        target: view.settingsController
        ignoreUnknownSignals: true
        function onThemeChanged() { view.syncFromController() }
        function onSystemTimezoneChanged() { view.syncFromController() }
        function onDataRetentionDaysChanged() { view.syncFromController() }
        function onMaintenanceModeChanged() { view.syncFromController() }
        function onSaved() {
            if (typeof window !== "undefined" && window && window.notify)
                window.notify("Settings saved", "success")
            if (settingsController)
                view.themeApplied(settingsController.theme)
            view.settingsSaved()
        }
        function onLoadError(msg) {
            if (typeof window !== "undefined" && window && window.notify)
                window.notify(msg, "error")
        }
    }

    Component.onCompleted: syncFromController()

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
                iconName: "save"
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

                    FormSectionLabel {
                        Layout.fillWidth: true
                        isDark: view.isDark
                        text: "APPEARANCE"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        UiLabel {
                            textType: UiLabel.Body2
                            text: "Default Theme"
                            color: Colors.textPrimary(view.isDark)
                            font.family: "Roboto"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        FormComboBox {
                            id: themeCombo
                            Layout.fillWidth: true
                            isDark: view.isDark
                            model: ["Dark", "Light"]
                            currentIndex: 0
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Colors.divider(view.isDark)
                    }

                    FormSectionLabel {
                        Layout.fillWidth: true
                        isDark: view.isDark
                        text: "DATA & CHARTS"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        UiLabel {
                            textType: UiLabel.Body2
                            text: "System Timezone"
                            color: Colors.textPrimary(view.isDark)
                            font.family: "Roboto"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        FormComboBox {
                            id: timezoneCombo
                            Layout.fillWidth: true
                            isDark: view.isDark
                            model: view.activeTimezoneOptions
                            currentIndex: 0
                        }
                        UiLabel {
                            textType: UiLabel.Caption
                            Layout.fillWidth: true
                            text: "Charts and event timestamps use this timezone."
                            color: Colors.textMuted(view.isDark)
                            font.family: "Inter"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        UiLabel {
                            textType: UiLabel.Body2
                            text: "Data Retention (Days)"
                            color: Colors.textPrimary(view.isDark)
                            font.family: "Roboto"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        FormSpinBox {
                            id: retentionSpin
                            isDark: view.isDark
                            from: 1
                            to: 3650
                            value: 30
                            editable: true
                        }
                        UiLabel {
                            textType: UiLabel.Caption
                            Layout.fillWidth: true
                            text: "Sensor readings and events older than this are removed on save and hourly."
                            color: Colors.textMuted(view.isDark)
                            font.family: "Inter"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Colors.divider(view.isDark)
                    }

                    FormSectionLabel {
                        Layout.fillWidth: true
                        isDark: view.isDark
                        text: "OPERATIONS"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        CheckBox {
                            id: maintenanceCheck
                            Material.theme: view.isDark ? Material.Dark : Material.Light
                            Material.accent: Colors.primary(view.isDark)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            UiLabel {
                                textType: UiLabel.Body2
                                text: "Maintenance Mode"
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
                            UiLabel {
                                textType: UiLabel.Caption
                                Layout.fillWidth: true
                                text: "Suppresses Alarm, Offline, and Warning system events while enabled."
                                color: Colors.textMuted(view.isDark)
                                font.family: "Inter"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 32 }
        }
    }
}
