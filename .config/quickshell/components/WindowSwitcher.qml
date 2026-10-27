pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland
import "../scripts/SwitcherModel.js" as Model

Item {
    id: root
    property bool opened: false
    property bool heldMode: false
    property int selectedIndex: -1
    property string selectedAddress: ""
    property string pendingAddress: ""
    property var history: []
    property var windows: []
    property var sources: Hyprland.toplevels.values
    property string shortcutLabel: "Alt+Esc"
    readonly property var selectedWindow: selectedIndex >= 0 && selectedIndex < windows.length ? windows[selectedIndex] : null

    function updateSelection(index) {
        selectedIndex = Model.wrap(index, windows.length);
        selectedAddress = selectedWindow ? selectedWindow.address : "";
    }
    function show(direction, held) {
        focusDelay.stop();
        pendingAddress = "";
        if (opened) {
            heldMode = heldMode || held;
            updateSelection(selectedIndex + direction);
            return;
        }
        windows = Model.rank(sources, history);
        heldMode = held;
        const monitor = Hyprland.focusedMonitor;
        const target = Quickshell.screens.find(screen => monitor && screen.name === monitor.name);
        if (target)
            panel.screen = target;
        const active = Hyprland.activeToplevel;
        const activeIndex = active ? windows.findIndex(window => window.address === active.address) : -1;
        updateSelection(activeIndex >= 0 ? activeIndex + direction : direction < 0 ? windows.length - 1 : 0);
        opened = true;
        Hyprland.refreshToplevels();
        Qt.callLater(function () {
            panel.takeFocus();
        });
    }
    function step(direction) {
        if (opened)
            updateSelection(selectedIndex + direction);
    }
    function cancel() {
        opened = false;
        heldMode = false;
        pendingAddress = "";
        focusDelay.stop();
    }
    function accept() {
        if (!opened)
            return;
        const target = selectedAddress;
        opened = false;
        heldMode = false;
        if (target && Model.eligible(sources).some(window => window.address === target)) {
            pendingAddress = target;
            focusDelay.restart();
        }
    }
    function acceptHeld() {
        if (opened && heldMode)
            accept();
    }
    function refreshOpenWindows() {
        if (!opened)
            return;
        const previous = selectedAddress;
        const oldIndex = selectedIndex;
        windows = Model.reconcile(sources, windows.map(window => window.address));
        if (!windows.length) {
            cancel();
            return;
        }
        const index = windows.findIndex(window => window.address === previous);
        updateSelection(index >= 0 ? index : Math.min(oldIndex, windows.length - 1));
    }
    function recordActive() {
        const active = Hyprland.activeToplevel;
        if (active && active.address && !opened)
            history = Model.remember(history, active.address, sources);
    }
    onSourcesChanged: refreshOpenWindows()
    Component.onCompleted: recordActive()
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.recordActive();
        }
    }
    Timer {
        id: focusDelay
        interval: 30
        onTriggered: {
            const address = root.pendingAddress;
            root.pendingAddress = "";
            const target = Model.eligible(root.sources).find(window => window.address === address);
            if (target) {
                const address = target.address.startsWith("0x") ? target.address : "0x" + target.address;
                focusRequest.command = ["hyprctl", "eval", 'hl.dispatch(hl.dsp.focus({window="address:' + address + '"}))'];
                focusRequest.running = true;
            }
        }
    }
    Process {
        id: focusRequest
    }
    IpcHandler {
        target: "windowSwitcher"
        function next(): void {
            root.show(1, true);
        }
        function previous(): void {
            root.show(-1, true);
        }
        function toggle(): void {
            if (root.opened)
                root.cancel();
            else
                root.show(1, false);
        }
        function accept(): void {
            root.accept();
        }
        function acceptHeld(): void {
            root.acceptHeld();
        }
        function cancel(): void {
            root.cancel();
        }
        function select(index: int): void {
            if (root.opened)
                root.updateSelection(index);
        }
        function status(): string {
            return JSON.stringify({
                opened: root.opened,
                held: root.heldMode,
                count: root.windows.length,
                selected: root.selectedIndex,
                selectedAddress: root.selectedAddress,
                previews: panel.previewCount(),
                keyboardIsolated: panel.navigationIsolated,
                tileWidth: panel.tileWidth,
                columns: panel.columns,
                shortcut: root.shortcutLabel
            });
        }
    }
    SwitcherWindow {
        id: panel
        controller: root
    }

    component SwitcherWindow: PanelWindow {
        id: switcherWindowPanel
        required property var controller
        readonly property bool navigationIsolated: switcherWindowShortcutGuard.active
        readonly property int columns: Math.max(1, Math.min(4, controller.windows.length || 1, Math.floor((width - 104) / 300)))
        readonly property real tileWidth: Math.min(360, (width - 104) / columns)
        readonly property real tileHeight: Math.round((tileWidth - 28) * 9 / 16) + 76
        readonly property int rows: Math.max(1, Math.min(Math.ceil(controller.windows.length / columns), Math.floor((height - 190) / tileHeight)))
        visible: controller.opened || switcherWindowFade.running
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "window-switcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: controller.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (!visible)
            switcherWindowContentLoader.active = false

        ShortcutInhibitor {
            id: switcherWindowShortcutGuard
            window: switcherWindowPanel
            enabled: switcherWindowPanel.controller.opened
        }

        function takeFocus() {
            switcherWindowContentLoader.active = true;
            switcherWindowKeyArea.forceActiveFocus();
        }
        function previewCount() {
            if (!switcherWindowContentLoader.item)
                return 0;
            return switcherWindowContentLoader.item.previewCount();
        }
        Connections {
            target: switcherWindowPanel.controller
            function onOpenedChanged() {
                if (switcherWindowPanel.controller.opened) {
                    switcherWindowContentLoader.active = true;
                    Qt.callLater(function () {
                        switcherWindowPanel.takeFocus();
                    });
                }
            }
        }
        Item {
            id: switcherWindowKeyArea
            anchors.fill: parent
            focus: switcherWindowPanel.controller.opened
            Keys.onPressed: function (event) {
                if (!switcherWindowPanel.controller.opened)
                    return;
                if (event.key === Qt.Key_Escape && (event.modifiers & Qt.AltModifier))
                    switcherWindowPanel.controller.step(1);
                else if (event.key === Qt.Key_Escape)
                    switcherWindowPanel.controller.cancel();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                    switcherWindowPanel.controller.accept();
                else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right)
                    switcherWindowPanel.controller.step(1);
                else if (event.key === Qt.Key_Left)
                    switcherWindowPanel.controller.step(-1);
                else if (event.key === Qt.Key_Down)
                    switcherWindowPanel.controller.step(switcherWindowPanel.columns);
                else if (event.key === Qt.Key_Up)
                    switcherWindowPanel.controller.step(-switcherWindowPanel.columns);
                else if (event.key === Qt.Key_Home)
                    switcherWindowPanel.controller.updateSelection(0);
                else if (event.key === Qt.Key_End)
                    switcherWindowPanel.controller.updateSelection(switcherWindowPanel.controller.windows.length - 1);
                else
                    return;
                event.accepted = true;
            }
            Keys.onReleased: function (event) {
                if (event.key === Qt.Key_Alt && switcherWindowPanel.controller.heldMode) {
                    switcherWindowPanel.controller.acceptHeld();
                    event.accepted = true;
                }
            }
        }
        Item {
            id: switcherWindowContent
            anchors.fill: parent
            opacity: switcherWindowPanel.controller.opened ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    id: switcherWindowFade
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "#990c0911"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: switcherWindowPanel.controller.cancel()
                onWheel: function (wheel) {
                    switcherWindowPanel.controller.step(wheel.angleDelta.y > 0 ? -1 : 1);
                    wheel.accepted = true;
                }
            }
            Loader {
                id: switcherWindowContentLoader
                anchors.centerIn: parent
                active: false
                sourceComponent: Rectangle {
                    id: switcherWindowCard
                    width: switcherWindowPanel.columns * switcherWindowPanel.tileWidth + 40
                    height: 72 + switcherWindowPanel.rows * switcherWindowPanel.tileHeight + 42
                    radius: 23
                    color: "#f21d1b22"
                    border.width: 1
                    border.color: "#6b536e80"
                    scale: switcherWindowPanel.controller.opened ? 1 : 0.96
                    Behavior on scale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                    function previewCount() {
                        let ready = 0;
                        for (let index = 0; index < switcherWindowPanel.controller.windows.length; index++) {
                            const item = switcherWindowGrid.itemAtIndex(index);
                            if (item && item.previewReady)
                                ready++;
                        }
                        return ready;
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {}
                    }
                    Row {
                        x: 24
                        y: 22
                        spacing: 10
                        Text {
                            text: "Windows"
                            color: "#f3eaff"
                            font.family: "sans-serif"
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: switcherWindowPanel.controller.windows.length
                            color: "#b8a1cc"
                            font.pixelSize: 13
                        }
                    }
                    ToolButton {
                        id: switcherWindowCloseButton
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 18
                        anchors.topMargin: 15
                        width: 30
                        height: 30
                        text: "×"
                        Accessible.name: "Cancel window selection"
                        onClicked: switcherWindowPanel.controller.cancel()
                        contentItem: Text {
                            text: "×"
                            color: "#bba6ca"
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 10
                            color: switcherWindowCloseButton.hovered ? "#3b2a47" : "transparent"
                        }
                    }
                    GridView {
                        id: switcherWindowGrid
                        x: 20
                        y: 64
                        width: switcherWindowPanel.columns * switcherWindowPanel.tileWidth
                        height: switcherWindowPanel.rows * switcherWindowPanel.tileHeight
                        cellWidth: switcherWindowPanel.tileWidth
                        cellHeight: switcherWindowPanel.tileHeight
                        clip: true
                        cacheBuffer: 0
                        boundsBehavior: Flickable.StopAtBounds
                        model: switcherWindowPanel.controller.windows
                        currentIndex: switcherWindowPanel.controller.selectedIndex
                        highlightRangeMode: GridView.ApplyRange
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: height - cellHeight
                        highlightMoveDuration: 100
                        onCurrentIndexChanged: if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, GridView.Contain)
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                        delegate: WindowCard {
                            required property var modelData
                            required property int index
                            width: switcherWindowGrid.cellWidth
                            height: switcherWindowGrid.cellHeight
                            windowData: modelData
                            selected: index === switcherWindowPanel.controller.selectedIndex
                            active: switcherWindowPanel.visible
                            onPointed: if (switcherWindowPanel.controller.selectedIndex !== index)
                                switcherWindowPanel.controller.updateSelection(index)
                            onChosen: {
                                switcherWindowPanel.controller.updateSelection(index);
                                switcherWindowPanel.controller.accept();
                            }
                        }
                    }
                    Text {
                        x: 25
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 17
                        width: parent.width - 50
                        text: switcherWindowPanel.controller.windows.length ? "Tab / arrows to choose   ·   Release Alt or Enter to switch   ·   Esc to cancel" : "No open windows   ·   Esc to close"
                        color: "#9b8ba7"
                        font.family: "sans-serif"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component WindowCard: Item {
        id: windowCardRoot
        required property var windowData
        property bool selected: false
        property bool active: false
        property bool pointerReady: false
        property point lastPointer: Qt.point(-1, -1)
        readonly property var handle: windowData ? windowData.wayland : null
        readonly property var entry: handle && handle.appId ? DesktopEntries.heuristicLookup(handle.appId) : null
        readonly property string appName: entry ? entry.name : handle ? handle.appId : "Application"
        readonly property bool previewReady: windowCardCapture.hasContent
        signal chosen
        signal pointed

        Timer {
            interval: 180
            running: true
            onTriggered: windowCardRoot.pointerReady = true
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 15
            color: windowCardRoot.selected ? "#3c304b" : windowCardHit.containsMouse ? "#2b2533" : "#24212a"
            border.width: windowCardRoot.selected ? 2 : 1
            border.color: windowCardRoot.selected ? "#c3b7ff" : "#3d3447"
            Behavior on color {
                ColorAnimation {
                    duration: 110
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 110
                }
            }

            Row {
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 7
                Image {
                    width: 22
                    height: 22
                    source: windowCardRoot.entry && windowCardRoot.entry.icon ? Quickshell.iconPath(windowCardRoot.entry.icon, true) : ""
                    sourceSize.width: 44
                    sourceSize.height: 44
                    fillMode: Image.PreserveAspectFit
                    Text {
                        anchors.centerIn: parent
                        visible: parent.status !== Image.Ready
                        text: "◇"
                        font.pixelSize: 15
                        color: "#c3b7ff"
                    }
                }
                Text {
                    width: parent.width - 29
                    anchors.verticalCenter: parent.verticalCenter
                    text: windowCardRoot.windowData ? windowCardRoot.windowData.title || windowCardRoot.appName : "Window closed"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: windowCardRoot.selected ? "#f7f3fc" : "#cec4db"
                    font.family: "sans-serif"
                    font.pixelSize: 13
                    font.weight: windowCardRoot.selected ? Font.DemiBold : Font.Normal
                }
            }

            ClippingRectangle {
                id: windowCardThumbnail
                x: 10
                y: 44
                width: parent.width - 20
                height: parent.height - 76
                radius: 8
                color: "#16131b"
                ScreencopyView {
                    id: windowCardCapture
                    anchors.centerIn: parent
                    readonly property real aspect: sourceSize.width > 0 && sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 9
                    width: Math.min(windowCardThumbnail.width, windowCardThumbnail.height * aspect)
                    height: width / aspect
                    constraintSize: Qt.size(windowCardThumbnail.width, windowCardThumbnail.height)
                    captureSource: windowCardRoot.active ? windowCardRoot.handle : null
                    live: windowCardRoot.active && windowCardRoot.selected
                    paintCursor: false
                    onCaptureSourceChanged: if (captureSource && !live)
                        Qt.callLater(function () {
                            windowCardCapture.captureFrame();
                        })
                }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 6
                    visible: !windowCardCapture.hasContent
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "▣"
                        font.pixelSize: 26
                        color: "#7e6c91"
                    }
                    Text {
                        width: parent.width
                        text: "Preview unavailable"
                        horizontalAlignment: Text.AlignHCenter
                        color: "#92869f"
                        font.pixelSize: 11
                    }
                }
            }
            Text {
                x: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                width: parent.width - 24
                text: windowCardRoot.appName + (windowCardRoot.windowData && windowCardRoot.windowData.workspace ? "  ·  Workspace " + windowCardRoot.windowData.workspace.name : "")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: windowCardRoot.selected ? "#c3b7ff" : "#92869f"
                font.pixelSize: 11
            }
        }
        MouseArea {
            id: windowCardHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                windowCardRoot.lastPointer = Qt.point(mouseX, mouseY);
                if (windowCardRoot.pointerReady)
                    windowCardRoot.pointed();
            }
            onPositionChanged: function (mouse) {
                const moved = Math.abs(mouse.x - windowCardRoot.lastPointer.x) > 0.5 || Math.abs(mouse.y - windowCardRoot.lastPointer.y) > 0.5;
                windowCardRoot.lastPointer = Qt.point(mouse.x, mouse.y);
                if (containsMouse && windowCardRoot.pointerReady && moved)
                    windowCardRoot.pointed();
            }
            onClicked: windowCardRoot.chosen()
        }
    }
}
