import "PanelTheme.js" as Theme
import QtQuick

Rectangle {
    id: root
    property bool checked: false
    property bool hasCursor: false
    property color foreground: Theme.foreground
    readonly property bool containsMouse: hit.containsMouse
    signal toggled()
    signal hovered(bool on)
    implicitWidth: 38
    implicitHeight: 22
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: checked ? Theme.accent : Theme.track
    gradient: checked ? onGradient : null
    Gradient {
        id: onGradient
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.accent }
        GradientStop { position: 1; color: Theme.accentAlt }
    }
    Behavior on color { ColorAnimation { duration: 160 } }
    border.width: 1
    border.color: hasCursor ? foreground : Qt.alpha(Theme.foreground, root.checked ? 0.2 : 0.08)
    Rectangle { x: root.checked ? parent.width - width - 3 : 3; y: 3; width: 16; height: 16; radius: 8; color: root.checked ? Theme.foreground : Theme.muted; scale: hit.pressed ? 0.85 : 1; Behavior on scale { NumberAnimation { duration: 90 } } Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(); onContainsMouseChanged: root.hovered(containsMouse) }
}
