import QtQuick

Rectangle {
    id: root
    property string iconText: ""
    property string tooltipText: ""
    property color foreground: "#eef3f8"
    property color hoverColor: foreground
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool hasCursor: false
    signal clicked()
    signal hovered(bool isHovered)
    implicitWidth: 26
    implicitHeight: 26
    width: implicitWidth
    height: implicitHeight
    radius: 4
    color: hit.containsMouse || hasCursor ? "#383044" : "transparent"
    Text { anchors.centerIn: parent; text: root.iconText; color: hit.containsMouse ? root.hoverColor : root.foreground; font.family: root.fontFamily; font.pixelSize: 15 }
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked(); onContainsMouseChanged: root.hovered(containsMouse) }
    PanelToolTip { visible: hit.containsMouse; text: root.tooltipText }
}
