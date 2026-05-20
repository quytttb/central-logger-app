import QtQuick

import "../cards"

/*
 * Panel card with padded chart content area (title header + 8px chart margins).
 */
PanelCard {
    id: root

    property int chartMargins: 8

    default property alias chartContent: chartHost.data

    Item {
        id: chartHost
        anchors.fill: parent
        anchors.margins: root.chartMargins
    }
}
