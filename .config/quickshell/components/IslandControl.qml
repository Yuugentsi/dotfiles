pragma ComponentBehavior: Bound
import "../controls/PanelTheme.js" as Theme
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls

Slider {
    id: control
    property string label: ""
    property string glyph: ""
    property color accent: Theme.accent
    property real minimum: 0
    property real maximum: 100
    property real wheelStep: 5
    property string unit: "%"
    implicitHeight: 58
    from: minimum
    to: maximum
    stepSize: 1
    live: true
    leftPadding: 10
    rightPadding: 10
    topPadding: 38
    bottomPadding: 12
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
            if (mouse.y >= 32)
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
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1
                strokeColor: inputArea.containsMouse || inputArea.pressed ? Qt.rgba(control.accent.r, control.accent.g, control.accent.b, 0.3) : "#60313244"
                fillColor: inputArea.containsMouse || inputArea.pressed ? "#60313244" : "#20181825"
                startX: 7
                startY: 1
                PathLine { x: control.width - 1; y: 1 }
                PathLine { x: control.width - 1; y: control.height - 7 }
                PathLine { x: control.width - 7; y: control.height - 1 }
                PathLine { x: 1; y: control.height - 1 }
                PathLine { x: 1; y: 7 }
                PathLine { x: 7; y: 1 }
            }
        }
        Rectangle {
            x: 10
            y: 0
            width: 14
            height: 1
            color: control.accent
            opacity: inputArea.containsMouse || inputArea.pressed ? 0.6 : 0.2
        }
        Text {
            x: control.leftPadding
            y: 11
            text: control.glyph
            color: inputArea.containsMouse || inputArea.pressed ? control.accent : "#a6adc8"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            x: 29
            y: 12
            width: Math.max(0, parent.width - x - controlValue.implicitWidth - 16)
            text: control.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: "#a6adc8"
            font.family: "JetBrains Mono"
            font.pixelSize: 9
        }
        Text {
            id: controlValue
            anchors.right: parent.right
            anchors.rightMargin: control.rightPadding
            y: 10
            text: Math.round(control.value) + control.unit
            color: inputArea.containsMouse || inputArea.pressed ? "#cdd6f4" : "#bac2de"
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            font.weight: Font.Medium
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Item {
            id: controlTrack
            x: control.leftPadding
            y: 40
            width: control.availableWidth
            height: 4
            Row {
                spacing: 2
                Repeater {
                    model: 16
                    Rectangle {
                        id: trackSegment
                        required property int index
                        width: Math.max(1, (controlTrack.width - 30) / 16)
                        height: 4
                        color: "#313244"
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, control.visualPosition * 16 - trackSegment.index))
                            height: parent.height
                            color: control.accent
                            opacity: inputArea.containsMouse || inputArea.pressed ? 0.85 : 0.55
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }
                }
            }
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: 38
        width: 3
        height: 8
        radius: 1
        color: "#cdd6f4"
        opacity: inputArea.containsMouse || inputArea.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
