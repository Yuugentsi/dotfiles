pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    property var options: []
    property bool available: true
    signal selected(int index)

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: dock
            required property var modelData
            property bool expanded: false
            screen: modelData
            visible: root.available
            anchors.right: true
            implicitWidth: expanded ? 132 : 3
            implicitHeight: buttons.implicitHeight + 20
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "panel-edge"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible)
                expanded = false

            Timer {
                id: hideDelay
                interval: 350
                onTriggered: if (!edgeHover.hovered)
                    dock.expanded = false
            }

            Item {
                anchors.fill: parent
                Shape {
                    id: edgeFrame
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    visible: dock.expanded
                    ShapePath {
                        strokeWidth: 1
                        strokeColor: "#45475a"
                        fillColor: "#1e1e2e"
                        startX: 9
                        startY: 1
                        PathLine { x: edgeFrame.width - 1; y: 1 }
                        PathLine { x: edgeFrame.width - 1; y: edgeFrame.height - 9 }
                        PathLine { x: edgeFrame.width - 9; y: edgeFrame.height - 1 }
                        PathLine { x: 1; y: edgeFrame.height - 1 }
                        PathLine { x: 1; y: 9 }
                        PathLine { x: 9; y: 1 }
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 20
                    color: "#50b4befe"
                    visible: !dock.expanded
                }
                HoverHandler {
                    id: edgeHover
                    onHoveredChanged: {
                        if (hovered) {
                            hideDelay.stop();
                            dock.expanded = true;
                        } else
                            hideDelay.restart();
                    }
                }
                Column {
                    id: buttons
                    x: 8
                    y: 10
                    width: 112
                    visible: dock.expanded
                    spacing: 2

                    Repeater {
                        model: root.options
                        Rectangle {
                            id: button
                            required property var modelData
                            required property int index
                            width: buttons.width
                            height: 28
                            radius: 2
                            color: hit.containsMouse ? "#80313244" : "transparent"
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.label
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: hit.containsMouse ? 16 : 6
                                color: "#b4befe"
                                opacity: hit.containsMouse ? 0.55 : 0
                                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }
                            Rectangle {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20
                                color: hit.containsMouse ? "#0ccba6f7" : "transparent"
                                border.width: 1
                                border.color: hit.containsMouse ? "#30b4befe" : "#40313244"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: button.modelData.icon
                                    color: hit.containsMouse ? "#b4befe" : "#a6adc8"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }
                            Text {
                                x: 36
                                anchors.verticalCenter: parent.verticalCenter
                                text: button.modelData.label
                                textFormat: Text.PlainText
                                color: hit.containsMouse ? "#cdd6f4" : "#bac2de"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.weight: Font.Normal
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uf105"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 10
                                color: "#b4befe"
                                opacity: hit.containsMouse ? 0.7 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: hit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dock.expanded = false;
                                    root.selected(button.index);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
