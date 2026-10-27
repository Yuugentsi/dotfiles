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
    property real trackHeight: 3
    property real knobSize: 10
    property color fillColor: "#c3b7ff"
    property color knobColor: "white"
    property color trackColor: "#3e3949"
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
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: parent.radius; color: root.fillColor }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: root.knobSize; height: width; radius: width / 2; color: root.knobColor
        }
    }
}
