import QtQuick
import "../../controls/PanelTheme.js" as Theme

Text {
    id: glyphButton
    signal clicked
    font.family: Theme.iconFont
    font.pixelSize: 22
    color: glyphMouse.containsMouse ? Theme.accent : Theme.foreground
    scale: glyphMouse.pressed ? 0.85 : glyphMouse.containsMouse ? 1.1 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    MouseArea {
        id: glyphMouse
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: glyphButton.clicked()
    }
}
