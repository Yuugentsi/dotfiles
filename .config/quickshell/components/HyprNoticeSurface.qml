pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property bool hud: false
    property color accentColor: "#a99aad"
    property string title: "System"
    default property alias contentData: content.data

    property Item frame: Canvas {
        parent: root
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
            ctx.moveTo(1, 1);
            ctx.lineTo(width - 11, 1);
            ctx.lineTo(width - 1, 11);
            ctx.lineTo(width - 11, height - 1);
            ctx.lineTo(1, height - 1);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, width, height);
            fill.addColorStop(0, "#f5191820");
            fill.addColorStop(1, "#f5141a20");
            ctx.fillStyle = fill;
            ctx.fill();
            ctx.strokeStyle = "#88a99aad";
            ctx.lineWidth = 0.7;
            ctx.stroke();
            ctx.strokeStyle = "#668d91ad";
            ctx.beginPath();
            ctx.moveTo(8, height - 4);
            ctx.lineTo(33, height - 4);
            ctx.stroke();
        }
    }

    property Item caption: Text {
        parent: root
        x: 12; y: 6; width: root.width - 32
        text: root.title
        textFormat: Text.PlainText
        color: "#8d91ad"
        font.family: "JetBrains Mono"
        font.pixelSize: 9
        elide: Text.ElideRight
    }

    property Item contentItem: Item {
        id: content
        parent: root
        x: 0; y: 22
        width: root.width
        height: Math.max(0, root.height - 22)
    }
}
