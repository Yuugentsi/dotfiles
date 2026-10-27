import QtQuick
import QtQuick.Controls

Dial {
    id: islandDialRoot
    property string label: ""
    property real minimum: 10
    implicitHeight: width
    from: minimum
    to: 100
    stepSize: 5
    inputMode: Dial.Vertical
    live: true
    wrap: false
    Accessible.name: label
    opacity: enabled ? 1 : 0.35
    background: Canvas {
        id: islandDialCanvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            const radius = Math.min(width, height) / 2 - 8;
            const start = 130 * Math.PI / 180;
            const span = 280 * Math.PI / 180;
            context.lineWidth = 4;
            context.lineCap = "round";
            context.strokeStyle = "#493053";
            context.beginPath();
            context.arc(width / 2, height / 2, radius, start, start + span);
            context.stroke();
            const gradient = context.createLinearGradient(0, height, width, 0);
            gradient.addColorStop(0, "#ff9c66");
            gradient.addColorStop(0.5, "#cf8dbc");
            gradient.addColorStop(1, "#c3a0ff");
            context.strokeStyle = gradient;
            context.beginPath();
            context.arc(width / 2, height / 2, radius, start, start + span * islandDialRoot.position);
            context.stroke();
        }
        Connections {
            target: islandDialRoot
            function onValueChanged() {
                islandDialCanvas.requestPaint();
            }
        }
    }
    handle: Rectangle {
        x: islandDialRoot.width / 2 + (Math.min(islandDialRoot.width, islandDialRoot.height) / 2 - 8) * Math.cos((islandDialRoot.angle - 90) * Math.PI / 180) - width / 2
        y: islandDialRoot.height / 2 + (Math.min(islandDialRoot.width, islandDialRoot.height) / 2 - 8) * Math.sin((islandDialRoot.angle - 90) * Math.PI / 180) - height / 2
        width: 10
        height: 10
        radius: 5
        color: "#f5eaff"
        border.width: 2
        border.color: "#9b72bc"
    }
    Column {
        anchors.centerIn: parent
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(islandDialRoot.value) + "%"
            color: "#f5eaff"
            font.pixelSize: 17
            font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: islandDialRoot.label
            color: "#aa91bd"
            font.pixelSize: 8
        }
    }
}
