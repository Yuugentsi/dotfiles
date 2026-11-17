pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property int variant: 0
    property real value: 0
    property bool muted: false
    property real progress: muted ? 0 : Math.max(0, Math.min(1, value))
    readonly property color accent: muted ? "#f38b78" : ["#a0f4bc", "#ffad45", "#b7a0f5", "#8ff0c5", "#ffd287", "#c7b5ff"][variant]
    readonly property color secondary: ["#ff9750", "#f05a3e", "#95e3d0", "#d5acff", "#f29f4e", "#91dfed"][variant]
    readonly property var titles: ["SYNCHRONIZATION / AUDIO", muted ? "SIGNAL / MUTED" : "DUAL / SYNC", "NEURAL SYNC / XY", "NEURAL LINK", "SYNC MONITOR / CRT", "RESONANCE / OUTPUT"]
    implicitWidth: [212, 150, 188, 174, 212, 208][variant]
    implicitHeight: [82, 48, 92, 58, 86, 78][variant]
    width: implicitWidth
    height: implicitHeight

    Behavior on progress { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    onProgressChanged: trace.requestPaint()
    onAccentChanged: trace.requestPaint()
    onSecondaryChanged: trace.requestPaint()

    Rectangle {
        anchors.fill: parent
        color: root.variant === 1 ? "#f5170e0b" : root.variant === 4 ? "#f511100b" : "#f50b1117"
        radius: root.variant === 3 ? 8 : root.variant === 5 ? 12 : 2
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
        Rectangle {
            x: 1; y: 1
            width: root.variant === 3 ? 2 : 28
            height: root.variant === 3 ? parent.height - 2 : 2
            color: root.secondary
        }
    }

    Text {
        x: 9; y: 6
        text: root.titles[root.variant]
        color: root.secondary
        font.family: "JetBrains Mono"
        font.pixelSize: root.variant === 3 ? 6 : 7
        font.letterSpacing: 0.6
    }

    Canvas {
        id: trace
        x: 9
        y: root.variant === 1 ? 19 : root.variant === 5 ? 35 : 22
        width: root.variant === 1 ? 87 : root.variant === 2 ? 64 : root.variant === 3 ? 102 : root.variant === 5 ? parent.width - 18 : 123
        height: root.variant === 1 ? 22 : root.variant === 2 ? 62 : root.variant === 3 ? 27 : root.variant === 5 ? 32 : 48
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width < 4 || height < 4)
                return;
            const amplitude = root.progress;
            const primary = root.accent.toString();
            const secondary = root.secondary.toString();
            const mid = height / 2;

            function grid(step) {
                ctx.lineWidth = 0.5;
                ctx.strokeStyle = root.variant === 1 ? "#42271b" : root.variant === 4 ? "#3a3021" : "#253b39";
                for (let x = 0; x <= width; x += step) {
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                }
                for (let y = 0; y <= height; y += step) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                }
            }

            function wave(color, offset, mirror, envelope) {
                ctx.beginPath();
                for (let x = 0; x <= width; x++) {
                    const window = envelope ? Math.pow(Math.sin(Math.PI * x / width), 1.5) : 1;
                    const y = mid + Math.sin(x * 0.14 + offset) * Math.cos(x * 0.035) * (height * 0.42) * amplitude * mirror * window;
                    if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.strokeStyle = color;
                ctx.lineWidth = 1.4;
                ctx.stroke();
            }

            if (root.variant === 0) {
                grid(12);
                wave(primary, 0, 1, false);
            } else if (root.variant === 1) {
                grid(8);
                wave(secondary, (1 - amplitude) * 3.4, -1, false);
                wave(primary, 0, 1, false);
            } else if (root.variant === 2) {
                grid(10);
                ctx.lineWidth = 0.7;
                ctx.strokeStyle = "#6b5485";
                ctx.beginPath(); ctx.moveTo(width / 2, 0); ctx.lineTo(width / 2, height); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(0, mid); ctx.lineTo(width, mid); ctx.stroke();
                ctx.beginPath();
                for (let i = 0; i <= 240; i++) {
                    const t = i / 240 * Math.PI * 2;
                    const x = width / 2 + Math.sin(t * 3) * (width * 0.41) * amplitude;
                    const y = mid + Math.sin(t * 2 + amplitude * 1.7) * (height * 0.41) * amplitude;
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.strokeStyle = primary;
                ctx.lineWidth = 1.2;
                ctx.stroke();
            } else if (root.variant === 3) {
                ctx.strokeStyle = "#33493f";
                ctx.lineWidth = 0.6;
                ctx.beginPath(); ctx.moveTo(0, mid); ctx.lineTo(width, mid); ctx.stroke();
                wave(primary, amplitude, 1, true);
            } else if (root.variant === 4) {
                grid(12);
                ctx.beginPath();
                const points = [[0, 0], [0.2, 0], [0.26, -0.1], [0.31, 0], [0.38, 0], [0.43, 0.28], [0.48, -1], [0.53, 0.72], [0.58, 0], [0.69, 0], [0.76, -0.3], [0.85, 0], [1, 0]];
                for (let i = 0; i < points.length; i++) {
                    const x = points[i][0] * width;
                    const y = mid + points[i][1] * height * 0.42 * amplitude;
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.strokeStyle = primary;
                ctx.lineWidth = 1.4;
                ctx.stroke();
                ctx.fillStyle = "#15ffd287";
                for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
            } else {
                const fill = ctx.createLinearGradient(0, 0, 0, height);
                fill.addColorStop(0, "#40c7b5ff");
                fill.addColorStop(0.5, "#0691dfed");
                fill.addColorStop(1, "#4091dfed");
                ctx.beginPath();
                for (let x = 0; x <= width; x++) {
                    const envelope = Math.pow(Math.sin(Math.PI * x / width), 1.5);
                    const y = mid - Math.abs(Math.sin(x * 0.14)) * envelope * height * 0.42 * amplitude;
                    if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                for (let x = width; x >= 0; x--) {
                    const envelope = Math.pow(Math.sin(Math.PI * x / width), 1.5);
                    const y = mid + Math.abs(Math.sin(x * 0.14)) * envelope * height * 0.42 * amplitude;
                    ctx.lineTo(x, y);
                }
                ctx.closePath(); ctx.fillStyle = fill; ctx.fill();
                wave(primary, 0, 1, true);
                wave(secondary, 0, -1, true);
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: root.variant === 1 ? 19 : root.variant === 2 ? 28 : root.variant === 3 ? 18 : root.variant === 5 ? 13 : 26
        text: Math.round(root.value * 100) + (root.variant === 1 || root.variant === 5 ? "%" : "")
        color: root.accent
        font.family: "JetBrains Mono"
        font.pixelSize: [29, 18, 26, 22, 27, 20][root.variant]
        font.weight: Font.Medium
    }
    Text {
        visible: root.variant !== 1 && root.variant !== 5
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: root.variant === 2 ? 64 : root.variant === 3 ? 43 : 62
        text: root.muted ? "NO LINK" : root.variant === 2 ? "COHERENCE %" : root.variant === 3 ? "%" : "SYNC %"
        color: root.secondary
        font.family: "JetBrains Mono"
        font.pixelSize: root.variant === 3 ? 6 : 7
    }
}
