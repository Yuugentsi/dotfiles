pragma ComponentBehavior: Bound
import QtQuick

Row {
    id: root
    property real value: 0
    property bool muted: false
    property string symbol: "󰕾"
    property string label: Math.round(value * 100) + "%"
    property color accentColor: "#a99aad"
    property color progressEndColor: "#a99aad"
    property real displayedValue: muted ? 0 : Math.max(0, Math.min(1, value))
    spacing: 8
    height: 20

    Behavior on displayedValue {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        text: root.symbol
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        color: root.muted ? "#b08f8f" : "#a99aad"
        horizontalAlignment: Text.AlignHCenter
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 100
        height: 12
        color: "#25242f"
        border.color: "#484351"
        Row {
            x: 3; y: 3; spacing: 2
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    width: 5; height: 6
                    color: index < root.displayedValue * 14 ? "#a99aad" : "transparent"
                }
            }
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: "Noto Sans"
        font.pixelSize: 11
        font.weight: Font.Medium
        color: root.muted ? "#b08f8f" : "#d4d5d8"
    }
}
