pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property int variant: 0
    property real value: 0
    property bool muted: false
    property real progress: muted ? 0 : Math.max(0, Math.min(1, value))
    readonly property string number: Math.round(value * 100).toString().padStart(2, "0")
    implicitWidth: [212, 190, 204, 212, 212, 132][variant]
    implicitHeight: [78, 78, 78, 82, 82, 104][variant]
    width: implicitWidth
    height: implicitHeight

    Behavior on progress { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    onProgressChanged: { syncGraph.requestPaint(); }
    onMutedChanged: { syncGraph.requestPaint(); }

    EvaVolume {
        visible: root.variant === 0
        anchors.fill: parent
        value: root.value
        muted: root.muted
    }

    Rectangle {
        visible: root.variant === 1
        anchors.fill: parent
        color: "#f5150b0c"
        border.color: "#d84a3c"
        Rectangle { x: 0; y: 0; width: 44; height: parent.height; color: "#bd342a" }
        Text {
            x: 6; y: 8
            text: "EVA"
            color: "#ffd9b0"
            font.family: "JetBrains Mono"; font.pixelSize: 10; font.weight: Font.Bold
        }
        Text {
            x: 4; y: 24
            text: "02"
            color: "#fff0d6"
            font.family: "JetBrains Mono"; font.pixelSize: 26; font.weight: Font.Bold
        }
        Row {
            x: 6; y: 64; spacing: 3
            Repeater { model: 5; Rectangle { width: 3; height: 7; rotation: 25; color: "#ffbd56" } }
        }
        Text {
            x: 54; y: 7
            text: root.muted ? "SIGNAL CUT" : "PRODUCTION MODEL"
            color: "#ff9e4d"
            font.family: "JetBrains Mono"; font.pixelSize: 7; font.letterSpacing: 0.4
        }
        Text {
            x: 54; y: 21
            text: root.number
            color: root.muted ? "#ff644f" : "#fff0d6"
            font.family: "JetBrains Mono"; font.pixelSize: 30; font.weight: Font.Bold
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 10; y: 37
            text: "%"
            color: "#ff9e4d"; font.pixelSize: 10
        }
        Row {
            x: 55; y: 63; spacing: 2
            Repeater {
                model: 18
                Rectangle {
                    required property int index
                    width: 5; height: 6
                    color: index < root.progress * 18 ? "#ff5f43" : "#3b1c1c"
                }
            }
        }
    }

    Rectangle {
        visible: root.variant === 2
        anchors.fill: parent
        color: "#f50c0c0b"
        border.color: "#ff9e32"
        Row {
            x: 1; y: 1; height: 8; spacing: 5
            clip: true; width: parent.width - 2
            Repeater { model: 24; Rectangle { width: 5; height: 12; rotation: 35; color: "#ff9e32" } }
        }
        Text {
            x: 10; y: 18
            text: "NERV"
            color: "#ff5d39"
            font.family: "JetBrains Mono"; font.pixelSize: 22; font.weight: Font.Bold; font.letterSpacing: 2
        }
        Text {
            x: 11; y: 48
            text: root.muted ? "AUDIO INHIBITED" : "AUDIO CONTROL"
            color: "#ff9e32"
            font.family: "JetBrains Mono"; font.pixelSize: 7; font.letterSpacing: 0.5
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 12; y: 19
            text: root.number
            color: "#ffb648"
            font.family: "JetBrains Mono"; font.pixelSize: 31; font.weight: Font.Bold
        }
        Rectangle { x: 11; y: 66; width: parent.width - 22; height: 3; color: "#3c2917" }
        Rectangle { x: 11; y: 66; width: (parent.width - 22) * root.progress; height: 3; color: "#ff9e32" }
    }

    Rectangle {
        visible: root.variant === 3
        anchors.fill: parent
        color: "#f50a1718"
        border.color: "#4d8d80"
        Text {
            x: 9; y: 6
            text: "MAGI / AUDIO CONSENSUS"
            color: "#80c9ac"
            font.family: "JetBrains Mono"; font.pixelSize: 7; font.letterSpacing: 0.7
        }
        Row {
            x: 9; y: 22; spacing: 4
            Repeater {
                model: ["CASPER", "MELCHIOR", "BALTHASAR"]
                Rectangle {
                    required property int index
                    required property string modelData
                    width: 61; height: 49
                    color: "#122c2a"
                    border.color: root.muted ? "#b95744" : "#478d77"
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 4
                        text: parent.modelData
                        color: "#7eae9e"
                        font.family: "JetBrains Mono"; font.pixelSize: 6
                    }
                    Text {
                        anchors.centerIn: parent; anchors.verticalCenterOffset: 3
                        text: root.number
                        color: root.muted ? "#ff775c" : "#a7f3bd"
                        font.family: "JetBrains Mono"; font.pixelSize: 17
                    }
                    Rectangle {
                        x: 5; y: 41; width: (parent.width - 10) * root.progress; height: 2
                        color: "#99e6b6"
                    }
                }
            }
        }
    }

    Rectangle {
        visible: root.variant === 4
        anchors.fill: parent
        color: "#f50b1117"
        border.color: "#467d75"
        Text {
            x: 9; y: 5
            text: "SYNCHRONIZATION / AUDIO"
            color: "#ff9750"
            font.family: "JetBrains Mono"; font.pixelSize: 7; font.letterSpacing: 0.7
        }
        Canvas {
            id: syncGraph
            x: 9; y: 21; width: 122; height: 48
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 0.5;
                ctx.strokeStyle = "#284036";
                for (let x = 0; x <= width; x += 12) {
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                }
                for (let y = 0; y <= height; y += 12) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                }
                ctx.strokeStyle = root.muted ? "#ff775c" : "#92f0a1";
                ctx.lineWidth = 1.4;
                ctx.beginPath();
                for (let x = 0; x <= width; x++) {
                    const y = height / 2 + Math.sin(x * 0.13) * Math.cos(x * 0.045) * 20 * root.progress;
                    if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 10; y: 26
            text: root.number
            color: "#a0f4bc"
            font.family: "JetBrains Mono"; font.pixelSize: 29
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 10; y: 60
            text: root.muted ? "NO LINK" : "SYNC %"
            color: "#ff9750"
            font.family: "JetBrains Mono"; font.pixelSize: 7
        }
    }

    EvaAwakening {
        visible: root.variant === 5
        anchors.fill: parent
        value: root.value
        muted: root.muted
    }
}
