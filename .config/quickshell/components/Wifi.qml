import "../controls/PanelTheme.js" as Theme
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../controls"
import QtQuick.Controls

Item {
    id: root
    property bool opened: false
    signal backRequested
    signal panelRequested(string panel)
    property var state: ({
            available: false,
            enabled: false,
            blocked: false,
            device: "",
            connected: "",
            ipv4: "",
            networks: []
        })
    property string error: ""
    property var passwordNetwork: null
    property var pendingNetwork: null
    property string actionPayload: ""
    property string lastAction: ""
    property bool powerPending: false
    property bool requestedPower: false
    property int powerRevision: 0
    property int discoveryAttempts: 0
    readonly property bool busy: action.running
    readonly property bool refreshing: query.running || discoveryAttempts > 0
    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/network.py"
    Component.onCompleted: refresh()
    function open() {
        opened = true;
        state = Object.assign({}, state, {
            networks: []
        });
        discoveryAttempts = 8;
        refresh();
    }
    function close() {
        opened = false;
        passwordNetwork = null;
        discoveryAttempts = 0;
    }
    function toggle() {
        if (opened)
            close();
        else
            open();
    }
    function refresh() {
        if (query.running || action.running)
            return;
        query.stdinEnabled = true;
        query.running = true;
    }
    function request(payload) {
        if (action.running)
            return;
        error = "";
        lastAction = payload.action;
        actionPayload = JSON.stringify(payload) + "\n";
        action.stdinEnabled = true;
        action.running = true;
    }
    function setPower(enabled) {
        if (busy)
            return;
        passwordNetwork = null;
        requestedPower = enabled;
        powerPending = true;
        powerRevision += 1;
        discoveryAttempts = enabled ? 8 : 0;
        request({
            action: "power",
            enabled: enabled
        });
    }
    function scan() {
        request({
            action: "scan",
            device: state.device
        });
    }
    function setDns(provider) {
        request({
            action: "dns",
            device: state.device,
            provider: provider
        });
    }
    function setBand(mode) {
        passwordNetwork = null;
        request({
            action: "band",
            device: state.device,
            mode: mode
        });
    }
    function connectNetwork(network, password) {
        if (busy || !state.enabled)
            return;
        pendingNetwork = network;
        var payload = {
            action: "connect",
            device: state.device,
            ssid: network.ssid,
            bssid: network.bssid
        };
        if (password !== undefined)
            payload.password = password;
        request(payload);
    }
    function submitPassword(password) {
        if (passwordNetwork)
            connectNetwork(passwordNetwork, password);
    }
    function forget(ssid) {
        if (busy || !ssid)
            return;
        passwordNetwork = null;
        request({
            action: "forget",
            ssid: ssid
        });
    }
    function disconnect() {
        request({
            action: "disconnect",
            device: state.device
        });
    }
    function cancelPassword() {
        passwordNetwork = null;
        error = "";
    }
    function actionResult(raw) {
        try {
            var result = JSON.parse(raw);
            if (result.ok) {
                if (lastAction === "power") {
                    state = Object.assign({}, state, {
                        enabled: requestedPower
                    }, requestedPower ? {} : {
                        connected: "",
                        ipv4: "",
                        networks: []
                    });
                    powerPending = false;
                }
                passwordNetwork = null;
                error = "";
            } else if (result.requiresPassword && pendingNetwork) {
                if (pendingNetwork.security.indexOf("802.1X") >= 0)
                    error = "Enterprise networks need a configured system connection.";
                else {
                    passwordNetwork = pendingNetwork;
                    error = "";
                }
            } else {
                if (lastAction === "power") {
                    powerPending = false;
                    discoveryAttempts = 0;
                }
                error = result.error || "The Wi-Fi action failed.";
            }
        } catch (exception) {
            powerPending = false;
            discoveryAttempts = 0;
            error = "Could not complete the Wi-Fi request.";
        }
    }
    Process {
        id: query
        property int revision: 0
        command: ["python3", "-I", "-B", root.script]
        onStarted: {
            revision = root.powerRevision;
            write(JSON.stringify({
                action: "state",
                profileUuid: root.state.profileUuid || "",
                rescan: root.discoveryAttempts > 0
            }) + "\n");
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (query.revision !== root.powerRevision || root.powerPending)
                    return;
                try {
                    var result = JSON.parse(text);
                    if (result.ok) {
                        var becameEnabled = !root.state.enabled && result.state.enabled;
                        root.state = result.state;
                        if (becameEnabled && !root.busy && root.discoveryAttempts === 0 && root.opened)
                            root.discoveryAttempts = 8;
                        if (root.discoveryAttempts > 0) {
                            if (!root.state.available || root.state.blocked || root.state.networks.length > 0)
                                root.discoveryAttempts = 0;
                            else
                                root.discoveryAttempts -= 1;
                        }
                    } else if (root.discoveryAttempts > 0) {
                        root.discoveryAttempts -= 1;
                        if (root.discoveryAttempts === 0)
                            root.error = result.error || "Could not read Wi-Fi status.";
                    } else
                        root.error = result.error || "Could not read Wi-Fi status.";
                } catch (exception) {
                    if (root.discoveryAttempts > 0)
                        root.discoveryAttempts -= 1;
                    else
                        root.error = "Could not read Wi-Fi status.";
                }
            }
        }
        onExited: if (root.discoveryAttempts > 0 && root.opened)
            discoveryRetry.restart()
    }
    Process {
        id: action
        command: ["python3", "-I", "-B", root.script]
        onStarted: {
            write(root.actionPayload);
            root.actionPayload = "";
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: root.actionResult(text)
        }
        onExited: refreshDelay.restart()
    }
    Timer {
        id: discoveryRetry
        interval: 1000
        onTriggered: if (root.discoveryAttempts > 0 && root.opened)
            root.refresh()
    }
    Timer {
        id: refreshDelay
        interval: 150
        onTriggered: root.refresh()
    }
    Timer {
        interval: 10000
        running: root.opened
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 20000
        running: root.opened && root.state.enabled && !root.state.blocked && !root.busy
        repeat: true
        onTriggered: root.scan()
    }
    IpcHandler {
        target: "wifi"
        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
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
        WlrLayershell.namespace: "wifi"
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
            currentPanel: "wifi"
            onSelected: function (panel) {
                root.panelRequested(panel);
            }
        }
        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(56, (panel.height - 560) / 2)
            width: Math.min(440, panel.width - 32)
            height: Math.min(view.implicitHeight + 40, panel.height - 112)
            radius: Theme.panelRadius
            gradient: PanelGradient {}
            border.width: 1
            border.color: Theme.border
            PanelAura { radius: parent.radius }
            focus: true
            Keys.onEscapePressed: {
                if (root.passwordNetwork)
                    root.cancelPassword();
                else if (view.selectedSsid.length > 0)
                    view.selectedSsid = "";
                else
                    root.close();
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            WifiView {
                id: view
                anchors.fill: parent
                anchors.margins: 20
                backend: root
            }
        }
    }
    component WifiView: Item {
        id: wifiViewRoot
        required property var backend
        readonly property color accentColor: Theme.accent
        readonly property color successColor: "#a9c4a0"
        readonly property color dangerColor: "#d9737f"
        readonly property string iconFont: "JetBrainsMono Nerd Font"
        readonly property bool powerOn: backend.powerPending ? backend.requestedPower : !!backend.state.enabled
        readonly property bool listVisible: backend.state.available && backend.state.enabled && !backend.state.blocked
        readonly property bool settingsVisible: listVisible && !!backend.state.connected
        property string search: ""
        property string selectedSsid: ""
        property bool showPassword: false
        readonly property var networks: (backend.state.networks || []).filter(function (network) {
            return !wifiViewRoot.search || network.ssid.toLowerCase().indexOf(wifiViewRoot.search.toLowerCase()) >= 0;
        })
        implicitHeight: Math.min(wifiViewContent.implicitHeight, 600)
        function signalGlyph(percent) {
            if (percent >= 75)
                return "󰤨";
            if (percent >= 50)
                return "󰤥";
            if (percent >= 25)
                return "󰤢";
            if (percent > 0)
                return "󰤟";
            return "󰤯";
        }
        function subtitle() {
            if (backend.powerPending)
                return backend.requestedPower ? "TURNING ON…" : "TURNING OFF…";
            if (backend.refreshing && !backend.state.available)
                return "SCANNING…";
            if (!backend.state.available)
                return "NO ADAPTER DETECTED";
            if (backend.state.blocked)
                return "BLOCKED BY HARDWARE SWITCH";
            if (!backend.state.enabled)
                return "WI-FI IS OFF";
            if ((backend.state.networks || []).length === 0 && backend.refreshing)
                return "SCANNING…";
            return (backend.state.networks || []).length + " NETWORKS IN RANGE";
        }
        function activity() {
            if (!backend.busy)
                return "";
            var labels = {
                scan: "SCANNING…",
                connect: "CONNECTING…",
                disconnect: "DISCONNECTING…",
                band: "SWITCHING BAND…",
                dns: "UPDATING DNS…",
                forget: "FORGETTING…",
                power: "UPDATING…"
            };
            return labels[backend.lastAction] || "UPDATING…";
        }
        function cancelPrompt() {
            wifiViewRoot.selectedSsid = "";
            wifiViewRoot.showPassword = false;
            if (backend.passwordNetwork)
                backend.cancelPassword();
        }
        Connections {
            target: wifiViewRoot.backend
            function onPasswordNetworkChanged() {
                if (wifiViewRoot.backend.passwordNetwork)
                    wifiViewRoot.selectedSsid = wifiViewRoot.backend.passwordNetwork.ssid;
                else
                    wifiViewRoot.selectedSsid = "";
            }
            function onStateChanged() {
                if (wifiViewRoot.selectedSsid && wifiViewRoot.backend.state.connected === wifiViewRoot.selectedSsid)
                    wifiViewRoot.selectedSsid = "";
                if (!wifiViewRoot.backend.opened) {
                    wifiViewRoot.selectedSsid = "";
                    wifiViewRoot.search = "";
                    wifiViewRoot.showPassword = false;
                    wifiViewSearchInput.clear();
                }
            }
            function onOpenedChanged() {
                if (!wifiViewRoot.backend.opened) {
                    wifiViewRoot.selectedSsid = "";
                    wifiViewRoot.search = "";
                    wifiViewRoot.showPassword = false;
                    wifiViewSearchInput.clear();
                }
            }
        }
        ScrollView {
            id: wifiViewScroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Column {
                id: wifiViewContent
                width: wifiViewScroll.availableWidth
                spacing: 14
                Item {
                    width: parent.width
                    height: 42
                    Column {
                        anchors.left: parent.left
                        anchors.right: wifiViewHeaderActions.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            text: "WIFI NETWORKS"
                            color: Theme.accent
                            font.family: "sans-serif"
                            font.pixelSize: 14
                            font.letterSpacing: 2
                            font.weight: Font.Black
                        }
                        Text {
                            width: parent.width
                            text: wifiViewRoot.subtitle()
                            textFormat: Text.PlainText
                            color: Theme.dim
                            font.family: "sans-serif"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                            elide: Text.ElideRight
                        }
                    }
                    Row {
                        id: wifiViewHeaderActions
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        WifiIconButton {
                            label: "Refresh networks"
                            glyph: "󰑐"
                            enabled: wifiViewRoot.powerOn && !wifiViewRoot.backend.busy && !wifiViewRoot.backend.refreshing
                            onClicked: wifiViewRoot.backend.scan()
                            RotationAnimation on rotation {
                                running: wifiViewRoot.backend.refreshing
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }
                        WifiIconButton {
                            objectName: "wifiPower"
                            label: "Wi-Fi power"
                            glyph: "󰖩"
                            active: wifiViewRoot.powerOn
                            enabled: wifiViewRoot.backend.state.available && !wifiViewRoot.backend.state.blocked && !wifiViewRoot.backend.busy
                            onClicked: wifiViewRoot.backend.setPower(!wifiViewRoot.powerOn)
                        }
                        WifiIconButton {
                            label: "Close"
                            glyph: "󰅖"
                            onClicked: wifiViewRoot.backend.close()
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 62
                    radius: 18
                    visible: !!wifiViewRoot.backend.state.connected
                    color: Qt.rgba(wifiViewRoot.accentColor.r, wifiViewRoot.accentColor.g, wifiViewRoot.accentColor.b, 0.1)
                    border.width: 1
                    border.color: Qt.rgba(wifiViewRoot.accentColor.r, wifiViewRoot.accentColor.g, wifiViewRoot.accentColor.b, 0.3)
                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14
                        Rectangle {
                            width: 38
                            height: 38
                            radius: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(wifiViewRoot.successColor.r, wifiViewRoot.successColor.g, wifiViewRoot.successColor.b, 0.2)
                            Text {
                                anchors.centerIn: parent
                                text: "󰤨"
                                color: wifiViewRoot.successColor
                                font.family: wifiViewRoot.iconFont
                                font.pixelSize: 20
                            }
                        }
                        Column {
                            width: parent.width - 38 - 14 - wifiViewDisconnect.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: wifiViewRoot.backend.state.connected
                                textFormat: Text.PlainText
                                color: Theme.foreground
                                font.family: "sans-serif"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: wifiViewRoot.backend.state.ipv4 ? "IP: " + wifiViewRoot.backend.state.ipv4 : "Connected"
                                textFormat: Text.PlainText
                                color: Theme.dim
                                font.family: "sans-serif"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            id: wifiViewDisconnect
                            objectName: "disconnectNetwork"
                            width: 86
                            height: 34
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: !wifiViewRoot.backend.busy
                            opacity: enabled ? 1 : 0.4
                            color: Qt.rgba(wifiViewRoot.dangerColor.r, wifiViewRoot.dangerColor.g, wifiViewRoot.dangerColor.b, 0.15)
                            border.width: 1
                            border.color: wifiViewRoot.dangerColor
                            Text {
                                anchors.centerIn: parent
                                text: "DISCONNECT"
                                color: wifiViewRoot.dangerColor
                                font.family: "sans-serif"
                                font.pixelSize: 9
                                font.weight: Font.Black
                                font.letterSpacing: 0.4
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: wifiViewDisconnect.enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiViewRoot.backend.disconnect()
                            }
                        }
                    }
                }
                Column {
                    width: parent.width
                    spacing: 6
                    visible: wifiViewRoot.settingsVisible
                    Text {
                        text: "BAND"
                        color: Theme.muted
                        font.family: "sans-serif"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        font.letterSpacing: 1.2
                    }
                    Row {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: [
                                {
                                    mode: "bg",
                                    label: "2.4 GHz"
                                },
                                {
                                    mode: "a",
                                    label: "5 GHz"
                                },
                                {
                                    mode: "",
                                    label: "AUTO"
                                }
                            ]
                            WifiChip {
                                required property var modelData
                                width: (parent.width - 12) / 3
                                label: modelData.label
                                selected: (wifiViewRoot.backend.state.bandMode || "") === modelData.mode
                                enabled: !wifiViewRoot.backend.busy && (!modelData.mode || (wifiViewRoot.backend.state.availableBands || []).indexOf(modelData.mode) >= 0)
                                objectName: "band-" + (modelData.mode || "auto")
                                onClicked: wifiViewRoot.backend.setBand(modelData.mode)
                            }
                        }
                    }
                    Text {
                        text: "DNS"
                        color: Theme.muted
                        font.family: "sans-serif"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        font.letterSpacing: 1.2
                    }
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: [
                                {
                                    key: "automatic",
                                    label: "AUTO"
                                },
                                {
                                    key: "adguard",
                                    label: "ADGUARD"
                                },
                                {
                                    key: "quad9",
                                    label: "QUAD9"
                                },
                                {
                                    key: "cloudflare",
                                    label: "CLOUDFLARE"
                                },
                                {
                                    key: "google",
                                    label: "GOOGLE"
                                }
                            ]
                            WifiChip {
                                required property var modelData
                                label: modelData.label
                                selected: (wifiViewRoot.backend.state.dnsMode || "automatic") === modelData.key
                                enabled: !wifiViewRoot.backend.busy
                                objectName: "dns-" + modelData.key
                                onClicked: wifiViewRoot.backend.setDns(modelData.key)
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: wifiViewError.implicitHeight + 20
                    radius: 12
                    visible: !!wifiViewRoot.backend.error
                    color: Qt.rgba(wifiViewRoot.dangerColor.r, wifiViewRoot.dangerColor.g, wifiViewRoot.dangerColor.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(wifiViewRoot.dangerColor.r, wifiViewRoot.dangerColor.g, wifiViewRoot.dangerColor.b, 0.4)
                    Text {
                        id: wifiViewError
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 10
                        text: wifiViewRoot.backend.error
                        textFormat: Text.PlainText
                        color: wifiViewRoot.dangerColor
                        font.family: "sans-serif"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
                Column {
                    id: wifiViewNetworkSection
                    objectName: "networkSection"
                    width: parent.width
                    spacing: 8
                    visible: wifiViewRoot.listVisible
                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "NETWORKS"
                            color: Theme.muted
                            font.family: "sans-serif"
                            font.pixelSize: 9
                            font.weight: Font.Black
                            font.letterSpacing: 1.2
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: wifiViewRoot.activity().length > 0
                            text: wifiViewRoot.activity()
                            color: Theme.accent
                            font.family: "sans-serif"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                        }
                    }
                    TextField {
                        id: wifiViewSearchInput
                        objectName: "networkSearch"
                        width: parent.width
                        height: 32
                        visible: (wifiViewRoot.backend.state.networks || []).length > 4 || wifiViewRoot.search.length > 0
                        placeholderText: "Search networks"
                        color: Theme.foreground
                        placeholderTextColor: Theme.dim
                        font.family: "sans-serif"
                        font.pixelSize: 11
                        Accessible.name: "Search networks"
                        background: Rectangle {
                            radius: 9
                            color: Theme.background
                            border.width: 1
                            border.color: wifiViewSearchInput.activeFocus ? Theme.accent : Theme.border
                        }
                        onTextEdited: wifiViewRoot.search = text
                    }
                    Column {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: wifiViewRoot.networks
                            Rectangle {
                                id: wifiViewNetwork
                                required property var modelData
                                readonly property bool active: !!modelData.active
                                readonly property bool known: !!modelData.known
                                readonly property bool promptOpen: wifiViewRoot.selectedSsid === modelData.ssid
                                readonly property bool expanded: promptOpen && (!!wifiViewRoot.backend.passwordNetwork || !known)
                                width: parent.width
                                height: expanded ? 108 : 60
                                radius: 16
                                color: active ? Qt.rgba(wifiViewRoot.accentColor.r, wifiViewRoot.accentColor.g, wifiViewRoot.accentColor.b, 0.18) : (wifiViewNetworkHit.containsMouse || activeFocus ? Theme.hover : Theme.surface)
                                border.width: 1
                                border.color: active ? wifiViewRoot.successColor : (expanded || activeFocus ? Theme.accent : Theme.border)
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.ssid + (active ? ", connected" : known ? ", saved" : "")
                                Behavior on height {
                                    NumberAnimation {
                                        duration: 160
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 140
                                    }
                                }
                                function activate() {
                                    if (wifiViewRoot.backend.busy)
                                        return;
                                    if (active) {
                                        wifiViewRoot.cancelPrompt();
                                        return;
                                    }
                                    if (known || !modelData.secured) {
                                        wifiViewRoot.cancelPrompt();
                                        wifiViewRoot.backend.connectNetwork(modelData);
                                        return;
                                    }
                                    wifiViewRoot.showPassword = false;
                                    wifiViewRoot.selectedSsid = promptOpen ? "" : modelData.ssid;
                                }
                                Keys.onReturnPressed: activate()
                                Keys.onSpacePressed: activate()
                                MouseArea {
                                    id: wifiViewNetworkHit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiViewNetwork.activate()
                                }
                                Item {
                                    id: wifiViewNetworkRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    height: 36
                                    Text {
                                        id: wifiViewSignal
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 30
                                        horizontalAlignment: Text.AlignHCenter
                                        text: wifiViewRoot.signalGlyph(modelData.signal)
                                        color: wifiViewNetwork.active ? wifiViewRoot.successColor : Theme.foreground
                                        font.family: wifiViewRoot.iconFont
                                        font.pixelSize: 22
                                    }
                                    Row {
                                        id: wifiViewNetworkActions
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.signal + "%"
                                            color: wifiViewNetwork.active ? wifiViewRoot.successColor : Theme.dim
                                            font.family: "sans-serif"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }
                                        Rectangle {
                                            width: 32
                                            height: 32
                                            radius: 10
                                            visible: wifiViewNetwork.known
                                            color: wifiViewForgetHit.containsMouse ? Qt.rgba(wifiViewRoot.dangerColor.r, wifiViewRoot.dangerColor.g, wifiViewRoot.dangerColor.b, 0.25) : Qt.rgba(wifiViewRoot.dangerColor.r, wifiViewRoot.dangerColor.g, wifiViewRoot.dangerColor.b, 0.15)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰆴"
                                                color: wifiViewRoot.dangerColor
                                                font.family: wifiViewRoot.iconFont
                                                font.pixelSize: 17
                                            }
                                            MouseArea {
                                                id: wifiViewForgetHit
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: wifiViewRoot.backend.forget(modelData.ssid)
                                            }
                                        }
                                        Rectangle {
                                            width: 74
                                            height: 32
                                            radius: 10
                                            visible: wifiViewNetwork.known && !wifiViewNetwork.active
                                            enabled: !wifiViewRoot.backend.busy
                                            opacity: enabled ? 1 : 0.4
                                            color: wifiViewConnectHit.containsMouse ? Theme.accentAlt : Theme.accent
                                            Text {
                                                anchors.centerIn: parent
                                                text: "CONNECT"
                                                color: Theme.background
                                                font.family: "sans-serif"
                                                font.pixelSize: 9
                                                font.weight: Font.Black
                                                font.letterSpacing: 0.4
                                            }
                                            MouseArea {
                                                id: wifiViewConnectHit
                                                anchors.fill: parent
                                                enabled: parent.enabled
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: wifiViewRoot.backend.connectNetwork(modelData)
                                            }
                                        }
                                        Rectangle {
                                            width: 32
                                            height: 32
                                            radius: 10
                                            visible: !wifiViewNetwork.known && !wifiViewNetwork.active
                                            color: Qt.rgba(0.902, 0.843, 0.863, 0.08)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅂"
                                                color: Theme.foreground
                                                font.family: wifiViewRoot.iconFont
                                                font.pixelSize: 15
                                                rotation: wifiViewNetwork.expanded ? 90 : 0
                                                Behavior on rotation {
                                                    NumberAnimation {
                                                        duration: 160
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: wifiViewNetwork.activate()
                                            }
                                        }
                                    }
                                    Column {
                                        anchors.left: wifiViewSignal.right
                                        anchors.leftMargin: 10
                                        anchors.right: wifiViewNetworkActions.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            text: modelData.ssid
                                            textFormat: Text.PlainText
                                            color: Theme.foreground
                                            font.family: "sans-serif"
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: wifiViewNetwork.active ? "ACTIVE" : wifiViewNetwork.known ? "SAVED" : "SIGNAL " + modelData.signal + "%"
                                            textFormat: Text.PlainText
                                            color: wifiViewNetwork.active ? wifiViewRoot.successColor : Theme.dim
                                            font.family: "sans-serif"
                                            font.pixelSize: 9
                                            font.weight: Font.Black
                                            font.letterSpacing: 0.5
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                                Row {
                                    id: wifiViewPasswordRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 12
                                    height: 34
                                    visible: wifiViewNetwork.expanded
                                    spacing: 8
                                    TextField {
                                        id: wifiViewPassword
                                        objectName: "networkPassword"
                                        width: parent.width - 34 - 80 - 16
                                        height: 34
                                        echoMode: wifiViewRoot.showPassword ? TextInput.Normal : TextInput.Password
                                        maximumLength: 256
                                        placeholderText: "Enter Wi-Fi password"
                                        color: Theme.foreground
                                        placeholderTextColor: Theme.dim
                                        font.family: "sans-serif"
                                        font.pixelSize: 12
                                        leftPadding: 10
                                        rightPadding: 10
                                        enabled: !wifiViewRoot.backend.busy
                                        Accessible.name: "Network password"
                                        background: Rectangle {
                                            radius: 10
                                            color: Theme.background
                                            border.width: 1
                                            border.color: wifiViewPassword.activeFocus ? Theme.accent : Theme.border
                                        }
                                        onVisibleChanged: {
                                            if (visible)
                                                Qt.callLater(function () {
                                                    wifiViewPassword.forceActiveFocus();
                                                });
                                            else
                                                wifiViewPassword.clear();
                                        }
                                        onAccepted: {
                                            if (wifiViewPassword.text && !wifiViewRoot.backend.busy)
                                                wifiViewRoot.backend.submitPassword(wifiViewPassword.text);
                                        }
                                    }
                                    Rectangle {
                                        width: 34
                                        height: 34
                                        radius: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: wifiViewPasswordEye.containsMouse ? Theme.hover : "transparent"
                                        border.width: 1
                                        border.color: Theme.border
                                        Text {
                                            anchors.centerIn: parent
                                            text: wifiViewRoot.showPassword ? "󰈈" : "󰈉"
                                            color: Theme.foreground
                                            font.family: wifiViewRoot.iconFont
                                            font.pixelSize: 16
                                        }
                                        MouseArea {
                                            id: wifiViewPasswordEye
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wifiViewRoot.showPassword = !wifiViewRoot.showPassword
                                        }
                                    }
                                    Rectangle {
                                        width: 80
                                        height: 34
                                        radius: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        enabled: wifiViewPassword.text.length > 0 && !wifiViewRoot.backend.busy
                                        opacity: enabled ? 1 : 0.4
                                        color: enabled && wifiViewJoinHit.containsMouse ? Theme.accentAlt : Theme.accent
                                        Text {
                                            anchors.centerIn: parent
                                            text: "JOIN"
                                            color: Theme.background
                                            font.family: "sans-serif"
                                            font.pixelSize: 10
                                            font.weight: Font.Black
                                            font.letterSpacing: 0.8
                                        }
                                        MouseArea {
                                            id: wifiViewJoinHit
                                            anchors.fill: parent
                                            enabled: parent.enabled
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wifiViewRoot.backend.submitPassword(wifiViewPassword.text)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: wifiViewRoot.networks.length === 0 && !wifiViewRoot.backend.refreshing && !wifiViewRoot.backend.busy
                        text: wifiViewRoot.search.length > 0 ? "No networks match this search." : "No networks in range. Try refreshing."
                        color: Theme.dim
                        font.family: "sans-serif"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
                Text {
                    width: parent.width
                    visible: !wifiViewRoot.listVisible
                    text: wifiViewRoot.backend.refreshing ? "Scanning for networks…" : !wifiViewRoot.backend.state.available ? "No Wi-Fi adapter was detected." : wifiViewRoot.backend.state.blocked ? "Enable wireless using your computer's hardware switch." : "Turn on Wi-Fi to see nearby networks."
                    color: Theme.dim
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
