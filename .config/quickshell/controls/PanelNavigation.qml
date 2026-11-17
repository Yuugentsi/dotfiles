import "PanelTheme.js" as Theme
import "PanelOptions.js" as NavigationOrder
import QtQuick
import QtQuick.Window

Item {
    id: root
    property string currentPanel: "hub"
    readonly property var focusItem: Window.window ? Window.window.activeFocusItem : null
    readonly property bool editingText: focusItem instanceof TextInput || focusItem instanceof TextEdit
    signal selected(string panel)
    readonly property var options: NavigationOrder.panels
    height: 42
    function advance(direction) {
        for (var index = 0; index < options.length; index++) {
            if (options[index].key === currentPanel) {
                selected(options[(index + direction + options.length) % options.length].key);
                return;
            }
        }
    }
    Shortcut {
        sequence: "D"
        context: Qt.WindowShortcut
        enabled: root.visible && !root.editingText
        onActivated: root.advance(1)
    }
    Shortcut {
        sequence: "A"
        context: Qt.WindowShortcut
        enabled: root.visible && !root.editingText
        onActivated: root.advance(-1)
    }
    Rectangle {
        anchors.horizontalCenter: bar.horizontalCenter
        y: 6
        width: bar.width + 8
        height: bar.height + 6
        radius: height / 2
        color: "#40000000"
    }
    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width, buttons.width + 14)
        height: root.height
        radius: height / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.gradientTop
            }
            GradientStop {
                position: 0.45
                color: Theme.gradientMiddle
            }
            GradientStop {
                position: 1
                color: Theme.gradientBottom
            }
        }
        border.width: 1
        border.color: Theme.border
        PanelAura { radius: bar.radius; intensity: 0.3 }
        Flickable {
            id: strip
            x: 7
            y: 5
            width: Math.max(0, parent.width - 14)
            height: parent.height - 10
            contentWidth: buttons.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Rectangle {
                id: indicator
                property Item target: null
                visible: target !== null
                x: target ? target.x : 0
                width: target ? target.width : 0
                height: strip.height
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.16) }
                    GradientStop { position: 1; color: Qt.alpha(Theme.accentAlt, 0.16) }
                }
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.25)
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 1
                    width: parent.width * 0.6
                    height: 1
                    color: Qt.alpha(Theme.foreground, 0.08)
                }
            }
            Row {
                id: buttons
                spacing: 2
                Repeater {
                    model: root.options
                    Rectangle {
                        id: button
                        objectName: "panel-" + modelData.key
                        required property var modelData
                        readonly property bool active: root.currentPanel === modelData.key
                        onActiveChanged: if (active) indicator.target = button
                        Component.onCompleted: if (active) indicator.target = button
                        width: caption.implicitWidth + 30
                        height: 32
                        radius: height / 2
                        color: !active && (hit.containsMouse || activeFocus) ? Qt.alpha(Theme.hover, 0.7) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }
                        border.width: activeFocus && !active ? 1 : 0
                        border.color: Theme.border
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.label
                        Keys.onReturnPressed: root.selected(modelData.key)
                        Keys.onSpacePressed: root.selected(modelData.key)
                        Row {
                            id: caption
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: button.modelData.icon
                                color: button.active ? Theme.accent : hit.containsMouse ? Theme.foreground : Theme.muted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                            Text {
                                text: button.modelData.label
                                color: button.active || hit.containsMouse ? Theme.foreground : Theme.muted
                                font.family: "sans-serif"
                                font.pixelSize: 11
                                font.weight: button.active ? Font.DemiBold : Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }
                        Timer {
                            interval: 180
                            running: root.visible && hit.containsMouse && !button.active
                            onTriggered: root.selected(button.modelData.key)
                        }
                        MouseArea {
                            id: hit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selected(button.modelData.key)
                        }
                    }
                }
            }
        }
    }
}
