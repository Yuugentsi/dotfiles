import "PanelTheme.js" as Theme
import QtQuick

Rectangle {
    id: root
    property string label: ""
    property bool selected: false
    signal clicked
    implicitWidth: labelItem.implicitWidth + 22
    height: 28
    radius: height / 2
    opacity: enabled || selected ? 1 : 0.35
    color: selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : (hit.containsMouse ? Theme.hover : Theme.surface)
    border.width: 1
    border.color: selected ? Qt.alpha(Theme.accent, 0.6) : Qt.alpha(Theme.foreground, 0.07)
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.checked: selected
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    Text {
        id: labelItem
        anchors.centerIn: parent
        text: root.label
        color: root.selected ? Theme.accent : Theme.muted
        font.family: "sans-serif"
        font.pixelSize: 9
        font.weight: Font.Black
        font.letterSpacing: 0.8
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
