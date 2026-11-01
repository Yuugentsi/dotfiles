import "PanelTheme.js" as Theme
import QtQuick

Text {
    property color foreground: Theme.foreground
    property string fontFamily: "sans-serif"
    color: Qt.darker(foreground, 1.4)
    font.family: fontFamily
    font.pixelSize: 10
    font.bold: true
    font.letterSpacing: 1
}
