pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property string title: ""
    property bool stopped: false
    property real maximumWidth: 960
    implicitWidth: Math.max(64, Math.min(maximumWidth, Math.ceil(titleMetrics.advanceWidth) + 48))
    implicitHeight: Math.max(32, Math.ceil(titleLayout.implicitHeight) + 16)

    TextMetrics {
        id: titleMetrics
        text: root.title
        font: trackTitle.font
    }

    Text {
        id: titleLayout
        visible: false
        width: root.implicitWidth - 48
        text: root.title
        textFormat: Text.PlainText
        font: trackTitle.font
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    Canvas {
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width < 20 || height < 20)
                return;
            ctx.beginPath();
            ctx.moveTo(8, 0.5);
            ctx.lineTo(width - 0.5, 0.5);
            ctx.lineTo(width - 0.5, height - 9);
            ctx.lineTo(width - 9, height - 0.5);
            ctx.lineTo(0.5, height - 0.5);
            ctx.lineTo(0.5, 8);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, width, height);
            fill.addColorStop(0, "#f523130e");
            fill.addColorStop(1, "#f5110c0b");
            ctx.fillStyle = fill;
            ctx.fill();
            ctx.lineWidth = 1;
            ctx.strokeStyle = "#ad5830";
            ctx.stroke();
        }
    }

    Rectangle { x: 1; y: 9; width: 2; height: parent.height - 18; color: "#f05a3e" }
    Rectangle { x: 13; y: 0; width: 18; height: 2; color: "#ffad45" }
    Rectangle {
        x: 9; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20
        color: "#3a2015"
        border.color: "#6c3521"
        Text {
            anchors.centerIn: parent
            text: root.stopped ? "󰎊" : "󰎇"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: root.stopped ? "#f05a3e" : "#ffad45"
        }
    }
    Text {
        id: trackTitle
        x: 38
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 10
        height: titleLayout.implicitHeight
        text: root.title
        textFormat: Text.PlainText
        color: "#ffe5c2"
        font.family: "JetBrains Mono"
        font.pixelSize: 13
        font.weight: Font.Medium
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }
}
