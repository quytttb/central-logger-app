import QtQuick
import QtQuick.Controls

import "StatusBadges.js" as StatusBadges

/*
 * Single badge for sensor table rows — maps display_status to Badge styling.
 */
Badge {
    id: root

    property string status: ""
    property string alarmType: ""

    readonly property var _mapped: StatusBadges.sensorDisplayStatus(status, alarmType)

    visible: _mapped.text.length > 0
    text: _mapped.text
    badgeColor: _mapped.color
}
