import QtQuick

import "../.."

/*
 * Hover overlay — animates opacity only (never transparent ↔ solid fill).
 * Prevents light-mode flicker from ColorAnimation through rgba(0,0,0,0).
 */
Rectangle {
    id: root

    property bool hovered: false
    property bool isDark: true
    property real cornerRadius: 0

    anchors.fill: parent
    radius: cornerRadius
    color: isDark ? "#ffffff" : "#000000"
    opacity: hovered ? (isDark ? UiMotion.hoverOpacityDark : UiMotion.hoverOpacityLight) : 0
    z: -1

    Behavior on opacity {
        NumberAnimation {
            duration: UiMotion.durationFast
            easing.type: UiMotion.easingOut
        }
    }
}
