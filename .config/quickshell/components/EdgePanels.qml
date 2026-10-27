pragma ComponentBehavior: Bound

import QtQuick
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
            implicitWidth: expanded ? 184 : 3
            implicitHeight: buttons.implicitHeight + 24
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "panel-edge"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) expanded = false

            Timer {
                id: hideDelay
                interval: 350
                onTriggered: if (!edgeHover.hovered) dock.expanded = false
            }

            Rectangle {
                anchors.fill: parent
                color: dock.expanded ? "#18181d" : "transparent"
                radius: dock.expanded ? 8 : 0
                border.width: dock.expanded ? 1 : 0
                border.color: "#37343f"

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 1
                    radius: 0.5
                    color: "#90c3a0ff"
                    visible: !dock.expanded
                }

                HoverHandler {
                    id: edgeHover
                    onHoveredChanged: {
                        if (hovered) {
                            hideDelay.stop()
                            dock.expanded = true
                        } else hideDelay.restart()
                    }
                }

                Column {
                    id: buttons
                    x: 12
                    y: 12
                    width: 160
                    visible: dock.expanded
                    spacing: 6

                    Repeater {
                        model: root.options
                        Rectangle {
                            id: button
                            required property var modelData
                            required property int index
                            width: buttons.width
                            height: 42
                            radius: 5
                            color: hit.containsMouse ? "#383044" : "#222128"
                            border.width: hit.containsMouse ? 1 : 0
                            border.color: "#c3b7ff"

                            Text {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: button.modelData.icon
                                color: "#c3b7ff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                            }
                            Text {
                                x: 44
                                anchors.verticalCenter: parent.verticalCenter
                                text: button.modelData.label
                                color: "#eef3f8"
                                font.family: "sans-serif"
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: hit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dock.expanded = false
                                    root.selected(button.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
