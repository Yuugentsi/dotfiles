pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
    property string excludedAddress: ""
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
        const active = Hyprland.activeToplevel;
        excludedAddress = active ? active.address : "";
        windows = Model.rank(sources, history).filter(window => window.address !== excludedAddress);
        if (!windows.length) {
            heldMode = false;
            return;
        }
        heldMode = held;
        const monitor = Hyprland.focusedMonitor;
        const target = Quickshell.screens.find(screen => monitor && screen.name === monitor.name);
        if (target)
            panel.screen = target;
        updateSelection(direction < 0 ? windows.length - 1 : 0);
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
        windows = Model.reconcile(sources, windows.map(window => window.address)).filter(window => window.address !== excludedAddress);
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
        readonly property var layout: calculateLayout()
        readonly property real tileWidth: layout.tileWidth
        readonly property real tileHeight: layout.tileHeight
        readonly property int columns: layout.columns
        readonly property int rows: layout.rows

        function calculateLayout() {
            const count = Math.max(1, controller.windows.length);
            const availableWidth = Math.max(1, width - 160);
            const availableHeight = Math.max(1, height - 260);
            let best = { columns: 1, rows: count, tileWidth: 1, tileHeight: 1 };
            for (let candidate = 1; candidate <= count; candidate++) {
                const rowCount = Math.ceil(count / candidate);
                const size = Math.min(400, availableWidth / candidate, availableHeight / rowCount * 360 / 280);
                if (size > best.tileWidth || (size === best.tileWidth && candidate * rowCount < best.columns * best.rows))
                    best = { columns: candidate, rows: rowCount, tileWidth: size, tileHeight: size * 280 / 360 };
            }
            return best;
        }
        property real wheelDistance: 0
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

        function scrollWindows(delta) {
            wheelReset.restart();
            wheelDistance += delta;
            if (Math.abs(wheelDistance) >= 120) {
                controller.step(wheelDistance > 0 ? -1 : 1);
                wheelDistance = 0;
            }
        }
        Timer {
            id: wheelReset
            interval: 240
            onTriggered: switcherWindowPanel.wheelDistance = 0
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
                else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)))
                    switcherWindowPanel.controller.step(-1);
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right)
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
        function tileX(index) {
            const row = Math.floor(index / columns);
            const rowSize = Math.min(columns, controller.windows.length - row * columns);
            return (index % columns + (columns - rowSize) / 2) * tileWidth;
        }
        function tileY(index) {
            return Math.floor(index / columns) * tileHeight;
        }
        Item {
            id: switcherWindowContent
            anchors.fill: parent
            opacity: switcherWindowPanel.controller.opened ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    id: switcherWindowFade
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: switcherWindowPanel.controller.cancel()
                onWheel: function (wheel) {
                    switcherWindowPanel.scrollWindows(wheel.angleDelta.y || wheel.angleDelta.x);
                    wheel.accepted = true;
                }
            }
            Loader {
                id: switcherWindowContentLoader
                anchors.centerIn: parent
                active: false
                sourceComponent: Item {
                    id: switcherWindowOverview
                    width: switcherWindowGrid.width
                    height: switcherWindowGrid.height + 120
                    scale: switcherWindowPanel.controller.opened ? 1 : 0.94
                    Behavior on scale {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.3
                        }
                    }

                    function previewCount() {
                        let ready = 0;
                        for (let index = 0; index < switcherWindowTiles.count; index++) {
                            const item = switcherWindowTiles.itemAt(index) as WindowCard;
                            if (item && item.previewReady)
                                ready++;
                        }
                        return ready;
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        width: windowCount.implicitWidth + 28
                        height: 30
                        radius: 15
                        color: "#d91e1e2e"
                        border.width: 1
                        border.color: "#59cba6f7"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#80000000"
                            shadowBlur: 0.8
                            shadowVerticalOffset: 3
                        }
                        Text {
                            id: windowCount
                            anchors.centerIn: parent
                            text: (switcherWindowPanel.controller.selectedIndex + 1) + "  /  " + switcherWindowPanel.controller.windows.length
                            color: "#cba6f7"
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                    Item {
                        id: switcherWindowGrid
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 56
                        width: switcherWindowPanel.columns * switcherWindowPanel.tileWidth
                        height: switcherWindowPanel.rows * switcherWindowPanel.tileHeight
                        Repeater {
                            id: switcherWindowTiles
                            model: switcherWindowPanel.controller.windows
                            delegate: WindowCard {
                                required property var modelData
                                required property int index
                                x: switcherWindowPanel.tileX(index)
                                y: switcherWindowPanel.tileY(index)
                                width: switcherWindowPanel.tileWidth
                                height: switcherWindowPanel.tileHeight
                                windowData: modelData
                                position: index + 1
                                selected: index === switcherWindowPanel.controller.selectedIndex
                                active: switcherWindowPanel.visible
                                onChosen: {
                                    switcherWindowPanel.controller.updateSelection(index);
                                    switcherWindowPanel.controller.accept();
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        width: switcherWindowHints.implicitWidth + 28
                        height: 34
                        radius: 17
                        color: "#d91e1e2e"
                        border.width: 1
                        border.color: "#33cba6f7"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#80000000"
                            shadowBlur: 0.8
                            shadowVerticalOffset: 3
                        }
                        Row {
                            id: switcherWindowHints
                            anchors.centerIn: parent
                            spacing: 16
                            Repeater {
                                model: [
                                    { keys: switcherWindowPanel.controller.heldMode ? "Esc" : "Tab", label: "next" },
                                    { keys: switcherWindowPanel.controller.heldMode ? "Alt" : "Enter", label: switcherWindowPanel.controller.heldMode ? "release to open" : "open" },
                                    { keys: switcherWindowPanel.controller.heldMode ? "Click" : "Esc", label: switcherWindowPanel.controller.heldMode ? "pick" : "cancel" }
                                ]
                                delegate: Row {
                                    id: hintItem
                                    required property var modelData
                                    spacing: 7
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: keyLabel.implicitWidth + 14
                                        height: 20
                                        radius: 6
                                        color: "#313244"
                                        Text {
                                            id: keyLabel
                                            anchors.centerIn: parent
                                            text: hintItem.modelData.keys
                                            color: "#cdd6f4"
                                            font.family: "monospace"
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: hintItem.modelData.label
                                        color: "#a6adc8"
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component WindowCard: Item {
        id: windowPreviewRoot
        required property var windowData
        property bool selected: false
        property bool active: false
        property int position: 0
        readonly property var handle: windowData ? windowData.wayland : null
        readonly property var entry: handle && handle.appId ? DesktopEntries.heuristicLookup(handle.appId) : null
        readonly property string appName: entry ? entry.name : handle ? handle.appId : "Application"
        readonly property string iconSource: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
        readonly property bool previewReady: windowCapture.hasContent
        readonly property bool emphasized: selected || previewHit.containsMouse
        signal chosen

        Item {
            width: 360
            height: 280
            scale: windowPreviewRoot.width / 360
            transformOrigin: Item.TopLeft

            Item {
                id: previewFrame
                readonly property real aspect: windowCapture.sourceSize.width > 0 && windowCapture.sourceSize.height > 0 ? windowCapture.sourceSize.width / windowCapture.sourceSize.height : 16 / 10
                width: Math.min(316, 196 * aspect)
                height: width / aspect
                x: (parent.width - width) / 2
                y: 18 + (196 - height) / 2
                scale: windowPreviewRoot.selected ? 1.04 : windowPreviewRoot.emphasized ? 1 : 0.95
                opacity: windowPreviewRoot.emphasized ? 1 : 0.8
                Behavior on scale {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }

                Rectangle {
                    id: previewGlowSource
                    anchors.fill: parent
                    radius: 14
                    color: "#cba6f7"
                    visible: false
                }
                MultiEffect {
                    anchors.fill: previewGlowSource
                    source: previewGlowSource
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: windowPreviewRoot.selected ? "#cba6f7" : "#000000"
                    shadowBlur: 1.0
                    shadowScale: windowPreviewRoot.selected ? 1.05 : 1.0
                    shadowVerticalOffset: windowPreviewRoot.selected ? 0 : 8
                    shadowOpacity: windowPreviewRoot.selected ? 0.75 : 0.55
                    opacity: 1
                    Behavior on shadowOpacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    Behavior on shadowColor {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 17
                    opacity: windowPreviewRoot.selected ? 1 : 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#cba6f7" }
                        GradientStop { position: 0.5; color: "#f5c2e7" }
                        GradientStop { position: 1; color: "#89b4fa" }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "#181825"
                    ScreencopyView {
                        id: windowCapture
                        anchors.fill: parent
                        constraintSize: Qt.size(previewFrame.width, previewFrame.height)
                        captureSource: windowPreviewRoot.active ? windowPreviewRoot.handle : null
                        live: windowPreviewRoot.active && windowPreviewRoot.selected
                        paintCursor: false
                        onCaptureSourceChanged: if (captureSource && !live)
                            Qt.callLater(function () {
                                windowCapture.captureFrame();
                            })
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 56
                        height: 56
                        source: windowPreviewRoot.iconSource
                        sourceSize: Qt.size(112, 112)
                        fillMode: Image.PreserveAspectFit
                        visible: !windowCapture.hasContent
                        Text {
                            anchors.centerIn: parent
                            visible: parent.status !== Image.Ready
                            text: "󰖯"
                            color: "#cba6f7"
                            font.pixelSize: 36
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: "transparent"
                        border.width: 1
                        border.color: "#26ffffff"
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.bottom
                    width: 34
                    height: 34
                    radius: 17
                    color: "#1e1e2e"
                    border.width: 1
                    border.color: windowPreviewRoot.selected ? "#cba6f7" : "#45475a"
                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: windowPreviewRoot.iconSource
                        sourceSize: Qt.size(40, 40)
                        fillMode: Image.PreserveAspectFit
                        visible: source !== ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: windowPreviewRoot.iconSource === ""
                        text: windowPreviewRoot.position
                        color: "#cba6f7"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 240
                width: Math.min(captionColumn.implicitWidth + 28, 330)
                height: captionColumn.implicitHeight + 12
                radius: height / 2
                color: windowPreviewRoot.selected ? "#e61e1e2e" : "#b31e1e2e"
                opacity: windowPreviewRoot.emphasized ? 1 : 0.75
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }
                Column {
                    id: captionColumn
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, 302)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, 302)
                        horizontalAlignment: Text.AlignHCenter
                        text: windowPreviewRoot.windowData ? windowPreviewRoot.windowData.title || windowPreviewRoot.appName : "Window closed"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: windowPreviewRoot.selected ? "#f5e0ff" : "#cdd6f4"
                        font.pixelSize: 12
                        font.weight: windowPreviewRoot.selected ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
        MouseArea {
            id: previewHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: windowPreviewRoot.chosen()
        }
    }
}
