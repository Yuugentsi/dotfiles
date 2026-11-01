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
        y: 3
        width: bar.width + 2
        height: bar.height + 2
        radius: 16
        color: "#50000000"
    }
    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width, buttons.width + 16)
        height: root.height
        radius: 14
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
        Flickable {
            x: 8
            y: 5
            width: Math.max(0, parent.width - 16)
            height: parent.height - 10
            contentWidth: buttons.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: buttons
                spacing: 3
                Repeater {
                    model: root.options
                    Rectangle {
                        id: button
                        objectName: "panel-" + modelData.key
                        required property var modelData
                        readonly property bool active: root.currentPanel === modelData.key
                        width: caption.implicitWidth + 28
                        height: 32
                        radius: 10
                        color: active ? Theme.selected : hit.containsMouse || activeFocus ? Theme.hover : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }
                        border.width: active || activeFocus ? 1 : 0
                        border.color: Theme.border
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.label
                        Keys.onReturnPressed: root.selected(modelData.key)
                        Keys.onSpacePressed: root.selected(modelData.key)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 16
                            height: 2
                            radius: 1
                            color: Theme.accent
                            visible: button.active
                        }
                        Row {
                            id: caption
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: button.modelData.icon
                                color: button.active ? Theme.accent : Theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: button.modelData.label
                                color: button.active ? Theme.foreground : Theme.accent
                                font.family: "sans-serif"
                                font.pixelSize: 11
                                font.weight: button.active ? Font.DemiBold : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
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
