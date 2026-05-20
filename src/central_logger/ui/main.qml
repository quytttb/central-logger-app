import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial
import CentralLogger.Core 1.0

import "."
import "views"
import "components"

Qaterial.ApplicationWindow {
    id: window
    width: 1440
    height: 880
    minimumWidth: 1100
    minimumHeight: 680
    visibility: Window.Maximized
    visible: true
    title: "Central Logger"
    flags: Qt.Window | Qt.FramelessWindowHint

    property bool isDark: true
    property string currentView: "dashboard"
    property bool sidebarOpen: true
    property int selectedLoggerId: -1

    property alias loggersModel: loggersModel
    property alias dashboardController: dashboardController
    property alias settingsController: settingsController
    property string searchQuery: ""

    function _viewOpacity(name) {
        return window.currentView === name ? 1.0 : 0.0
    }

    function _viewZ(name) {
        return window.currentView === name ? 2 : 0
    }

    function syncAppStats() {
        AppState.totalLoggers = loggersModel.count()
        AppState.onlineLoggers = loggersModel.onlineCount()
        AppState.alarmCount = loggersModel.alarmCount()
        AppState.statusText = AppState.totalLoggers === 0
            ? "Ready — no loggers configured"
            : "Monitoring " + AppState.onlineLoggers + "/" + AppState.totalLoggers + " online"
    }

    LoggerListModel { id: loggersModel }
    RecentEventsModel { id: recentEventsModel }

    DashboardController {
        id: dashboardController
        model: loggersModel
        Component.onCompleted: {
            dashboardController.start()
            window.syncAppStats()
        }
    }

    SettingsController {
        id: settingsController
        Component.onCompleted: {
            settingsController.load()
            window._applyTheme((settingsController.theme || "dark").toLowerCase() === "dark")
        }
    }

    Connections {
        target: dashboardController
        function onAppStatsChanged() { window.syncAppStats() }
        function onLoggerRemoved(id) {
            if (id === window.selectedLoggerId) {
                window.selectedLoggerId = -1
                window.currentView = "loggers"
            }
        }
    }

    Connections {
        target: settingsController
        function onThemeChanged() {
            window._applyTheme((settingsController.theme || "dark").toLowerCase() === "dark")
        }
    }

    Component.onCompleted: {
        _applyTheme(isDark)
    }

    function _applyTheme(dark) {
        isDark = dark
        if (dark) {
            Qaterial.Style.theme = Qaterial.Style.Theme.Dark
        } else {
            Qaterial.Style.theme = Qaterial.Style.Theme.Light
        }
    }

    onClosing: function (close) {
        close.accepted = false
        TrayCtl.quitApp()
    }

    function notify(message, severity) {
        var t = severity === "error" ? 7000 : 4000
        Qaterial.SnackbarManager.show({ text: message, timeout: t })
    }

    // ── Root layout: Sidebar + Main content ─────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar ──────────────────────────────────────────────────────────
        AppSidebar {
            id: sidebar
            Layout.preferredWidth: sidebarOpen ? 256 : 64
            Layout.fillHeight: true
            currentView: window.currentView
            isOpen: window.sidebarOpen
            isDark: window.isDark

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: UiMotion.durationNormal
                    easing.type: UiMotion.easingOut
                }
            }

            onNavigate: function (view) {
                window.currentView = view
            }
        }

        // ── Main content column ──────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Top Bar ──────────────────────────────────────────────────────
            AppTopBar {
                id: topBar
                Layout.fillWidth: true
                isDark: window.isDark

                onMenuToggled: window.sidebarOpen = !window.sidebarOpen
                onThemeChanged: function (dark) {
                    window._applyTheme(dark)
                    if (settingsController) settingsController.theme = dark ? "dark" : "light"
                }
                onSearchChanged: function (q) {
                    window.searchQuery = q
                    if (q && window.currentView !== "loggers") {
                        window.currentView = "loggers"
                    }
                }
            }

            // ── Content Area (crossfade views) ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colors.surfaceMuted(window.isDark)

                DashboardView {
                    anchors.fill: parent
                    isDark: window.isDark
                    dashboardController: window.dashboardController
                    recentEventsModel: recentEventsModel
                    opacity: window._viewOpacity("dashboard")
                    visible: opacity > 0
                    enabled: visible
                    z: window._viewZ("dashboard")
                    Behavior on opacity {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                }

                LoggersView {
                    anchors.fill: parent
                    isDark: window.isDark
                    loggersModel: window.loggersModel
                    dashboardController: window.dashboardController
                    searchQuery: window.searchQuery
                    opacity: window._viewOpacity("loggers")
                    visible: opacity > 0
                    enabled: visible
                    z: window._viewZ("loggers")
                    Behavior on opacity {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                    onSelectLogger: function (loggerId) {
                        window.selectedLoggerId = loggerId
                        window.currentView = "logger-detail"
                    }
                }

                LoggerDetailView {
                    anchors.fill: parent
                    isDark: window.isDark
                    loggerId: window.selectedLoggerId
                    loggersModel: window.loggersModel
                    dashboardController: window.dashboardController
                    opacity: window._viewOpacity("logger-detail")
                    visible: opacity > 0
                    enabled: visible
                    z: window._viewZ("logger-detail")
                    Behavior on opacity {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                    onGoBack: window.currentView = "loggers"
                }

                SettingsView {
                    anchors.fill: parent
                    isDark: window.isDark
                    settingsController: window.settingsController
                    opacity: window._viewOpacity("settings")
                    visible: opacity > 0
                    enabled: visible
                    z: window._viewZ("settings")
                    Behavior on opacity {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                }
            }
        }
    }

    // ── Frame resize handles (keep for frameless window) ─────────────────────
    FrameResizeHandles {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: parent.top
        z: 100
    }

    // ── Global Focus Clear ───────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        z: 9999
        propagateComposedEvents: true
        onPressed: function(mouse) {
            if (window.activeFocusItem) {
                window.activeFocusItem.focus = false
            }
            mouse.accepted = false
        }
    }
}
