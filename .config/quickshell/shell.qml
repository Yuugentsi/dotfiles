import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"

ShellRoot {
    id: shell
    Dock {}
    WindowSwitcher {}
    DynamicIsland { id: dynamicIsland; audioBackend: audio; displayBackend: display }
    Hypr { audioBackend: audio }
    MusicNotify { suppressNotifications: !dynamicIsland.automaticNotifications || !dynamicIsland.settingsReady || dynamicIsland.doNotDisturb }
    property bool barVisible: false
    IpcHandler {
        target: "bar"
        function toggle(): void {
            shell.barVisible = !shell.barVisible
            if (!shell.barVisible) {
                hub.close()
                media.close()
                clipboard.close()
                audio.close()
                bluetooth.close()
                wifi.close(); display.close()
            }
        }
    }
    PanelMenu {
        id: panelMenu
        opened: hub.opened || media.opened || clipboard.opened || audio.opened || bluetooth.opened || wifi.opened || display.opened
        onOpening: {
            hub.close()
            media.close()
            clipboard.close()
            audio.close()
            bluetooth.close()
            wifi.close(); display.close()
        }
        onSelected: function(panel) {
            panelMenu.lastPanel = panel
            Qt.callLater(function() {
                if (panel === "hub") hub.open("{}")
                else if (panel === "media") media.open("{}")
                else if (panel === "clipboard") clipboard.open("{}")
                else if (panel === "audio") audio.open()
                else if (panel === "bluetooth") bluetooth.open()
                else if (panel === "wifi") wifi.open()
                else if (panel === "display") display.open()
            })
        }
    }
    EdgePanels {
        options: panelMenu.options
        available: !panelMenu.opened && !hub.opened && !media.opened && !clipboard.opened && !audio.opened && !bluetooth.opened && !wifi.opened && !display.opened
        onSelected: function(index) { panelMenu.activate(index) }
    }
    Hub { id: hub; onBackRequested: panelMenu.selected("hub"); onPanelRequested: function(panel) { panelMenu.selected(panel) }; onOpenedChanged: if (opened) { panelMenu.lastPanel = "hub"; media.close(); clipboard.close(); audio.close(); bluetooth.close(); wifi.close(); display.close() } }
    Media { id: media; onBackRequested: panelMenu.selected("hub"); onPanelRequested: function(panel) { panelMenu.selected(panel) }; onOpenedChanged: if (opened) { panelMenu.lastPanel = "media"; hub.close(); clipboard.close(); audio.close(); bluetooth.close(); wifi.close(); display.close() } }
    Clipboard { id: clipboard; onBackRequested: panelMenu.selected("hub"); onPanelRequested: function(panel) { panelMenu.selected(panel) }; onOpenedChanged: if (opened) { panelMenu.lastPanel = "clipboard"; hub.close(); media.close(); audio.close(); bluetooth.close(); wifi.close(); display.close() } }

    Audio { id: audio; bluetoothBackend: bluetooth; onBackRequested: panelMenu.selected("hub"); onPanelRequested: function(panel) { panelMenu.selected(panel) }; popupX: 228; onOpenedChanged: if (opened) { panelMenu.lastPanel = "audio"; hub.close(); media.close(); clipboard.close(); bluetooth.close(); wifi.close(); display.close() } }
    Bluetooth { id: bluetooth; onBackRequested: panelMenu.selected("hub"); onPanelRequested: function(panel) { panelMenu.selected(panel) }; popupX: 294; onOpenedChanged: if (opened) { panelMenu.lastPanel = "bluetooth"; hub.close(); media.close(); clipboard.close(); audio.close(); wifi.close(); display.close() } }

    Wifi {
        id: wifi
        onBackRequested: panelMenu.selected("hub")
        onPanelRequested: function(panel) { panelMenu.selected(panel) }
        onOpenedChanged: if (opened) {
            panelMenu.lastPanel = "wifi"
            hub.close()
            media.close()
            clipboard.close()
            audio.close()
            bluetooth.close()
            display.close()
        }
    }
    Display {
        id: display
        onBackRequested: panelMenu.selected("hub")
        onPanelRequested: function(panel) { panelMenu.selected(panel) }
        onOpenedChanged: if (opened) {
            panelMenu.lastPanel = "display"
            hub.close()
            media.close()
            clipboard.close()
            audio.close()
            bluetooth.close()
            wifi.close()
        }
    }

    PanelWindow {
        id: topBar
        visible: shell.barVisible
        anchors { top: true; left: true; right: true }
        margins { top: 4; left: 6; right: 6 }
        implicitHeight: 22
        color: "transparent"
        exclusionMode: ExclusionMode.Auto
        WlrLayershell.namespace: "hub-bar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: hubButton
            width: 58
            height: parent.height
            radius: 4
            color: hub.opened || hit.containsMouse ? "#383044" : "#18181d"
            border.width: hub.opened ? 1 : 0
            border.color: "#c3b7ff"

            Text {
                anchors.centerIn: parent
                text: "◇ Hub"
                font.family: "sans-serif"
                font.pixelSize: 11
                color: hub.opened ? "#c3b7ff" : "#eef3f8"
            }

            MouseArea {
                id: hit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: hub.toggle()
            }

            ToolTip.visible: hit.containsMouse
            ToolTip.delay: 600
            ToolTip.text: "Open Hub"
        }
        Rectangle {
            x: 62
            width: 66
            height: parent.height
            radius: 4
            color: media.opened || mediaHit.containsMouse ? "#383044" : "#18181d"
            border.width: media.opened ? 1 : 0
            border.color: "#c3b7ff"
            Text {
                anchors.centerIn: parent
                text: "♫ Media"
                font.family: "sans-serif"
                font.pixelSize: 11
                color: media.opened ? "#c3b7ff" : "#eef3f8"
            }
            MouseArea {
                id: mediaHit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: media.toggle()
            }
            ToolTip.visible: mediaHit.containsMouse
            ToolTip.delay: 600
            ToolTip.text: "Open Media"
        }
        Rectangle {
            x: 132
            width: 88
            height: parent.height
            radius: 4
            color: clipboard.opened || clipboardHit.containsMouse ? "#383044" : "#18181d"
            border.width: clipboard.opened ? 1 : 0
            border.color: "#c3b7ff"
            Text {
                anchors.centerIn: parent
                text: "Clipboard"
                font.family: "sans-serif"
                font.pixelSize: 11
                color: clipboard.opened ? "#c3b7ff" : "#eef3f8"
            }
            MouseArea {
                id: clipboardHit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: clipboard.toggle()
            }
            ToolTip.visible: clipboardHit.containsMouse
            ToolTip.delay: 600
            ToolTip.text: "Open Clipboard"
        }
        Rectangle {
            x: 224
            width: 62
            height: parent.height
            radius: 4
            color: audio.opened || audioHit.containsMouse ? "#383044" : "#18181d"
            border.width: audio.opened ? 1 : 0
            border.color: "#c3b7ff"
            Text {
                anchors.centerIn: parent
                text: "󰕾 Audio"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: audio.opened ? "#c3b7ff" : "#eef3f8"
            }
            MouseArea {
                id: audioHit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: audio.toggle()
            }
            ToolTip.visible: audioHit.containsMouse
            ToolTip.delay: 600
            ToolTip.text: "Open Audio"
        }
        Rectangle {
            x: 290; width: 68; height: parent.height; radius: 4
            color: wifi.opened || wifiHit.containsMouse ? "#383044" : "#18181d"
            border.width: wifi.opened ? 1 : 0; border.color: "#c3b7ff"
            Text {
                anchors.centerIn: parent; text: "\uf1eb  Wi-Fi"
                color: wifi.opened ? "#c3b7ff" : "#eef3f8"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
            }
            MouseArea { id: wifiHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wifi.toggle() }
            ToolTip.visible: wifiHit.containsMouse
            ToolTip.delay: 600
            ToolTip.text: "Open Wi-Fi"
        }
        Rectangle {
            x: 362; width: 76; height: parent.height; radius: 4
            color: display.opened || displayHit.containsMouse ? "#383044" : "#18181d"
            border.width: display.opened ? 1 : 0; border.color: "#c3b7ff"
            Text {
                anchors.centerIn: parent; text: "\uf185  Display"
                color: display.opened ? "#c3b7ff" : "#eef3f8"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
            }
            MouseArea { id: displayHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: display.toggle() }
            ToolTip.visible: displayHit.containsMouse
            ToolTip.delay: 600
            ToolTip.text: "Open Display"
        }
    }
}
