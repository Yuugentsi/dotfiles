pragma ComponentBehavior: Bound
import QtQuick

Row {
    id: root
    property real value: 0
    property bool muted: false
    property string symbol: "󰕾"
    property string label: Math.round(value * 100) + "%"
    property color accentColor: "#cba6f7"
    property color progressEndColor: "#b4befe"
    property real displayedValue: muted ? 0 : Math.max(0, Math.min(1, value))
    spacing: 8

    Behavior on displayedValue {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        readonly property color tone: root.muted ? "#f38ba8" : root.accentColor
        color: Qt.rgba(tone.r, tone.g, tone.b, 0.06)
        border.width: 1
        border.color: "#313244"
        Rectangle { width: 7; height: 1; color: parent.tone }
        Rectangle { width: 1; height: 7; color: parent.tone }
        Text {
            anchors.centerIn: parent
            text: root.symbol
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: parent.tone
        }
    }
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 84
        height: 14
        Row {
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: 14
                Rectangle {
                    id: segment
                    required property int index
                    readonly property real amount: Math.max(0, Math.min(1, root.displayedValue * 14 - index))
                    width: 4
                    height: 10
                    rotation: 12
                    color: "#313244"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * segment.amount
                        color: Qt.tint(root.accentColor, Qt.rgba(root.progressEndColor.r, root.progressEndColor.g, root.progressEndColor.b, segment.index / 13))
                    }
                }
            }
        }
    }
    Text {
        id: levelLabel
        anchors.verticalCenter: parent.verticalCenter
        width: labelMetrics.advanceWidth
        text: root.label
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignRight
        color: root.muted ? "#f38ba8" : "#cdd6f4"
    }
    TextMetrics {
        id: labelMetrics
        text: root.label.endsWith("K") ? "2700K" : "100%"
        font: levelLabel.font
    }
}
