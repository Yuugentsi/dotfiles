import "PanelTheme.js" as Theme
import QtQuick

Rectangle {
    id: root
    property string label: ""
    property string glyph: ""
    property bool active: false
    signal clicked
    width: 36
    height: 36
    radius: 18
    opacity: enabled ? 1 : 0.35
    color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : (hit.containsMouse ? Theme.hover : Theme.surface)
    border.width: 1
    border.color: active ? Qt.alpha(Theme.accent, 0.6) : Qt.alpha(Theme.foreground, 0.07)
    scale: hit.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.active ? Theme.accent : Theme.muted
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 17
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    PanelToolTip {
        visible: hit.containsMouse
        text: root.label
    }
}
