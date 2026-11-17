import "PanelTheme.js" as Theme
import QtQuick
import QtQuick.Controls

ToolTip {
    id: tip
    property string fontFamily: "sans-serif"
    font.family: fontFamily
    font.pixelSize: 11
    delay: 500
    padding: 7
    leftPadding: 11
    rightPadding: 11
    contentItem: Text {
        text: tip.text
        font: tip.font
        color: Theme.foreground
    }
    background: Rectangle {
        radius: 10
        color: "#f0221c21"
        border.width: 1
        border.color: Theme.border
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
}
