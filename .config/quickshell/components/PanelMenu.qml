import "../controls/PanelOptions.js" as NavigationOrder
import QtQuick
import Quickshell.Io

Item {
    id: root
    property bool opened: false
    property string lastPanel: "hub"
    signal selected(string panel)
    signal opening()
    readonly property var options: NavigationOrder.panels
    function close() { opening() }
    function toggle() {
        if (opened) close()
        else selected(lastPanel)
    }
    function activate(index) {
        if (index < 0 || index >= options.length) return
        selected(options[index].key)
    }
    IpcHandler {
        target: "panels"
        function toggle(): void { root.toggle() }
        function close(): void { root.close() }
    }
}
