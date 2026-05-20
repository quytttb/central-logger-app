pragma Singleton
import QtQuick

QtObject {
    readonly property int durationFast: animationsEnabled ? 120 : 0
    readonly property int durationNormal: animationsEnabled ? 200 : 0
    readonly property int durationSlow: animationsEnabled ? 320 : 0
    readonly property int durationDialog: animationsEnabled ? 260 : 0
    readonly property int easingOut: Easing.OutCubic
    readonly property int easingIn: Easing.InCubic
    readonly property int easingInOut: Easing.InOutCubic
    property bool animationsEnabled: true

    /** Row / list hover — opacity of white (dark) or black (light) overlay; avoid animating Color to "transparent". */
    readonly property real hoverOpacityDark: 0.08
    readonly property real hoverOpacityLight: 0.06
}
