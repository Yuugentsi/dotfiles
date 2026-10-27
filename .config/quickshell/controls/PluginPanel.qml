import QtQuick
import Quickshell.Io

Item {
    id: root
    signal backRequested()
    signal panelRequested(string panel)
    property string moduleName: ""
    property string ipcTarget: ""
    property bool manageIpc: true
    property bool opened: false
    property real popupX: 6
    property QtObject bar: QtObject {
        property color foreground: "#eef3f8"
        property color urgent: "#bf616a"
        property string fontFamily: "JetBrainsMono Nerd Font"
        property var shell: null
    }
    function space(value) { return value }
    function open() { root.opened = true }
    function close() { root.opened = false }
    function toggle() { root.opened = !root.opened }
    function switchPanel(direction) { close() }
    IpcHandler {
        target: root.ipcTarget
        function toggle(): void { root.toggle() }
        function close(): void { root.close() }
    }
}
