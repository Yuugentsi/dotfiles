import "PanelTheme.js" as Theme
import QtQuick

Text {
    property color foreground: Theme.foreground
    property string fontFamily: "sans-serif"
    color: Theme.dim
    font.family: fontFamily
    font.pixelSize: 10
    font.weight: Font.Bold
    font.letterSpacing: 1.4
    font.capitalization: Font.AllUppercase
}
