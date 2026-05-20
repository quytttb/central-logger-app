import QtQuick
import QtQuick.Controls

import "../.."

/*
 * Bottom snackbar for global notifications.
 */
Popup {
    id: snackbar

    property bool isDark: true
    property string messageText: ""

    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose
    padding: 0

    width: Math.min(400, parent ? parent.width - 32 : 400)
    height: 48
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? parent.height - height - 24 : 0

    background: Rectangle {
        radius: 6
        color: {
            if (_severity === "error")
                return Colors.destructive(snackbar.isDark)
            if (_severity === "success")
                return Colors.primary(snackbar.isDark)
            if (_severity === "warning")
                return Colors.badgeFill(snackbar.isDark, "amber")
            return Colors.surfaceMuted(snackbar.isDark)
        }
        border.width: 1
        border.color: Colors.border(snackbar.isDark)
    }

    contentItem: UiLabel {
        text: snackbar.messageText
        textType: UiLabel.Body2
        color: _severity === "warning"
            ? Colors.badgeText(snackbar.isDark, "amber")
            : (_severity === "error" || _severity === "success" ? "#ffffff" : Colors.textPrimary(snackbar.isDark))
        horizontalAlignment: Text.AlignHCenter
        anchors.fill: parent
        anchors.margins: 12
        elide: Text.ElideRight
        maximumLineCount: 2
    }

    property string _severity: "info"

    Timer {
        id: hideTimer
        interval: 4000
        onTriggered: snackbar.close()
    }

    function show(text, timeoutMs, severity) {
        messageText = text || ""
        _severity = severity || "info"
        var ms = timeoutMs > 0 ? timeoutMs : (severity === "error" ? 7000 : 4000)
        hideTimer.interval = ms
        open()
        hideTimer.restart()
    }
}
