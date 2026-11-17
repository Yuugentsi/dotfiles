import "../controls/PanelTheme.js" as Theme
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../controls"

Item {
    id: root
    property bool opened: false
    signal panelRequested(string panel)

    function open() {
        opened = true;
    }
    function close() {
        opened = false;
    }
    function toggle() {
        opened = !opened;
    }

    IpcHandler {
        target: "hyprSettings"
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hypr-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
        PanelNavigation {
            x: 16
            y: 8
            width: parent.width - 32
            currentPanel: "hypr"
            onSelected: function (panel) {
                root.panelRequested(panel);
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(360, panel.width - 32)
            height: Math.min(content.implicitHeight + 36, panel.height - 112)
            radius: 28
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
            focus: true
            Keys.onEscapePressed: root.close()
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            ScrollView {
                id: scroll
                anchors.fill: parent
                anchors.margins: 18
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                Column {
                    id: content
                    width: scroll.availableWidth
                    spacing: 18
                    HyprSettings {
                        width: parent.width
                        height: implicitHeight
                        opened: root.opened
                        onCloseRequested: root.close()
                    }
                }
            }
        }
    }
}
