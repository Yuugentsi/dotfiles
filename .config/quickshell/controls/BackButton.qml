import QtQuick

Rectangle {
    id: root
    signal clicked()
    width: 76
    height: 26
    radius: 5
    color: hit.containsMouse || activeFocus ? "#383044" : "#18181d"
    border.width: 1
    border.color: "#37343f"
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Back to panel menu"
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Text {
        anchors.centerIn: parent
        text: "← Back"
        color: "#eef3f8"
        font.family: "sans-serif"
        font.pixelSize: 11
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
