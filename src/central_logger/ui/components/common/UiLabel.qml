import QtQuick
import QtQuick.Controls

/*
 * Typography wrapper (Material Design 2 scale). Override font.* on the instance when needed.
 */
Label {
    id: root

    enum TextType {
        Caption,
        Body2,
        Body1,
        Headline5,
        Headline3
    }

    property int textType: UiLabel.Body2

    font.family: "Roboto"
    font.pixelSize: {
        switch (root.textType) {
        case UiLabel.Caption: return 12
        case UiLabel.Body2: return 14
        case UiLabel.Body1: return 16
        case UiLabel.Headline5: return 24
        case UiLabel.Headline3: return 30
        default: return 14
        }
    }
    font.weight: {
        switch (root.textType) {
        case UiLabel.Headline5: return Font.Medium
        case UiLabel.Headline3: return Font.Bold
        default: return Font.Normal
        }
    }
}
