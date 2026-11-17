import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import "../../controls/PanelTheme.js" as Theme
import "../../controls"

Rectangle {
    id: service
    property var item: ({})
    property string glyph: ""
    property string onLabel: "ACTIVE"
    property string offLabel: "STOPPED"
    property string detail: ""
    readonly property bool running: !!item && !!item.running
    readonly property color tint: running ? Theme.success : Theme.accent
    signal logsRequested
    signal toggleRequested
    width: ListView.view ? ListView.view.width : 0
    implicitHeight: 76
    radius: 18
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
            position: 0
            color: Qt.alpha(service.tint, service.running ? 0.14 : serviceHover.hovered ? 0.07 : 0.03)
            Behavior on color { ColorAnimation { duration: 220 } }
        }
        GradientStop { position: 0.6; color: Qt.alpha(Theme.foreground, serviceHover.hovered ? 0.05 : 0.025) }
        GradientStop { position: 1; color: Qt.alpha(Theme.foreground, 0.015) }
    }
    border.width: 1
    border.color: running ? Qt.alpha(Theme.success, serviceHover.hovered ? 0.55 : 0.32) : Qt.alpha(Theme.foreground, serviceHover.hovered ? 0.14 : 0.07)
    Behavior on border.color { ColorAnimation { duration: 180 } }

    HoverHandler { id: serviceHover }

    Rectangle {
        x: 22
        y: 0
        width: parent.width * 0.45
        height: 1
        opacity: service.running ? 1 : serviceHover.hovered ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(service.tint, 0.9) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Item {
        id: scanClip
        anchors.fill: parent
        anchors.margins: 1
        clip: true
        visible: service.running
        Rectangle {
            id: scanLine
            width: 90
            height: parent.height
            opacity: 0.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.alpha(Theme.success, 0.08) }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on x {
                running: scanClip.visible && service.visible
                from: -scanLine.width
                to: scanClip.width
                duration: 4200
                loops: Animation.Infinite
                easing.type: Easing.InOutSine
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 14

        Item {
            id: orb
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50

            Rectangle {
                anchors.centerIn: parent
                width: 50
                height: 50
                radius: 25
                color: Qt.alpha(Theme.success, 0.25)
                visible: service.running
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 24
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(Theme.foreground, 0.1)
                    strokeWidth: 2
                    fillColor: "transparent"
                    PathAngleArc { centerX: 25; centerY: 25; radiusX: 23; radiusY: 23; startAngle: 0; sweepAngle: 360 }
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: service.running
                RotationAnimation on rotation {
                    running: service.running && service.visible
                    from: 0
                    to: 360
                    duration: 3200
                    loops: Animation.Infinite
                }
                ShapePath {
                    strokeColor: Theme.success
                    strokeWidth: 2.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 25; centerY: 25; radiusX: 23; radiusY: 23; startAngle: 0; sweepAngle: 100 }
                }
                ShapePath {
                    strokeColor: Qt.alpha(Theme.success, 0.45)
                    strokeWidth: 2.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 25; centerY: 25; radiusX: 23; radiusY: 23; startAngle: 180; sweepAngle: 50 }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: 18
                color: "#221c21"
                border.width: 1
                border.color: service.running ? Qt.alpha(Theme.success, 0.5) : Qt.alpha(Theme.foreground, 0.1)
                Behavior on border.color { ColorAnimation { duration: 180 } }
                Text {
                    anchors.centerIn: parent
                    text: service.glyph
                    font.family: Theme.iconFont
                    font.pixelSize: 19
                    color: service.running ? Theme.success : Theme.dim
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: service.item ? service.item.name : ""
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: service.running ? Theme.foreground : Qt.alpha(Theme.foreground, 0.75)
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: statusRow.implicitWidth + 16
                    radius: 9
                    color: service.running ? Qt.alpha(Theme.success, 0.14) : Qt.alpha(Theme.foreground, 0.05)
                    border.width: 1
                    border.color: service.running ? Qt.alpha(Theme.success, 0.4) : Qt.alpha(Theme.foreground, 0.1)
                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 5
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: 3
                                color: service.running ? Theme.success : Theme.dim
                            }
                            Rectangle {
                                id: pulse
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.success
                                visible: service.running
                                ParallelAnimation {
                                    running: pulse.visible && service.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { target: pulse; property: "width"; from: 6; to: 16; duration: 1400; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: pulse; property: "height"; from: 6; to: 16; duration: 1400; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: pulse; property: "opacity"; from: 0.9; to: 0; duration: 1400 }
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: service.running ? service.onLabel : service.offLabel
                            font.family: "monospace"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            color: service.running ? Theme.success : Theme.dim
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: service.detail
                    font.family: "monospace"
                    font.pixelSize: 10
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            id: logsButton
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 17
            color: logsMouse.containsMouse ? Qt.alpha(Theme.accent, 0.16) : Qt.alpha(Theme.foreground, 0.05)
            border.width: 1
            border.color: logsMouse.containsMouse ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.foreground, 0.1)
            scale: logsMouse.pressed ? 0.9 : 1
            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on scale { NumberAnimation { duration: 90 } }
            Text {
                anchors.centerIn: parent
                text: "󰦨"
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: logsMouse.containsMouse ? Theme.accent : Theme.muted
            }
            MouseArea {
                id: logsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: service.logsRequested()
            }
        }

        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44

            Rectangle {
                anchors.centerIn: parent
                width: 44
                height: 44
                radius: 22
                color: Qt.alpha(service.running ? Theme.success : Theme.accent, 0.35)
                opacity: service.running || powerMouse.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 20
                }
            }

            Rectangle {
                id: powerButton
                readonly property color ink: service.running ? (powerMouse.containsMouse ? Theme.danger : Theme.success) : (powerMouse.containsMouse ? Theme.accent : Theme.muted)
                anchors.centerIn: parent
                width: 38
                height: 38
                radius: 19
                color: service.running ? Qt.alpha(powerButton.ink, 0.18) : Qt.alpha(Theme.foreground, powerMouse.containsMouse ? 0.08 : 0.04)
                border.width: 1.5
                border.color: Qt.alpha(powerButton.ink, service.running || powerMouse.containsMouse ? 0.8 : 0.3)
                scale: powerMouse.pressed ? 0.88 : 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: powerButton.ink
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: service.toggleRequested()
                }
                PanelToolTip {
                    visible: powerMouse.containsMouse
                    text: service.running ? "Stop" : "Start"
                }
            }
        }
    }
}
