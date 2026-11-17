pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property real value: 0
    property bool muted: false
    property real progress: muted ? 0 : Math.max(0, Math.min(1, value))
    readonly property color signalColor: muted ? "#ff6546" : "#b4ff39"
    implicitWidth: 212
    implicitHeight: 78

    Behavior on progress {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    Canvas {
        id: frame
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width < 20 || height < 20)
                return;
            ctx.beginPath();
            ctx.moveTo(10, 1);
            ctx.lineTo(width - 1, 1);
            ctx.lineTo(width - 1, height - 12);
            ctx.lineTo(width - 12, height - 1);
            ctx.lineTo(1, height - 1);
            ctx.lineTo(1, 10);
            ctx.closePath();
            ctx.fillStyle = "#f70d0d12";
            ctx.fill();
            ctx.lineWidth = 1;
            ctx.strokeStyle = "#9271c7";
            ctx.stroke();
        }
    }

    Rectangle { x: 1; y: 15; width: 3; height: 45; color: "#8d5bd6" }
    Rectangle { x: 12; y: 21; width: 116; height: 1; color: "#40314f" }
    Rectangle { x: 137; y: 27; width: 1; height: 35; color: "#40314f" }
    Rectangle { x: 160; y: 1; width: 37; height: 2; color: root.signalColor }

    Text {
        x: 12
        y: 7
        text: "EVA-01"
        color: "#bc98f0"
        font.family: "JetBrains Mono"
        font.pixelSize: 10
        font.weight: Font.Bold
        font.letterSpacing: 1.5
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 8
        text: "AUDIO / LINK"
        color: "#ff9c42"
        font.family: "JetBrains Mono"
        font.pixelSize: 7
        font.letterSpacing: 0.7
    }
    Text {
        x: 12
        y: 28
        text: root.muted ? "SIGNAL LOST" : "OUTPUT LEVEL"
        color: "#ff9c42"
        font.family: "JetBrains Mono"
        font.pixelSize: 8
        font.letterSpacing: 1
    }

    Row {
        x: 12
        y: 43
        spacing: 2
        Repeater {
            model: 16
            Rectangle {
                required property int index
                width: 5.3
                height: 13
                color: index < root.progress * 16 ? index >= 13 ? "#ff9c42" : root.signalColor : "#26242d"
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 13
        y: 22
        text: Math.round(root.value * 100).toString().padStart(2, "0")
        color: root.signalColor
        font.family: "JetBrains Mono"
        font.pixelSize: 29
        font.weight: Font.Bold
        font.letterSpacing: -1.5
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 54
        text: "%"
        color: "#ff9c42"
        font.family: "JetBrains Mono"
        font.pixelSize: 8
    }

    Text {
        x: 12
        y: 65
        text: root.muted ? "STATUS: SILENT" : "STATUS: NORMAL"
        color: root.signalColor
        font.family: "JetBrains Mono"
        font.pixelSize: 6
        font.letterSpacing: 1.2
    }
    Row {
        x: 153
        y: 67
        spacing: 3
        Repeater {
            model: 6
            Rectangle { width: 3; height: 6; rotation: 30; color: "#8d5bd6" }
        }
    }
}
