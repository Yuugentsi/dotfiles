import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

Rectangle {
    id: btn
    property string icon: ""
    property string label: ""
    property bool primary: false
    property bool active: false
    property color tint: Theme.accent
    property bool spinning: false
    readonly property bool hovered: btnMouse.containsMouse
    readonly property color ink: primary ? "#221c21" : (active || hovered) ? tint : Theme.foreground
    signal clicked
    implicitHeight: 32
    implicitWidth: label === "" ? implicitHeight : btnRow.implicitWidth + 24
    radius: height / 2
    gradient: primary ? primaryGradient : null
    color: primary ? (hovered ? Theme.accentAlt : tint) : active ? Qt.alpha(tint, hovered ? 0.28 : 0.18) : hovered ? Qt.alpha(tint, 0.14) : Qt.alpha(Theme.foreground, 0.05)
    border.width: 1
    border.color: primary ? Qt.alpha(Theme.foreground, 0.25) : (active || hovered) ? Qt.alpha(tint, 0.45) : Qt.alpha(Theme.foreground, 0.08)
    scale: btnMouse.pressed ? 0.94 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Gradient {
        id: primaryGradient
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: btn.tint }
        GradientStop { position: 1; color: btn.tint === Theme.accent ? (btn.hovered ? "#d69aac" : Theme.accentAlt) : btn.tint }
    }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    Row {
        id: btnRow
        anchors.centerIn: parent
        spacing: 6
        Text {
            id: btnIcon
            visible: btn.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.icon
            font.family: Theme.iconFont
            font.pixelSize: 15
            color: btn.ink
            RotationAnimation on rotation {
                running: btn.spinning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onStopped: btnIcon.rotation = 0
            }
        }
        Text {
            visible: btn.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.label
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: btn.ink
        }
    }

    MouseArea {
        id: btnMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
