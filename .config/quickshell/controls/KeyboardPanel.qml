import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    property var anchorItem: null
    property var owner: null
    property var bar: null
    property bool open: false
    property bool centered: false
    property var focusTarget: null
    property real contentWidth: 380
    property real contentHeight: 400
    default property alias content: container.data
    function fittedContentWidth(value) { return Math.min(value, window.width - 40) }
    function fittedContentHeight(value, maximum) { return Math.min(value, maximum || 560, window.height - 96) }
    onOpenChanged: { if (open) Qt.callLater(function() { if (focusTarget) focusTarget.forceActiveFocus() }) }
    data: [PanelWindow {
        id: window
        Shortcut {
            sequence: "B"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: {
                if (root.owner) {
                    root.owner.close()
                    root.owner.backRequested()
                }
            }
        }
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: root.owner ? root.owner.moduleName : "controls"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        PanelNavigation {
            x: 8
            y: 4
            width: parent.width - 16
            z: 100
            currentPanel: root.owner ? root.owner.ipcTarget : ""
            onSelected: function(panel) { if (root.owner) root.owner.panelRequested(panel) }
        }

        Rectangle { anchors.fill: parent; color: "#ac080e16" }
        MouseArea { anchors.fill: parent; onClicked: if (root.owner) root.owner.close() }
        Rectangle {
            x: root.centered ? (window.width - width) / 2 : Math.max(6, Math.min(root.owner ? root.owner.popupX : 6, window.width - width - 6))
            y: root.centered ? (window.height - height) / 2 : 44
            width: root.contentWidth + 36
            height: root.contentHeight + 36
            gradient: Gradient {
                GradientStop { position: 0; color: "#202027" }
                GradientStop { position: 1; color: "#18181d" }
            }
            radius: 8
            border.width: 1
            border.color: "#37343f"
            MouseArea { anchors.fill: parent; onClicked: {} }
            Item { id: container; anchors.fill: parent; anchors.margins: 18 }
        }
    }]
}
