import QtQuick
import QtQuick.Controls

Slider {
    id: control
    property string label: ""
    property string glyph: ""
    property color accent: "#c3b7ff"
    property real minimum: 0
    property real maximum: 100
    property real wheelStep: 5
    property string unit: "%"
    implicitHeight: 44
    from: minimum
    to: maximum
    stepSize: 1
    live: true
    leftPadding: 8
    rightPadding: 8
    topPadding: 24
    bottomPadding: 10
    Accessible.name: label
    opacity: enabled ? 1 : 0.35
    function applyValue(next) {
        value = Math.round(Math.max(from, Math.min(to, next)));
        moved();
    }
    MouseArea {
        id: inputArea
        anchors.fill: parent
        z: 10
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeHorCursor
        property real startX: 0
        property real startY: 0
        property real startValue: 0
        onPressed: function (mouse) {
            startX = mouse.x;
            startY = mouse.y;
            if (mouse.y >= 24 && mouse.y <= 42)
                control.applyValue(control.from + (mouse.x - control.leftPadding) / control.availableWidth * (control.to - control.from));
            startValue = control.value;
        }
        onPositionChanged: function (mouse) {
            if (!pressed)
                return;
            const horizontal = mouse.x - startX;
            const vertical = startY - mouse.y;
            const delta = Math.abs(horizontal) >= Math.abs(vertical) ? horizontal : vertical;
            control.applyValue(startValue + delta / control.availableWidth * (control.to - control.from));
        }
        onWheel: function (wheel) {
            const delta = wheel.angleDelta.y || wheel.pixelDelta.y || wheel.angleDelta.x || wheel.pixelDelta.x;
            if (delta !== 0) {
                control.applyValue(control.value + (delta > 0 ? control.wheelStep : -control.wheelStep));
                wheel.accepted = true;
            }
        }
    }
    ToolTip.visible: inputArea.containsMouse && !inputArea.pressed
    ToolTip.delay: 700
    ToolTip.text: label
    background: Item {
        Text {
            x: control.leftPadding
            y: 4
            text: control.glyph
            color: inputArea.containsMouse ? control.accent : "#a69ab6"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: control.rightPadding
            y: 4
            text: Math.round(control.value) + control.unit
            color: inputArea.containsMouse ? "#eee6f7" : "#a69ab6"
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Rectangle {
            x: control.leftPadding
            y: 30
            width: control.availableWidth
            height: 3
            radius: 2
            color: "#3b3345"
            Rectangle {
                width: parent.width * control.visualPosition
                height: parent.height
                radius: 2
                color: control.accent
                opacity: inputArea.containsMouse || inputArea.pressed ? 1 : 0.65
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: 28
        width: 7
        height: 7
        radius: 4
        color: "#eee6f7"
        opacity: inputArea.containsMouse || inputArea.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
