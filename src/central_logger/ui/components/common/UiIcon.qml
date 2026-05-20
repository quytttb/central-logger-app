import QtQuick

/*
 * Material Symbols Outlined icon (font-based). Requires MaterialSymbolsOutlined.ttf loaded in main.py.
 */
Text {
    id: root

    property string name: ""
    property int size: 24
    property color iconColor: "#000000"

    text: MaterialIcons.glyph(name)
    font.family: "Material Symbols Outlined"
    font.pixelSize: size
    color: root.iconColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
