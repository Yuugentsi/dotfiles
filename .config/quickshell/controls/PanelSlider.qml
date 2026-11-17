import "PanelTheme.js" as Theme
import QtQuick
import QtQuick.Controls
Item {
    id: root
    property var bar: null
    implicitHeight: 24
    property real step: 0.05
    signal moved(real value)
    signal rightClicked()
    property real minimum: 0
    property real maximum: 100
    property real value: 0
    property real trackHeight: 5
    property real knobSize: 14
    property color fillColor: Theme.accent
    property color knobColor: Theme.foreground
    property color trackColor: Theme.track
    readonly property bool dragging: slider.pressed
    readonly property real liveValue: slider.value
    signal released(real value)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        z: 2
        onClicked: root.rightClicked()
    }
    Slider {
        id: slider
        anchors.fill: parent
        from: root.minimum
        to: root.maximum
        value: root.value
        stepSize: root.step
        onMoved: root.moved(value)
        onPressedChanged: if (!pressed) root.released(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth; height: root.trackHeight; radius: height / 2; color: root.trackColor
            Rectangle {
                width: slider.visualPosition * parent.width; height: parent.height; radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.fillColor === Theme.accent ? "#d69aac" : root.fillColor }
                    GradientStop { position: 1; color: root.fillColor }
                }
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: root.knobSize; height: width; radius: width / 2; color: root.knobColor
            border.width: 3
            border.color: root.fillColor
            scale: slider.pressed ? 1.2 : slider.hovered ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 2
                height: width
                radius: width / 2
                color: Qt.alpha(root.fillColor, 0.18)
                visible: slider.pressed
                z: -1
            }
        }
    }
}
