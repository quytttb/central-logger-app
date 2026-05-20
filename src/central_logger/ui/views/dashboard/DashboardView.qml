import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CentralLogger.Core 1.0

import "../../"
import "../../components/cards"
import "../../components/common"

/*
 * Dashboard overview page — Shadcn style.
 * Shows: stat cards (Total, Online, Alarms), recent events list.
 */
Item {
    id: view

    property bool isDark: true
    property var dashboardController: null
    property var recentEventsModel: null

    signal selectLogger(int loggerId)

    readonly property int gridGap: 24
    readonly property int gridMargin: 32
    readonly property int gridColumns: Math.max(1, Math.min(3, Math.floor((width - gridMargin * 2) / 280)))
    readonly property real gridContentWidth: Math.max(0, width - gridMargin * 2)
    readonly property real gridColWidth: gridColumns > 0
        ? (gridContentWidth - (gridColumns - 1) * gridGap) / gridColumns
        : gridContentWidth
    /** Rộng bằng 2 stat card + 1 khe giữa (desktop 3 cột). */
    readonly property real chartBlockWidth: 2 * gridColWidth + gridGap
    readonly property real eventsBlockWidth: gridColWidth

    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 64
        clip: true

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: gridGap

            Item { Layout.preferredHeight: 8 }

            PageHeader {
                Layout.fillWidth: true
                Layout.leftMargin: gridMargin
                Layout.rightMargin: gridMargin
                isDark: view.isDark
                titleFontFamily: "Roboto"
                title: "System Overview"
                subtitle: AppState.statusText
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: gridMargin
                Layout.rightMargin: gridMargin
                columns: view.gridColumns
                columnSpacing: gridGap
                rowSpacing: gridGap

                StatCard {
                    Layout.fillWidth: true
                    statTitle: "Total Loggers"
                    value: String(AppState.totalLoggers)
                    iconName: "server"
                    isDark: view.isDark
                }
                StatCard {
                    Layout.fillWidth: true
                    statTitle: "Online Loggers"
                    value: String(AppState.onlineLoggers)
                    iconName: "wifi"
                    isDark: view.isDark
                    trend: AppState.totalLoggers > 0 && AppState.onlineLoggers === AppState.totalLoggers ? "100% stable" : "Some offline"
                    trendColor: AppState.totalLoggers > 0 && AppState.onlineLoggers === AppState.totalLoggers ? "green" : "amber"
                }
                StatCard {
                    Layout.fillWidth: true
                    statTitle: "Active Alarms"
                    value: String(AppState.alarmCount)
                    iconName: "alertOutline"
                    isDark: view.isDark
                    trend: AppState.alarmCount > 0 ? "Requires attention" : "All clear"
                    trendColor: AppState.alarmCount > 0 ? "red" : "green"
                }
            }

            // Desktop: chart = 2 cột, events = 1 cột (cùng gridColWidth với stat cards)
            RowLayout {
                visible: view.gridColumns >= 3
                Layout.leftMargin: gridMargin
                Layout.rightMargin: gridMargin
                spacing: gridGap

                NetworkTrafficChart {
                    Layout.preferredWidth: view.chartBlockWidth
                    Layout.maximumWidth: view.chartBlockWidth
                    Layout.preferredHeight: 400
                    Layout.minimumHeight: 400
                    isDark: view.isDark
                    dashboardController: view.dashboardController
                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                    Behavior on Layout.maximumWidth {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                }

                RecentEventsList {
                    Layout.preferredWidth: view.eventsBlockWidth
                    Layout.maximumWidth: view.eventsBlockWidth
                    Layout.preferredHeight: 400
                    Layout.minimumHeight: 400
                    isDark: view.isDark
                    dashboardController: view.dashboardController
                    eventsModel: view.recentEventsModel
                    onSelectLogger: function (id) { view.selectLogger(id) }
                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                    Behavior on Layout.maximumWidth {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                }
            }

            // Thu hẹp màn hình: xếp dọc full width
            ColumnLayout {
                visible: view.gridColumns < 3
                Layout.fillWidth: true
                Layout.leftMargin: gridMargin
                Layout.rightMargin: gridMargin
                spacing: gridGap

                NetworkTrafficChart {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 400
                    Layout.minimumHeight: 400
                    isDark: view.isDark
                    dashboardController: view.dashboardController
                }

                RecentEventsList {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 400
                    Layout.minimumHeight: 400
                    isDark: view.isDark
                    dashboardController: view.dashboardController
                    eventsModel: view.recentEventsModel
                    onSelectLogger: function (id) { view.selectLogger(id) }
                }
            }

            Item { Layout.preferredHeight: 32 }
        }
    }
}
