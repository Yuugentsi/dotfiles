import "PanelTheme.js" as Theme
import QtQuick

Rectangle {
    property color foreground: Theme.foreground
    width: parent.width
    height: 1
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 0.2; color: Qt.alpha(foreground, 0.14) }
        GradientStop { position: 0.8; color: Qt.alpha(foreground, 0.14) }
        GradientStop { position: 1; color: "transparent" }
    }
}
