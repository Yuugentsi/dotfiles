import "PanelTheme.js" as Theme
import QtQuick

Rectangle {
    id: root
    signal clicked()
    width: 76
    height: 26
    radius: height / 2
    color: hit.containsMouse || activeFocus ? Theme.hover : Qt.alpha(Theme.foreground, 0.05)
    border.width: 1
    border.color: hit.containsMouse || activeFocus ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.foreground, 0.1)
    scale: hit.pressed ? 0.95 : 1
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Back to panel menu"
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    Text {
        anchors.centerIn: parent
        text: "← Back"
        color: Theme.foreground
        font.family: "sans-serif"
        font.pixelSize: 11
        font.weight: Font.Medium
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
