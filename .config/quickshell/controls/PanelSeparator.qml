import "PanelTheme.js" as Theme
import QtQuick

Rectangle {
    property color foreground: Theme.foreground
    width: parent.width
    height: 1
    color: foreground
    opacity: 0.14
}
