pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property real value: 0
    property bool muted: false
    property real progress: muted ? 0 : Math.max(0, Math.min(1, value))
    readonly property color accent: muted ? "#f38ba8" : "#cba6f7"
    readonly property string symbol: muted ? "󰖁" : value < 0.4 ? "󰖀" : "󰕾"
    implicitWidth: 64
    implicitHeight: 64

    Behavior on progress {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    onProgressChanged: ring.requestPaint()
    onAccentChanged: ring.requestPaint()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#f52c2339" }
            GradientStop { position: 0.55; color: "#f5211c2d" }
            GradientStop { position: 1; color: "#f5171522" }
        }
        border.width: 1
        border.color: "#6657476d"
    }

    Canvas {
        id: ring
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 11 || height <= 11)
                return;
            const radius = Math.min(width, height) / 2 - 5.5;
            const start = Math.PI * 0.75;
            const sweep = Math.PI * 1.5;
            ctx.lineWidth = 2.5;
            ctx.lineCap = "round";
            ctx.strokeStyle = "#42374f";
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, radius, start, start + sweep);
            ctx.stroke();
            if (root.progress > 0) {
                const end = start + sweep * root.progress;
                const gradient = ctx.createLinearGradient(0, height, width, 0);
                gradient.addColorStop(0, root.accent.toString());
                gradient.addColorStop(0.5, root.muted ? "#f38ba8" : "#b4befe");
                gradient.addColorStop(1, root.muted ? "#f38ba8" : "#89dceb");
                ctx.lineWidth = 6;
                ctx.strokeStyle = root.muted ? "#18f38ba8" : "#18cba6f7";
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, radius, start, end);
                ctx.stroke();
                ctx.lineWidth = 2.5;
                ctx.strokeStyle = gradient;
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, radius, start, end);
                ctx.stroke();
                ctx.fillStyle = root.muted ? "#f38ba8" : "#e2eaff";
                ctx.beginPath();
                ctx.arc(width / 2 + Math.cos(end) * radius, height / 2 + Math.sin(end) * radius, 1.8, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        spacing: 1.5
        Text {
            id: number
            text: Math.round(root.value * 100)
            font.family: "JetBrains Mono"
            font.pixelSize: 17
            font.weight: Font.Medium
            color: root.muted ? "#b5a8c2" : "#f3eaff"
        }
        Text {
            anchors.baseline: number.baseline
            text: "%"
            font.family: "JetBrains Mono"
            font.pixelSize: 8
            color: "#a99cba"
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 46
        text: root.symbol
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: root.accent
    }
}
