pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property real value: 0
    property bool muted: false
    property real opening: muted ? 0 : Math.max(0, Math.min(1, value))
    property real impulse: 0
    readonly property color energy: muted ? "#ff684d" : "#bdff50"
    implicitWidth: 132
    implicitHeight: 104

    Behavior on opening {
        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
    }
    onOpeningChanged: mechanism.requestPaint()
    onImpulseChanged: mechanism.requestPaint()
    onMutedChanged: { mechanism.requestPaint(); pulse.restart(); }
    onValueChanged: pulse.restart()

    SequentialAnimation {
        id: pulse
        NumberAnimation { target: root; property: "impulse"; from: 0; to: 1; duration: 70 }
        NumberAnimation { target: root; property: "impulse"; to: 0; duration: 420; easing.type: Easing.OutCubic }
    }

    Canvas {
        id: mechanism
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width < 30 || height < 30)
                return;
            const cx = width / 2;
            const cy = 48;
            const spread = root.opening * 12;
            const energy = root.energy.toString();
            function polygon(points, fill, stroke) {
                ctx.beginPath();
                ctx.moveTo(points[0][0], points[0][1]);
                for (let i = 1; i < points.length; i++)
                    ctx.lineTo(points[i][0], points[i][1]);
                ctx.closePath();
                if (fill) { ctx.fillStyle = fill; ctx.fill(); }
                if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
            }
            polygon([[cx - 48, cy - 19], [cx - 28, cy - 39], [cx + 28, cy - 39], [cx + 48, cy - 19], [cx + 48, cy + 19], [cx + 28, cy + 39], [cx - 28, cy + 39], [cx - 48, cy + 19]], "#ed100e19", "#493359");

            for (let layer = 3; layer > 0; layer--) {
                const rx = 21 + layer * 3 + root.impulse * layer;
                const ry = 25 + layer * 3;
                polygon([[cx, cy - ry], [cx + rx, cy], [cx, cy + ry], [cx - rx, cy]], root.muted ? "#08ff684d" : "#0cbdff50", "");
            }
            const core = ctx.createLinearGradient(cx, cy - 24, cx, cy + 24);
            core.addColorStop(0, root.muted ? "#ff684d" : "#e2ffb0");
            core.addColorStop(0.5, energy);
            core.addColorStop(1, root.muted ? "#57251f" : "#3e751c");
            polygon([[cx, cy - 29], [cx + 22, cy], [cx, cy + 29], [cx - 22, cy]], core, energy);
            polygon([[cx, cy - 23], [cx + 17, cy], [cx, cy + 23], [cx - 17, cy]], "#f0141b12", "");

            const top = cy - spread;
            const bottom = cy + spread;
            const armor = ctx.createLinearGradient(0, top - 32, 0, bottom + 32);
            armor.addColorStop(0, "#9d73d4");
            armor.addColorStop(0.45, "#573579");
            armor.addColorStop(1, "#2a1d3c");
            polygon([[cx - 43, top - 18], [cx - 26, top - 34], [cx + 26, top - 34], [cx + 43, top - 18], [cx + 23, top - 5], [cx - 23, top - 5]], armor, "#b590df");
            polygon([[cx - 43, bottom + 18], [cx - 24, bottom + 6], [cx + 24, bottom + 6], [cx + 43, bottom + 18], [cx + 26, bottom + 33], [cx - 26, bottom + 33]], armor, "#735092");

            ctx.lineWidth = 2;
            ctx.strokeStyle = energy;
            ctx.beginPath(); ctx.moveTo(cx - 26, top - 15); ctx.lineTo(cx - 13, top - 9); ctx.stroke();
            ctx.beginPath(); ctx.moveTo(cx + 26, top - 15); ctx.lineTo(cx + 13, top - 9); ctx.stroke();
            ctx.strokeStyle = "#ff9852";
            ctx.beginPath(); ctx.moveTo(cx - 12, bottom + 17); ctx.lineTo(cx + 12, bottom + 17); ctx.stroke();

            for (let side = -1; side <= 1; side += 2) {
                const x = cx + side * (43 + spread * 0.4);
                polygon([[x, cy - 14], [x + side * 7, cy - 6], [x + side * 7, cy + 6], [x, cy + 14]], "#553579", "#9364b9");
                ctx.fillStyle = energy;
                ctx.fillRect(x - 1, cy - 5, 2, 10);
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 36
        text: root.muted ? "×" : Math.round(root.value * 100)
        color: root.muted ? "#ffb5a4" : "#efffd7"
        font.family: "JetBrains Mono"
        font.pixelSize: 17
        font.weight: Font.Bold
        style: Text.Outline
        styleColor: "#14200d"
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 92
        text: root.muted ? "RESTRAINT LOCKED" : "AWAKENING / " + Math.round(root.value * 100) + "%"
        color: root.muted ? "#ff9852" : "#bc98e0"
        font.family: "JetBrains Mono"
        font.pixelSize: 6
        font.letterSpacing: 1
    }
}
