import QtQuick

Rectangle {
    id: root
    property bool checked: false
    property bool hasCursor: false
    property color foreground: "#eef3f8"
    readonly property bool containsMouse: hit.containsMouse
    signal toggled()
    signal hovered(bool on)
    implicitWidth: 34
    implicitHeight: 20
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: checked ? "#c3b7ff" : "#37343f"
    border.width: hasCursor ? 1 : 0
    border.color: foreground
    Rectangle { x: root.checked ? parent.width - width - 3 : 3; y: 3; width: 14; height: 14; radius: 7; color: root.checked ? "#18181d" : root.foreground; Behavior on x { NumberAnimation { duration: 120 } } }
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(); onContainsMouseChanged: root.hovered(containsMouse) }
}
