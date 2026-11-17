pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property int variant: 0
    property string heading: "Audio"
    property string title: "Enjoy the Silence"
    property string symbol: "󰎇"
    property real level: -1
    property bool muted: false
    property real maximumWidth: Number.MAX_VALUE
    property int fontSize: 11
    property real progress: muted ? 0 : Math.max(0, Math.min(1, level))
    readonly property bool meter: level >= 0
    readonly property var palettes: [
        {accent: "#b6ad83", secondary: "#839da2", bg: "#f516181b", text: "#d4d5d8"},
        {accent: "#b49aae", secondary: "#8aabb2", bg: "#f518171d", text: "#d4d5d8"},
        {accent: "#8ea898", secondary: "#698377", bg: "#f5141917", text: "#d4d5d8"},
        {accent: "#b08f8f", secondary: "#8d919a", bg: "#f5191619", text: "#d4d5d8"},
        {accent: "#8ba6ad", secondary: "#677f8b", bg: "#f5141b20", text: "#d4d5d8"},
        {accent: "#a99aad", secondary: "#8d91ad", bg: "#f5191720", text: "#d4d5d8"},
        {accent: "#b29b83", secondary: "#7e8790", bg: "#f51b1c1f", text: "#d4d5d8"},
        {accent: "#b1bec5", secondary: "#80949c", bg: "#f5161b20", text: "#d4d5d8"},
        {accent: "#a2ad89", secondary: "#7a9687", bg: "#f5181c17", text: "#d4d5d8"},
        {accent: "#9b93b0", secondary: "#a18c93", bg: "#f516161c", text: "#d4d5d8"}
    ]
    readonly property var tones: palettes[variant]
    implicitWidth: meter ? 164 : Math.max(100, Math.min(maximumWidth, Math.ceil(metrics.advanceWidth) + 44))
    implicitHeight: Math.max(34, Math.ceil(layout.implicitHeight) + 18)

    Behavior on progress { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    onVariantChanged: frame.requestPaint()
    TextMetrics { id: metrics; text: root.title; font: label.font }
    Text {
        id: layout
        visible: false
        width: root.implicitWidth - 44
        text: root.meter ? "" : root.title
        textFormat: Text.PlainText
        font: label.font
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    Canvas {
        id: frame
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width < 20 || height < 20)
                return;
            const a = "#88" + root.tones.accent.slice(1);
            const b = "#66" + root.tones.secondary.slice(1);
            const w = width - 1;
            const h = height - 1;
            function polygon(points, fill, stroke) {
                ctx.beginPath(); ctx.moveTo(points[0][0], points[0][1]);
                for (let i = 1; i < points.length; i++) ctx.lineTo(points[i][0], points[i][1]);
                ctx.closePath();
                ctx.fillStyle = fill; ctx.fill();
                if (stroke) { ctx.lineWidth = 0.7; ctx.strokeStyle = stroke; ctx.stroke(); }
            }
            function line(x1, y1, x2, y2, color, thickness) {
                ctx.strokeStyle = color; ctx.lineWidth = Math.min(1, thickness);
                ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
            }
            if (root.variant === 0) {
                polygon([[1, 1], [w, 1], [w, h - 10], [w - 10, h], [1, h]], root.tones.bg, a);
                ctx.fillStyle = a; ctx.fillRect(1, 1, 18, 1);
            } else if (root.variant === 1) {
                polygon([[3, 3], [w - 2, 3], [w - 2, h - 3], [3, h - 3]], root.tones.bg, a);
                line(1, 10, 1, h - 1, b, 1);
                line(1, h - 1, w - 10, h - 1, b, 1);
                line(w, 1, w, h - 10, b, 1);
            } else if (root.variant === 2) {
                polygon([[1, 1], [w, 1], [w, h], [1, h]], root.tones.bg, "");
                for (const side of [0, 1]) {
                    const x = side ? w : 1;
                    const direction = side ? -1 : 1;
                    line(x, 1, x + direction * 12, 1, a, 1);
                    line(x, 1, x, 12, a, 1);
                    line(x, h, x + direction * 12, h, a, 1);
                    line(x, h, x, h - 12, a, 1);
                }
            } else if (root.variant === 3) {
                polygon([[1, 1], [w - 8, 1], [w, 9], [w, h], [10, h], [1, h - 9]], root.tones.bg, "#44363a");
                ctx.fillStyle = a; ctx.fillRect(1, 9, 1, h - 18);
                line(w - 31, 1, w - 10, 1, a, 2);
                line(14, h - 1, 40, h - 1, a, 2);
            } else if (root.variant === 4) {
                polygon([[10, 1], [w - 10, 1], [w, h / 2], [w - 10, h], [10, h], [1, h / 2]], root.tones.bg, a);
                line(14, h - 3, w - 14, h - 3, b, 1);
            } else if (root.variant === 5) {
                const fill = ctx.createLinearGradient(0, 0, width, height);
                fill.addColorStop(0, "#f5191820"); fill.addColorStop(1, "#f5141a20");
                polygon([[1, 1], [w - 10, 1], [w, 11], [w - 10, h], [1, h]], fill, a);
                for (let i = 0; i < 1; i++) line(8, h - 3 - i * 3, 36 + i * 5, h - 3 - i * 3, b, 0.6);
            } else if (root.variant === 6) {
                polygon([[1, 1], [w, 1], [w, h], [1, h]], root.tones.bg, "#3b4148");
                line(1, 1, 31, 1, a, 3); line(w - 31, h, w, h, a, 3);
                for (const x of [4, w - 5]) for (const y of [4, h - 5]) {
                    ctx.fillStyle = b; ctx.fillRect(x, y, 2, 2);
                }
            } else if (root.variant === 7) {
                polygon([[8, 1], [w, 1], [w, h - 7], [w - 7, h], [1, h], [1, 8]], root.tones.bg, "#3c4a51");
                line(12, 1, 40, 1, a, 1);
                line(w - 8, 8, w - 8, 14, a, 1); line(w - 11, 11, w - 5, 11, a, 1);
            } else if (root.variant === 8) {
                polygon([[9, 1], [w, 1], [w, h], [1, h], [1, 9]], root.tones.bg, "#3c4934");
                ctx.fillStyle = a; ctx.fillRect(1, 12, 2, h - 13);
                line(w - 48, h - 7, w - 30, h - 7, b, 1);
                line(w - 30, h - 7, w - 24, h - 13, b, 1);
                line(w - 24, h - 13, w - 10, h - 13, b, 1);
                ctx.fillStyle = a; ctx.fillRect(w - 12, h - 15, 3, 3);
            } else {
                polygon([[7, 1], [w - 7, 1], [w, 8], [w, h - 7], [w - 7, h], [7, h], [1, h - 7], [1, 8]], root.tones.bg, "#403a4b");
                ctx.fillStyle = b; ctx.fillRect(9, 8, 3, 3);
                for (let i = 0; i < 3; i++) line(w - 20 + i * 4, h - 8, w - 18 + i * 4, h - 12, a, 1);
            }
        }
    }

    Text {
        visible: false
        x: root.variant === 9 ? 17 : 9; y: 6
        text: root.heading.toUpperCase() + (root.variant === 2 ? "_" : " // LINK")
        color: root.tones.secondary
        font.family: "JetBrains Mono"; font.pixelSize: 7; font.letterSpacing: 0.8
    }
    Text {
        x: 10; y: 10
        text: root.meter ? root.muted ? "󰖁" : "󰕾" : root.symbol
        color: root.tones.accent
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
    }
    Text {
        id: label
        visible: !root.meter
        x: 32; y: 9; width: root.width - 44; height: layout.implicitHeight
        text: root.title
        textFormat: Text.PlainText
        font.family: "JetBrains Mono"; font.pixelSize: root.fontSize; font.weight: Font.Medium
        color: root.tones.text
        elide: Text.ElideNone
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }
    Item {
        visible: root.meter
        x: 32; y: 14; width: root.width - 83; height: 6
        Rectangle { anchors.fill: parent; color: Qt.rgba(0.5, 0.5, 0.6, 0.07) }
        Rectangle {
            visible: root.variant === 1 || root.variant === 4 || root.variant === 7
            width: parent.width * root.progress; height: 1
            anchors.verticalCenter: parent.verticalCenter
            color: root.tones.accent
        }
        Row {
            visible: root.variant !== 1 && root.variant !== 4 && root.variant !== 7
            spacing: 2
            Repeater {
                model: 16
                Rectangle {
                    required property int index
                    width: 3; height: root.variant === 5 ? 2 + index * 0.2 : 5
                    color: index < root.progress * 16 ? root.tones.accent : "transparent"
                }
            }
        }
    }
    Text {
        visible: root.meter
        anchors.right: parent.right; anchors.rightMargin: 9; y: 9
        text: Math.round(root.level * 100) + "%"
        font.family: "JetBrains Mono"; font.pixelSize: 12; font.weight: Font.Medium
        color: root.tones.text
    }
}
