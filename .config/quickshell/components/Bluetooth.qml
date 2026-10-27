import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../controls"
import "../controls/Util.js" as Util
import "../scripts/BluetoothModel.js" as Model

PluginPanel {
    id: root
    moduleName: "bluetooth"
    ipcTarget: "bluetooth"
    manageIpc: true

    property var pendingActions: ({})
    property bool embeddedOpened: false
    onEmbeddedOpenedChanged: if (embeddedOpened && adapter && adapter.discovering)
        owesDiscoveryStop = true

    readonly property var adapter: Bluetooth.defaultAdapter

    property bool owesDiscoveryStop: false
    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var pipewireNodes: Pipewire.nodes ? Pipewire.nodes.values : []
    property var pendingAudioOutputDevice: null
    property int pendingAudioOutputAttempts: 0
    property string preferredAudioAddress: ""
    property bool reconnectRequested: false
    property int reconnectAttempts: 0
    property var pendingResumePlayers: []
    property string resumeAudioAddress: ""
    property int resumeAttempts: 0
    property bool resumeRequested: false
    Process {
        id: lastAudioDevice
        command: ["python3", "-I", "-B", Quickshell.env("HOME") + "/.config/quickshell/scripts/route_audio.py", "--last"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: if (!root.preferredAudioAddress)
                root.preferredAudioAddress = text.trim()
        }
    }
    Timer {
        interval: 500
        running: root.reconnectRequested
        repeat: true
        onTriggered: root.reconnectAudioDevice()
    }
    Timer {
        interval: 500
        running: root.resumeRequested
        repeat: true
        onTriggered: root.resumePlaybackAfterReconnect()
    }
    function rememberPlayingPlayers() {
        pendingResumePlayers = Mpris.players.values.filter(function (player) {
            return player && player.isPlaying && player.canPause;
        });
        resumeAudioAddress = preferredAudioAddress;
        resumeAttempts = 0;
    }
    function resumePlaybackAfterReconnect() {
        if (!resumeRequested || pendingResumePlayers.length === 0)
            return;
        resumeAttempts += 1;
        if (resumeAttempts > 40) {
            pendingResumePlayers = [];
            resumeRequested = false;
            return;
        }
        if (!adapter || !adapter.enabled)
            return;
        var address = resumeAudioAddress || preferredAudioAddress;
        var device = null;
        for (var i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].connected && (!address || devices[i].address === address) && (bluetoothAudioSink(devices[i]) || Model.isAudioDevice(devices[i]))) {
                device = devices[i];
                break;
            }
        }
        if (!device)
            return;
        var sink = bluetoothAudioSink(device);
        if (!sink || !Pipewire.defaultAudioSink || sink.id !== Pipewire.defaultAudioSink.id)
            return;
        var players = pendingResumePlayers;
        pendingResumePlayers = [];
        resumeAudioAddress = "";
        resumeRequested = false;
        for (var j = 0; j < players.length; j++) {
            if (players[j] && !players[j].isPlaying && players[j].canPlay)
                players[j].togglePlaying();
        }
    }
    function reconnectAudioDevice() {
        if (!reconnectRequested)
            return;
        reconnectAttempts += 1;
        if (reconnectAttempts > 40) {
            reconnectRequested = false;
            return;
        }
        if (!adapter || !adapter.enabled)
            return;
        var device = Model.reconnectCandidate(devices, preferredAudioAddress);
        if (!device)
            return;
        preferredAudioAddress = device.address;
        reconnectRequested = false;
        if (device.connected)
            scheduleAudioOutputSwitch(device);
        else if (pendingAction(device.address) !== "connecting")
            connectDevice(device);
    }
    function rememberConnectedAudio() {
        var candidates = connectedDevices.filter(function (device) {
            return !!root.bluetoothAudioSink(device) || Model.isAudioDevice(device);
        });
        if (candidates.length === 1)
            preferredAudioAddress = candidates[0].address;
        else {
            for (var i = 0; i < candidates.length; i++) {
                var sink = bluetoothAudioSink(candidates[i]);
                if (sink && Pipewire.defaultAudioSink && sink.id === Pipewire.defaultAudioSink.id) {
                    preferredAudioAddress = candidates[i].address;
                    break;
                }
            }
        }
    }

    function deviceLabel(device) {
        return Model.deviceLabel(device);
    }

    function isUuidLike(value) {
        return Model.isUuidLike(value);
    }

    function isAddressLike(value) {
        return Model.isAddressLike(value);
    }

    function hasHumanName(device) {
        return Model.hasHumanName(device);
    }

    readonly property var deviceGroups: Model.deviceLists(devices)
    readonly property var connectedDevices: deviceGroups.connected || []
    readonly property var knownDevices: deviceGroups.known || []
    readonly property var discoveredDevices: deviceGroups.discovered || []

    readonly property string icon: {
        if (!adapter)
            return "";
        if (!adapter.enabled)
            return "󰂲";
        if (connectedDevices.length > 0)
            return "󰂱";
        return "󰂯";
    }

    property int phraseIndex: 0
    readonly property var activePhrases: ["Untangling wires", "Streaming vikings", "Pairing mysteries", "Herding headsets", "Taming radios", "Summoning speakers", "Wrangling codecs", "Polishing packets"]
    readonly property bool rotatingPhrases: adapter && adapter.enabled
    readonly property string heroStatusText: {
        if (!adapter)
            return "No adapter";
        if (!adapter.enabled)
            return "Turned Off";
        return activePhrases[phraseIndex % activePhrases.length];
    }

    property string focusSection: "connected"
    property int selectedIndex: 0
    property bool actionFocused: false
    property bool cursorActive: false

    property string focusedDeviceAddress: ""

    readonly property bool headerHasCursor: cursorActive && focusSection === "header"
    readonly property string toggleHint: root.adapter && root.adapter.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on"

    readonly property color hoverFill: bar ? "#383044" : "transparent"
    readonly property color selectedFill: bar ? "#383044" : "transparent"

    function sectionCount(section) {
        if (section === "connected")
            return connectedDevices.length;
        if (section === "known")
            return knownDevices.length;
        if (section === "discovered")
            return discoveredDevices.length;
        return 0;
    }

    function sectionVisible(section) {
        if (section === "connected")
            return connectedDevices.length > 0;
        if (section === "known")
            return knownDevices.length > 0;
        if (section === "discovered")
            return adapter && adapter.discovering && discoveredDevices.length > 0;
        return false;
    }

    readonly property var visibleSections: {
        return Model.visibleSections(deviceGroups, adapter && adapter.discovering);
    }

    function devicesForSection(section) {
        return Model.sectionDevices(deviceGroups, section);
    }

    readonly property var scrollRows: {
        var rows = [];
        for (var k = 0; k < knownDevices.length; k++)
            rows.push({
                dev: Model.deviceRow(knownDevices[k]),
                section: "known",
                indexInSection: k
            });
        if (sectionVisible("discovered"))
            for (var d = 0; d < discoveredDevices.length; d++)
                rows.push({
                    dev: Model.deviceRow(discoveredDevices[d]),
                    section: "discovered",
                    indexInSection: d
                });
        return rows;
    }

    readonly property var connectedRows: {
        var rows = [];
        for (var i = 0; i < connectedDevices.length; i++)
            rows.push(Model.deviceRow(connectedDevices[i]));
        return rows;
    }

    function deviceFor(row) {
        if (!row || !row.dev)
            return null;
        var addr = row.dev.address || "";
        var devs = devices || [];
        for (var i = 0; i < devs.length; i++) {
            if ((devs[i].address || "") === addr)
                return devs[i];
        }
        return null;
    }

    readonly property int scrollRowIndex: {
        if (focusSection !== "known" && focusSection !== "discovered")
            return -1;
        for (var i = 0; i < scrollRows.length; i++)
            if (scrollRows[i].section === focusSection && scrollRows[i].indexInSection === selectedIndex)
                return i;
        return -1;
    }

    function scrollSectionTitle(index) {
        var rows = scrollRows;
        if (index < 0 || index >= rows.length)
            return "";
        if (index > 0 && rows[index - 1].section === rows[index].section)
            return "";
        return rows[index].section === "known" ? "PAIRED" : "AVAILABLE";
    }

    function audioSinks() {
        var sinks = [];
        for (var i = 0; i < pipewireNodes.length; i++) {
            var node = pipewireNodes[i];
            if (node && node.isSink && !node.isStream)
                sinks.push(node);
        }
        return sinks;
    }

    function bluetoothAudioSink(device) {
        var sinks = audioSinks();
        for (var i = 0; i < sinks.length; i++) {
            if (Model.bluetoothSinkMatchesDevice(sinks[i], device))
                return sinks[i];
        }
        return null;
    }

    function setDefaultAudioSink(sink, address) {
        if (!sink)
            return;
        Pipewire.preferredDefaultAudioSink = sink;
        if (sink.id !== undefined && sink.name) {
            Quickshell.execDetached(["wpctl", "set-default", String(sink.id)]);
        }
        if (address)
            Quickshell.execDetached(["python3", "-I", "-B", Quickshell.env("HOME") + "/.config/quickshell/scripts/route_audio.py", address, sink.name || ""]);
    }

    function scheduleAudioOutputSwitch(device) {
        if (device && device.address)
            preferredAudioAddress = device.address;
        pendingAudioOutputDevice = {
            address: device && device.address ? device.address : "",
            name: device && device.name ? device.name : "",
            deviceName: device && device.deviceName ? device.deviceName : ""
        };
        pendingAudioOutputAttempts = 0;
        audioSwitchTimer.restart();
    }

    function switchPendingAudioOutput() {
        if (!pendingAudioOutputDevice)
            return;
        var connected = devices.some(function (device) {
            return device && device.address === root.pendingAudioOutputDevice.address && device.connected;
        });
        if (!connected) {
            pendingAudioOutputDevice = null;
            return;
        }

        var sink = bluetoothAudioSink(pendingAudioOutputDevice);
        if (sink) {
            setDefaultAudioSink(sink, pendingAudioOutputDevice.address);
            pendingAudioOutputDevice = null;
            audioSwitchTimer.stop();
            return;
        }

        pendingAudioOutputAttempts += 1;
        if (pendingAudioOutputAttempts >= 20) {
            pendingAudioOutputDevice = null;
            return;
        }
        audioSwitchTimer.restart();
    }

    function deviceAt(section, index) {
        var list = devicesForSection(section);
        return index >= 0 && index < list.length ? list[index] : null;
    }

    function cloneMap(map) {
        return Model.cloneMap(map);
    }

    function pendingAction(address) {
        return Model.pendingAction(pendingActions, address);
    }

    function setPendingAction(address, action) {
        if (!address)
            return;
        pendingActions = Model.withPendingAction(pendingActions, address, action);
        if (action)
            pendingTimeout.restart();
    }

    function deviceCommand(action, address) {
        return ["python3", "-B", Quickshell.env("HOME") + "/.config/quickshell/scripts/device.py", action, address];
    }

    function runDeviceAction(device, action, pending) {
        if (!device || !device.address)
            return;
        setPendingAction(device.address, pending);
        Quickshell.execDetached(deviceCommand(action, device.address));
    }

    function connectDevice(device) {
        if (!device || device.connected || pendingAction(device.address) === "connecting")
            return;
        if (Model.isAudioDevice(device) || bluetoothAudioSink(device))
            preferredAudioAddress = device.address;
        if (device.paired || device.bonded || device.trusted)
            runDeviceAction(device, "connect", "connecting");
        else
            runDeviceAction(device, "pair", "connecting");
    }

    function disconnectDevice(device) {
        if (!device || !device.address)
            return;
        if (!device.connected)
            return;
        setPendingAction(device.address, "disconnecting");
        if (device.disconnect)
            device.disconnect();
        Quickshell.execDetached(deviceCommand("disconnect", device.address));
    }

    function forgetDevice(device) {
        if (!device || !device.address)
            return;
        runDeviceAction(device, "forget", "forgetting");
    }

    function syncPendingActions() {
        var next = cloneMap(pendingActions);
        var changed = false;

        for (var address in next) {
            var action = next[address];
            var found = null;

            for (var i = 0; i < devices.length; i++) {
                var d = devices[i];
                if (d && d.address === address) {
                    found = d;
                    break;
                }
            }

            var finishedConnecting = action === "connecting" && found && found.connected;
            if (finishedConnecting || (action === "disconnecting" && found && !found.connected) || (action === "forgetting" && (!found || (!found.paired && !found.bonded && !found.trusted)))) {
                if (finishedConnecting)
                    scheduleAudioOutputSwitch(found);
                delete next[address];
                changed = true;
            }
        }

        if (changed)
            pendingActions = next;
    }

    function moveCursor(delta) {
        var sections = visibleSections;
        if (focusSection === "header") {
            if (delta > 0 && sections && sections.length > 0) {
                focusSection = sections[0];
                selectedIndex = 0;
                actionFocused = false;
            }
            return;
        }
        if (!sections || sections.length === 0) {
            focusSection = "header";
            actionFocused = false;
            return;
        }
        var sIdx = sections.indexOf(focusSection);
        if (sIdx < 0) {
            focusSection = sections[0];
            selectedIndex = 0;
            actionFocused = false;
            return;
        }

        var idx = selectedIndex;
        var max = sectionCount(focusSection) - 1;

        if (delta > 0) {
            if (idx < max) {
                selectedIndex = idx + 1;
                actionFocused = false;
                return;
            }
            if (sIdx < sections.length - 1) {
                focusSection = sections[sIdx + 1];
                selectedIndex = 0;
                actionFocused = false;
            }
        } else {
            if (idx > 0) {
                selectedIndex = idx - 1;
                actionFocused = false;
                return;
            }
            if (sIdx > 0) {
                focusSection = sections[sIdx - 1];
                selectedIndex = sectionCount(focusSection) - 1;
                actionFocused = false;
            } else {
                focusSection = "header";
                actionFocused = false;
            }
        }
    }

    function setHeaderCursor() {
        cursorActive = true;
        focusSection = "header";
        actionFocused = false;
    }

    function moveCursorH(delta) {
        if (!cursorActive) {
            cursorActive = true;
            return;
        }
        if (focusSection !== "known" && focusSection !== "connected")
            return;
        var dev = deviceAt(focusSection, selectedIndex);
        if (!dev || !dev.address)
            return;
        if (delta > 0)
            actionFocused = true;
        else if (delta < 0)
            actionFocused = false;
    }

    function activateCursor() {
        if (focusSection === "header") {
            toggleBluetooth();
            return;
        }
        if (actionFocused) {
            deleteSelected();
            return;
        }

        if (focusSection === "connected" || focusSection === "known") {
            var dev = deviceAt(focusSection, selectedIndex);
            if (!dev)
                return;
            if (dev.connected)
                disconnectDevice(dev);
            else
                connectDevice(dev);
            return;
        }
        if (focusSection === "discovered") {
            var d = discoveredDevices[selectedIndex];
            if (!d)
                return;
            connectDevice(d);
        }
    }

    function deleteSelected() {
        if (focusSection !== "known" && focusSection !== "connected")
            return;
        var dev = deviceAt(focusSection, selectedIndex);
        if (!dev)
            return;
        forgetDevice(dev);
    }

    onOpenedChanged: {
        if (opened) {
            if (adapter !== null && adapter.discovering)
                owesDiscoveryStop = true;
            if (connectedDevices.length > 0) {
                focusSection = "connected";
                selectedIndex = 0;
            } else if (knownDevices.length > 0) {
                focusSection = "known";
                selectedIndex = 0;
            } else if (discoveredDevices.length > 0) {
                focusSection = "discovered";
                selectedIndex = 0;
            } else {
                focusSection = "header";
            }
            actionFocused = false;
            cursorActive = false;
        }
    }

    function openSibling() {
        if (!bar || typeof bar.moduleWidgets !== "function")
            return null;
        var items = bar.moduleWidgets(moduleName);
        for (var i = 0; i < items.length; i++) {
            if (items[i] && items[i] !== root && (items[i].opened === true || items[i].embeddedOpened === true))
                return items[i];
        }
        return null;
    }

    function updateFocusedAddress() {
        var d = deviceAt(focusSection, selectedIndex);
        focusedDeviceAddress = d ? (d.address || "") : "";
    }

    function reselectFocusedDevice() {
        if (focusedDeviceAddress === "") {
            clampCursor();
            return;
        }

        var sections = ["connected", "known", "discovered"];
        for (var s = 0; s < sections.length; s++) {
            var section = sections[s];
            if (!sectionVisible(section))
                continue;
            var list = devicesForSection(section);
            for (var i = 0; i < list.length; i++) {
                if (list[i] && list[i].address === focusedDeviceAddress) {
                    focusSection = section;
                    selectedIndex = i;
                    clampCursor();
                    return;
                }
            }
        }

        clampCursor();
    }

    onSelectedIndexChanged: updateFocusedAddress()
    onFocusSectionChanged: updateFocusedAddress()
    onConnectedDevicesChanged: {
        reselectFocusedDevice();
        syncPendingActions();
    }
    onKnownDevicesChanged: {
        reselectFocusedDevice();
        syncPendingActions();
    }
    onDiscoveredDevicesChanged: {
        reselectFocusedDevice();
        syncPendingActions();
    }
    onVisibleSectionsChanged: clampCursor()

    function clampCursor() {
        var sections = visibleSections;
        if (focusSection === "header")
            return;
        if (!sections || !sections.length) {
            selectedIndex = 0;
            return;
        }
        if (sections.indexOf(focusSection) < 0) {
            focusSection = sections[0];
            selectedIndex = 0;
            return;
        }
        var count = sectionCount(focusSection);
        if (count === 0) {
            var sIdx = sections.indexOf(focusSection);
            focusSection = sIdx > 0 ? sections[sIdx - 1] : sections[0];
            selectedIndex = Math.max(0, sectionCount(focusSection) - 1);
            return;
        }
        if (selectedIndex > count - 1)
            selectedIndex = count - 1;
        if (selectedIndex < 0)
            selectedIndex = 0;
    }

    visible: adapter !== null

    Timer {
        id: discoveryRetry
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: (root.opened || root.embeddedOpened) && root.adapter !== null && root.adapter.enabled && !root.adapter.discovering
        onTriggered: {
            root.owesDiscoveryStop = true;
            root.adapter.discovering = true;
        }
    }

    Timer {
        id: discoveryStop
        interval: 1000
        repeat: true
        property int attempts: 0
        running: !root.opened && !root.embeddedOpened && root.owesDiscoveryStop && root.adapter !== null && root.adapter.discovering === true
        onRunningChanged: if (running)
            attempts = 0
        onTriggered: {
            var sibling = root.openSibling();
            if (sibling) {
                sibling.owesDiscoveryStop = true;
                root.owesDiscoveryStop = false;
                return;
            }
            attempts += 1;
            if (attempts > 3) {
                root.owesDiscoveryStop = false;
                return;
            }
            root.adapter.discovering = false;
        }
    }

    Connections {
        target: root.adapter
        function onDiscoveringChanged() {
            if (!root.adapter.discovering)
                root.owesDiscoveryStop = false;
        }
    }

    Component.onDestruction: {
        if (!owesDiscoveryStop)
            return;
        var items = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [];
        for (var i = 0; i < items.length; i++) {
            if (items[i] && items[i] !== root) {
                items[i].owesDiscoveryStop = true;
                return;
            }
        }
        if (adapter !== null && adapter.discovering)
            adapter.discovering = false;
    }

    Timer {
        id: pendingTimeout
        interval: 20000
        repeat: false
        onTriggered: root.pendingActions = ({})
    }

    Timer {
        id: audioSwitchTimer
        interval: 500
        repeat: false
        onTriggered: root.switchPendingAudioOutput()
    }

    Timer {
        id: phraseTimer
        interval: 2800
        running: root.opened && root.rotatingPhrases
        repeat: true
        onTriggered: phraseSwap.restart()
    }

    SequentialAnimation {
        id: phraseSwap
        PropertyAnimation {
            target: heroStatus
            property: "opacity"
            to: 0.0
            duration: 180
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
        }
        PropertyAnimation {
            target: heroStatus
            property: "opacity"
            to: 1.0
            duration: 260
            easing.type: Easing.InQuad
        }
    }

    Connections {
        target: root
        function onRotatingPhrasesChanged() {
            if (!root.rotatingPhrases) {
                phraseSwap.stop();
                heroStatus.opacity = 1.0;
            }
        }
    }

    function toggleBluetooth() {
        if (!adapter)
            return;
        if (adapter.enabled) {
            rememberPlayingPlayers();
            rememberConnectedAudio();
            resumeAudioAddress = preferredAudioAddress;
            resumeRequested = false;
            reconnectRequested = false;
            pendingAudioOutputDevice = null;
            pendingActions = ({});
            adapter.enabled = false;
        } else if (reconnectRequested) {
            reconnectRequested = false;
            pendingResumePlayers = [];
            resumeAudioAddress = "";
            resumeRequested = false;
            pendingAudioOutputDevice = null;
            pendingActions = ({});
            adapter.enabled = false;
        } else {
            reconnectAttempts = 0;
            reconnectRequested = true;
            resumeRequested = pendingResumePlayers.length > 0;
            adapter.enabled = true;
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(root.space(380))
        contentHeight: panel.fittedContentHeight(column.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onMoveRequested: function (dx, dy) {
                if (!root.cursorActive) {
                    root.cursorActive = true;
                    return;
                }
                if (dy !== 0)
                    root.moveCursor(dy);
                else if (dx !== 0)
                    root.moveCursorH(dx);
            }
            onActivateRequested: if (root.cursorActive)
                root.activateCursor()
            onCloseRequested: root.close()
            onTabRequested: function (direction) {
                root.switchPanel(direction);
            }
            onDeleteRequested: if (root.cursorActive)
                root.deleteSelected()
            onTextKey: function (t) {
                if (t === "b" || t === "B")
                    root.toggleBluetooth();
            }

            Column {
                id: column
                anchors.fill: parent
                spacing: root.space(14)

                Item {
                    width: parent.width
                    implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, powerSwitch.implicitHeight)

                    Text {
                        id: heroIcon
                        textFormat: Text.PlainText
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.icon
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: 36
                        opacity: root.adapter && root.adapter.enabled ? 1.0 : 0.5
                    }

                    ToggleSwitch {
                        id: powerSwitch
                        visible: !!root.adapter
                        checked: !!root.adapter && root.adapter.enabled
                        hasCursor: root.headerHasCursor
                        foreground: root.bar.foreground
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        property bool hoverActivated: false
                        onHovered: function (on) {
                            if (on)
                                root.setHeaderCursor();
                            else
                                powerSwitch.hoverActivated = false;
                        }
                        onToggled: {
                            powerSwitch.hoverActivated = true;
                            root.toggleBluetooth();
                        }

                        Timer {
                            interval: 180
                            running: root.opened && powerSwitch.visible && powerSwitch.containsMouse && !powerSwitch.hoverActivated
                            onTriggered: {
                                powerSwitch.hoverActivated = true;
                                root.toggleBluetooth();
                            }
                        }

                        PanelToolTip {
                            visible: powerSwitch.containsMouse
                            text: root.toggleHint
                            fontFamily: root.bar.fontFamily
                        }
                    }

                    Column {
                        id: heroLabels
                        anchors.left: heroIcon.right
                        anchors.leftMargin: root.space(14)
                        anchors.right: parent.right
                        anchors.rightMargin: powerSwitch.visible ? powerSwitch.width + root.space(12) : 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.space(2)

                        Text {
                            text: "Bluetooth"
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            id: heroStatus
                            textFormat: Text.PlainText
                            text: root.heroStatusText.toUpperCase()
                            color: Qt.darker(root.bar.foreground, 1.4)
                            font.family: root.bar.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                PanelSeparator {
                    foreground: root.bar.foreground
                }

                Column {
                    id: connectedList
                    visible: root.connectedDevices.length > 0
                    width: parent.width
                    spacing: root.space(10)

                    PanelSectionHeader {
                        text: "CONNECTED"
                        foreground: root.bar.foreground
                        fontFamily: root.bar.fontFamily
                    }

                    Repeater {
                        model: root.connectedRows
                        DeviceRow {
                            contextRoot: root
                            required property var modelData
                            required property int index
                            width: connectedList.width
                            dev: modelData
                            rowIndex: index
                            sectionName: "connected"
                            isDiscovered: false
                        }
                    }
                }

                PanelSeparator {
                    visible: root.connectedDevices.length > 0 && root.scrollRows.length > 0
                    foreground: root.bar.foreground
                }

                ListView {
                    id: deviceListView
                    width: parent.width
                    height: Math.min(contentHeight, root.space(400))
                    spacing: root.space(10)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    model: root.scrollRows
                    currentIndex: root.scrollRowIndex
                    onCurrentIndexChanged: if (currentIndex >= 0)
                        Qt.callLater(keepCurrentVisible)
                    function keepCurrentVisible() {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index
                        readonly property string sectionTitle: root.scrollSectionTitle(index)

                        width: ListView.view.width
                        height: delegateColumn.implicitHeight

                        Column {
                            id: delegateColumn
                            width: parent.width
                            spacing: root.space(10)

                            PanelSeparator {
                                visible: index > 0 && sectionTitle !== ""
                                height: visible ? implicitHeight : 0
                                foreground: root.bar.foreground
                            }

                            PanelSectionHeader {
                                visible: sectionTitle !== ""
                                height: visible ? implicitHeight : 0
                                text: sectionTitle
                                foreground: root.bar.foreground
                                fontFamily: root.bar.fontFamily
                            }

                            DeviceRow {
                                contextRoot: root
                                width: parent.width
                                dev: modelData.dev
                                rowIndex: modelData.indexInSection
                                sectionName: modelData.section
                                isDiscovered: modelData.section === "discovered"
                            }
                        }
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    visible: root.connectedDevices.length === 0 && root.scrollRows.length === 0
                    text: !root.adapter ? "No Bluetooth adapter" : !root.adapter.enabled ? "Turn Bluetooth on to scan" : "Scanning for devices…"
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }
        }
    }

    component DeviceRow: CursorSurface {
        id: deviceRowRow
        required property var contextRoot
        required property var dev
        required property int rowIndex
        required property string sectionName
        required property bool isDiscovered

        readonly property bool isConnected: dev && dev.connected
        readonly property int devState: dev && dev.state !== undefined ? dev.state : -1
        readonly property string action: contextRoot.pendingAction(dev ? dev.address : "")
        readonly property string actionTooltip: {
            if (!dev)
                return "";
            if (isConnected)
                return "Disconnect";
            if (isDiscovered)
                return "Pair";
            return "Connect";
        }

        readonly property bool rowSelected: contextRoot.cursorActive && contextRoot.focusSection === sectionName && contextRoot.selectedIndex === rowIndex
        readonly property bool forgetAvailable: (sectionName === "known" || sectionName === "connected") && !isDiscovered
        readonly property bool showForgetButton: forgetAvailable && (deviceRowRowMouse.containsMouse || rowSelected)

        hasCursor: rowSelected && !contextRoot.actionFocused
        current: isConnected
        foreground: contextRoot.bar.foreground
        fill: contextRoot.hoverFill
        currentFill: contextRoot.selectedFill

        readonly property string statusText: {
            if (!dev)
                return "";
            if (action === "forgetting")
                return "Forgetting…";
            if (action === "disconnecting" || devState === 2)
                return "Disconnecting…";
            if (isConnected) {
                if (dev.batteryAvailable)
                    return Math.round(dev.battery * 100) + "%";
                return sectionName === "connected" ? "" : "Connected";
            }
            if (action === "connecting" || devState === 3 || dev.pairing === true)
                return "Connecting…";
            if (isDiscovered)
                return "";
            return "";
        }

        readonly property color statusColor: {
            if (isConnected)
                return contextRoot.bar.foreground;
            if (action !== "" || devState === 3 || dev.pairing === true)
                return contextRoot.bar.foreground;
            return Qt.darker(contextRoot.bar.foreground, 1.5);
        }

        implicitHeight: deviceRowRowContent.implicitHeight + 16

        MouseArea {
            id: deviceRowRowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: deviceRowRow.dev ? Qt.PointingHandCursor : Qt.ArrowCursor

            onContainsMouseChanged: if (containsMouse) {
                contextRoot.cursorActive = true;
                contextRoot.focusSection = deviceRowRow.sectionName;
                contextRoot.selectedIndex = deviceRowRow.rowIndex;
                contextRoot.actionFocused = false;
            }

            onClicked: function (mouse) {
                var dev = contextRoot.deviceFor(deviceRowRow);
                if (!dev)
                    return;
                if (mouse.button === Qt.RightButton) {
                    if (deviceRowRow.isConnected)
                        contextRoot.disconnectDevice(dev);
                    else if (!deviceRowRow.isDiscovered)
                        contextRoot.forgetDevice(dev);
                    return;
                }
                if (deviceRowRow.isConnected)
                    contextRoot.disconnectDevice(dev);
                else
                    contextRoot.connectDevice(dev);
            }
        }

        PanelToolTip {
            visible: deviceRowRow.actionTooltip !== "" && deviceRowRowMouse.containsMouse && !contextRoot.actionFocused
            text: deviceRowRow.actionTooltip
            fontFamily: contextRoot.bar.fontFamily
        }

        Item {
            id: deviceRowRowContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: contextRoot.space(10)
            anchors.rightMargin: contextRoot.space(10)
            implicitHeight: Math.max(deviceRowDeviceIcon.implicitHeight, deviceRowInfo.implicitHeight, deviceRowForgetBtn.implicitHeight)

            Text {
                id: deviceRowDeviceIcon
                textFormat: Text.PlainText
                text: deviceRowRow.isConnected ? "󰂱" : "󰂯"
                color: deviceRowRow.statusColor
                font.family: contextRoot.bar.fontFamily
                font.pixelSize: 18
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                id: deviceRowInfo
                spacing: contextRoot.space(1)
                anchors.left: deviceRowDeviceIcon.right
                anchors.leftMargin: contextRoot.space(10)
                anchors.right: deviceRowForgetBtn.visible ? deviceRowForgetBtn.left : parent.right
                anchors.rightMargin: deviceRowForgetBtn.visible ? contextRoot.space(8) : 0
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    textFormat: Text.PlainText
                    text: contextRoot.deviceLabel(deviceRowRow.dev) || "Device"
                    color: contextRoot.bar.foreground
                    font.family: contextRoot.bar.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    textFormat: Text.PlainText
                    visible: deviceRowRow.statusText !== ""
                    text: deviceRowRow.statusText
                    color: deviceRowRow.statusColor
                    font.family: contextRoot.bar.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            PanelActionButton {
                id: deviceRowForgetBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: deviceRowRow.showForgetButton
                iconText: "󰅙"
                tooltipText: "Forget"
                foreground: contextRoot.bar.foreground
                hoverColor: contextRoot.bar.foreground
                fontFamily: contextRoot.bar.fontFamily
                hasCursor: deviceRowRow.rowSelected && contextRoot.actionFocused
                onHovered: function (isHovered) {
                    if (!isHovered) {
                        if (deviceRowRowMouse.containsMouse)
                            contextRoot.actionFocused = false;
                        return;
                    }
                    contextRoot.cursorActive = true;
                    contextRoot.focusSection = deviceRowRow.sectionName;
                    contextRoot.selectedIndex = deviceRowRow.rowIndex;
                    contextRoot.actionFocused = true;
                }
                onClicked: {
                    var dev = contextRoot.deviceFor(deviceRowRow);
                    if (!dev)
                        return;
                    contextRoot.forgetDevice(dev);
                }
            }
        }
    }

    component QuickView: Column {
        id: bluetoothQuickViewRoot
        required property var backend
        readonly property var adapter: backend ? backend.adapter : null
        readonly property var rows: backend && adapter && adapter.enabled ? (backend.connectedRows || []).concat((backend.scrollRows || []).map(function (row) {
            return row.dev;
        })) : []
        spacing: 8
        function activate(row) {
            if (!backend || backend.pendingAction(row.address))
                return;
            var device = backend.deviceFor({
                dev: row
            });
            if (!device)
                return;
            if (device.connected)
                backend.disconnectDevice(device);
            else
                backend.connectDevice(device);
        }
        Item {
            width: parent.width
            height: 30
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                color: "#e8dff1"
                font.family: "sans-serif"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            ToggleSwitch {
                id: bluetoothQuickViewPower
                objectName: "audioBluetoothPower"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: !!bluetoothQuickViewRoot.adapter && bluetoothQuickViewRoot.adapter.enabled
                enabled: !!bluetoothQuickViewRoot.adapter
                activeFocusOnTab: true
                Accessible.role: Accessible.CheckBox
                Accessible.name: "Bluetooth power"
                Accessible.checked: checked
                onToggled: bluetoothQuickViewRoot.backend.toggleBluetooth()
                Keys.onSpacePressed: bluetoothQuickViewRoot.backend.toggleBluetooth()
                Keys.onReturnPressed: bluetoothQuickViewRoot.backend.toggleBluetooth()
            }
        }
        ListView {
            id: bluetoothQuickViewList
            objectName: "audioBluetoothList"
            width: parent.width
            height: Math.min(contentHeight, 190)
            visible: count > 0
            model: bluetoothQuickViewRoot.rows
            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: Rectangle {
                id: bluetoothQuickViewDeviceRow
                required property var modelData
                required property int index
                readonly property string pending: bluetoothQuickViewRoot.backend ? bluetoothQuickViewRoot.backend.pendingAction(modelData.address) : ""
                readonly property string status: pending === "connecting" || modelData.pairing ? "Connecting…" : pending === "disconnecting" ? "Disconnecting…" : modelData.connected && modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                objectName: "audioBluetoothDevice-" + index
                width: bluetoothQuickViewList.width
                height: status ? 52 : 40
                radius: 9
                color: modelData.connected ? "#383044" : bluetoothQuickViewHit.containsMouse || activeFocus ? "#2a2531" : "transparent"
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: (modelData.deviceName || modelData.name) + (modelData.connected ? ", disconnect" : ", connect")
                Keys.onReturnPressed: bluetoothQuickViewRoot.activate(modelData)
                Keys.onSpacePressed: bluetoothQuickViewRoot.activate(modelData)
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf293"
                    color: bluetoothQuickViewDeviceRow.modelData.connected ? "#c3b7ff" : "#8f829a"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 15
                }
                Column {
                    x: 36
                    width: parent.width - 68
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        width: parent.width
                        text: bluetoothQuickViewDeviceRow.modelData.deviceName || bluetoothQuickViewDeviceRow.modelData.name
                        textFormat: Text.PlainText
                        color: "#e5dcec"
                        font.family: "sans-serif"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: !!bluetoothQuickViewDeviceRow.status
                        text: bluetoothQuickViewDeviceRow.status
                        color: "#a69ab2"
                        font.family: "sans-serif"
                        font.pixelSize: 9
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: bluetoothQuickViewDeviceRow.pending ? "…" : bluetoothQuickViewDeviceRow.modelData.connected ? "✓" : "›"
                    color: "#c3b7ff"
                    font.pixelSize: 14
                }
                MouseArea {
                    id: bluetoothQuickViewHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bluetoothQuickViewRoot.activate(bluetoothQuickViewDeviceRow.modelData)
                }
            }
        }
        Text {
            width: parent.width
            visible: !bluetoothQuickViewRoot.adapter || (bluetoothQuickViewRoot.adapter.enabled && bluetoothQuickViewRoot.rows.length === 0)
            text: !bluetoothQuickViewRoot.adapter ? "No Bluetooth adapter" : bluetoothQuickViewRoot.adapter.discovering ? "Searching for devices…" : "No devices available"
            color: "#928b96"
            font.family: "sans-serif"
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
    }
}
