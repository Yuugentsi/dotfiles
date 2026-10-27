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
    function open() {
        opened = true;
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
            color: "#ac080e16"
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
            radius: 20
            color: "#1d1b22"
            border.width: 1
            border.color: "#3c3545"
            focus: true
            Keys.onEscapePressed: {
                if (root.passwordNetwork)
                    root.cancelPassword();
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

    component DnsPicker: Item {
        id: dnsPickerRoot
        property string mode: "automatic"
        property bool expanded: false
        property bool busy: false
        property bool canSelect: true
        property bool pointerOwned: false
        property bool hoverArmed: true
        onExpandedChanged: if (!expanded)
            pointerOwned = false
        HoverHandler {
            id: dnsPickerPickerHover
            onHoveredChanged: {
                if (hovered)
                    dnsPickerRoot.pointerOwned = true;
                else
                    dnsPickerRoot.hoverArmed = true;
            }
        }
        Timer {
            interval: 160
            running: dnsPickerHeaderHit.containsMouse && dnsPickerRoot.hoverArmed && !dnsPickerRoot.expanded && !dnsPickerRoot.busy
            onTriggered: {
                if (!dnsPickerRoot.expanded) {
                    dnsPickerRoot.hoverArmed = false;
                    dnsPickerRoot.pointerOwned = true;
                    dnsPickerRoot.toggleRequested();
                }
            }
        }
        Timer {
            interval: 220
            running: dnsPickerRoot.expanded && dnsPickerRoot.pointerOwned && !dnsPickerPickerHover.hovered
            onTriggered: if (dnsPickerRoot.expanded)
                dnsPickerRoot.toggleRequested()
        }
        signal toggleRequested
        signal selected(string provider)
        readonly property var providers: [
            {
                key: "adguard",
                label: "AdGuard",
                address: "94.140.14.14",
                glyph: "\uf132"
            },
            {
                key: "quad9",
                label: "Quad9",
                address: "9.9.9.9",
                glyph: "\uf233"
            },
            {
                key: "cloudflare",
                label: "Cloudflare",
                address: "1.1.1.1",
                glyph: "\uf0c2"
            },
            {
                key: "google",
                label: "Google",
                address: "8.8.8.8",
                glyph: "\uf0ac"
            }
        ]
        readonly property string modeLabel: ({
                automatic: "Auto",
                adguard: "AdGuard",
                quad9: "Quad9",
                cloudflare: "Cloudflare",
                google: "Google",
                custom: "Custom"
            })[mode] || "Custom"
        implicitHeight: dnsPickerLayout.implicitHeight + 28
        height: implicitHeight

        Rectangle {
            anchors.fill: parent
            radius: 14
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#252030"
                }
                GradientStop {
                    position: 1
                    color: "#17141e"
                }
            }
            border.width: 1
            border.color: dnsPickerRoot.expanded ? "#5d4a77" : "#393042"
        }
        Column {
            id: dnsPickerLayout
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 12
            Item {
                id: dnsPickerToggle
                objectName: "dnsToggle"
                signal clicked
                width: parent.width
                height: 38
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "DNS provider, " + dnsPickerRoot.modeLabel
                Keys.onReturnPressed: {
                    dnsPickerRoot.pointerOwned = false;
                    clicked();
                }
                Keys.onSpacePressed: {
                    dnsPickerRoot.pointerOwned = false;
                    clicked();
                }
                onClicked: dnsPickerRoot.toggleRequested()
                Rectangle {
                    width: 34
                    height: 34
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#35273f"
                    border.width: 1
                    border.color: "#544265"
                    Text {
                        anchors.centerIn: parent
                        text: "\uf233"
                        color: "#c3b7ff"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                    }
                }
                Column {
                    x: 46
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Text {
                        text: "DNS"
                        color: "#9b8eaf"
                        font.family: "sans-serif"
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.7
                    }
                    Text {
                        text: dnsPickerRoot.busy ? "Applying…" : dnsPickerRoot.modeLabel
                        color: "#eee6fa"
                        font.family: "sans-serif"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 8
                    color: dnsPickerHeaderHit.containsMouse || dnsPickerToggle.activeFocus ? "#3c2f49" : "#2c2335"
                    Text {
                        anchors.centerIn: parent
                        text: dnsPickerRoot.expanded ? "\uf106" : "\uf107"
                        color: "#c3b7ff"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    id: dnsPickerHeaderHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dnsPickerRoot.pointerOwned = true;
                        dnsPickerToggle.clicked();
                    }
                }
            }
            Column {
                width: parent.width
                spacing: 8
                visible: dnsPickerRoot.expanded
                Grid {
                    width: parent.width
                    columns: 2
                    spacing: 8
                    Repeater {
                        model: dnsPickerRoot.providers
                        Rectangle {
                            id: dnsPickerCard
                            required property var modelData
                            readonly property bool active: dnsPickerRoot.mode === modelData.key
                            objectName: "dns-" + modelData.key
                            width: (parent.width - 8) / 2
                            height: 76
                            radius: 11
                            enabled: !dnsPickerRoot.busy && dnsPickerRoot.canSelect
                            opacity: enabled || active ? 1 : 0.5
                            activeFocusOnTab: true
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: dnsPickerCard.active ? "#453253" : dnsPickerCardHit.containsMouse || dnsPickerCard.activeFocus ? "#30273c" : "#211b2a"
                                }
                                GradientStop {
                                    position: 1
                                    color: dnsPickerCard.active ? "#2d2339" : "#1b1722"
                                }
                            }
                            border.width: 1
                            border.color: active ? "#b49ae9" : dnsPickerCardHit.containsMouse || activeFocus ? "#6b527f" : "#3c3048"
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.label
                            Keys.onReturnPressed: dnsPickerRoot.selected(modelData.key)
                            Keys.onSpacePressed: dnsPickerRoot.selected(modelData.key)
                            Text {
                                x: 12
                                y: 12
                                text: dnsPickerCard.modelData.glyph
                                color: dnsPickerCard.active ? "#ddcaff" : "#a28aba"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 13
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                y: 13
                                width: 6
                                height: 6
                                radius: 3
                                color: dnsPickerCard.active ? "#d2bcff" : "transparent"
                                border.width: 1
                                border.color: dnsPickerCard.active ? "#d2bcff" : "#675274"
                            }
                            Text {
                                x: 12
                                y: 34
                                text: dnsPickerCard.modelData.label
                                color: "#eee6fa"
                                font.family: "sans-serif"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                x: 12
                                y: 53
                                text: dnsPickerCard.modelData.address
                                color: dnsPickerCard.active ? "#bca6d6" : "#82718f"
                                font.family: "monospace"
                                font.pixelSize: 9
                            }
                            Rectangle {
                                x: 12
                                y: parent.height - 1
                                width: parent.width - 24
                                height: 1
                                color: "#b49ae9"
                                visible: dnsPickerCard.active
                            }
                            MouseArea {
                                id: dnsPickerCardHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dnsPickerRoot.selected(dnsPickerCard.modelData.key)
                            }
                        }
                    }
                }
                Rectangle {
                    id: dnsPickerAutomatic
                    objectName: "dns-automatic"
                    readonly property bool active: dnsPickerRoot.mode === "automatic"
                    width: parent.width
                    height: 40
                    radius: 10
                    enabled: !dnsPickerRoot.busy && dnsPickerRoot.canSelect
                    opacity: enabled || active ? 1 : 0.5
                    activeFocusOnTab: true
                    color: active ? "#30243e" : dnsPickerAutoHit.containsMouse || activeFocus ? "#2b2234" : "#1c1723"
                    border.width: 1
                    border.color: active ? "#8d70ae" : "#3c3048"
                    Accessible.role: Accessible.Button
                    Accessible.name: "Automatic DNS"
                    Keys.onReturnPressed: dnsPickerRoot.selected("automatic")
                    Keys.onSpacePressed: dnsPickerRoot.selected("automatic")
                    Text {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf074"
                        color: "#b19acb"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 12
                    }
                    Text {
                        x: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Auto"
                        color: "#d5c9e2"
                        font.family: "sans-serif"
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: dnsPickerAutomatic.active ? "✓" : ""
                        color: "#c3b7ff"
                        font.family: "sans-serif"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: dnsPickerAutoHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dnsPickerRoot.selected("automatic")
                    }
                }
            }
        }
    }

    component WifiViewAction: Rectangle {
        id: wifiViewActionButton
        property string label: ""
        property string glyph: ""
        signal clicked
        width: 28
        height: 28
        radius: 8
        opacity: enabled ? 1 : 0.3
        color: wifiViewActionHit.containsMouse || activeFocus ? "#383044" : "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            anchors.centerIn: parent
            text: wifiViewActionButton.glyph
            color: "#aaa6b5"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 12
        }
        MouseArea {
            id: wifiViewActionHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wifiViewActionButton.clicked()
        }
        PanelToolTip {
            visible: wifiViewActionHit.containsMouse
            text: wifiViewActionButton.label
        }
    }

    component WifiViewTextButton: Rectangle {
        id: wifiViewTextButtonButton
        property string label: ""
        property bool primary: false
        signal clicked
        width: wifiViewTextButtonCaption.implicitWidth + 24
        height: 30
        radius: 8
        opacity: enabled ? 1 : 0.3
        color: primary ? "#c3b7ff" : wifiViewTextButtonHit.containsMouse || activeFocus ? "#383044" : "#29252f"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            id: wifiViewTextButtonCaption
            anchors.centerIn: parent
            text: wifiViewTextButtonButton.label
            color: wifiViewTextButtonButton.primary ? "#19171c" : "#aaa6b5"
            font.family: "sans-serif"
            font.pixelSize: 11
        }
        MouseArea {
            id: wifiViewTextButtonHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wifiViewTextButtonButton.clicked()
        }
    }

    component WifiView: Item {
        id: wifiViewRoot
        required property var backend
        readonly property bool powerEnabled: backend.powerPending ? backend.requestedPower : !!backend.state.enabled
        property string search: ""
        property bool dnsExpanded: false
        property bool networksHovered: false
        readonly property bool networksExpanded: networksHovered || !backend.state.connected || !!backend.passwordNetwork || wifiViewSearchInput.activeFocus
        Timer {
            id: wifiViewExpandNetworks
            interval: 160
            onTriggered: wifiViewRoot.networksHovered = true
        }
        Timer {
            id: wifiViewCollapseNetworks
            interval: 240
            onTriggered: {
                wifiViewRoot.networksHovered = false;
                if (!wifiViewSearchInput.activeFocus) {
                    wifiViewRoot.search = "";
                    wifiViewSearchInput.clear();
                }
            }
        }
        readonly property var networks: (backend.state.networks || []).filter(function (wifiViewNetwork) {
            return !wifiViewRoot.search || wifiViewNetwork.ssid.toLowerCase().indexOf(wifiViewRoot.search.toLowerCase()) >= 0;
        })
        implicitHeight: Math.min(wifiViewContent.implicitHeight, 520)
        function connectSelected() {
            if (!wifiViewPassword.text || backend.busy)
                return;
            var secret = wifiViewPassword.text;
            wifiViewPassword.clear();
            backend.submitPassword(secret);
        }
        Connections {
            target: wifiViewRoot.backend
            function onPasswordNetworkChanged() {
                wifiViewPassword.clear();
                if (wifiViewRoot.backend.passwordNetwork)
                    Qt.callLater(function () {
                        wifiViewPassword.forceActiveFocus();
                    });
            }
            function onOpenedChanged() {
                if (!wifiViewRoot.backend.opened) {
                    wifiViewPassword.clear();
                    wifiViewRoot.search = "";
                    wifiViewSearchInput.clear();
                    wifiViewRoot.networksHovered = false;
                    wifiViewExpandNetworks.stop();
                    wifiViewCollapseNetworks.stop();
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
                spacing: 16
                Item {
                    width: parent.width
                    height: 52
                    Rectangle {
                        id: wifiViewIcon
                        width: 42
                        height: 42
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: wifiViewRoot.powerEnabled ? "#c3b7ff" : "#302938"
                        Text {
                            anchors.centerIn: parent
                            text: "\uf1eb"
                            color: wifiViewRoot.powerEnabled ? "#19171c" : "#928b96"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 19
                        }
                    }
                    Column {
                        anchors.left: wifiViewIcon.right
                        anchors.leftMargin: 12
                        anchors.right: wifiViewHeaderActions.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            text: "Wi-Fi"
                            color: "#eef3f8"
                            font.family: "sans-serif"
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: wifiViewRoot.backend.powerPending ? wifiViewRoot.backend.requestedPower ? "Turning on…" : "Turning off…" : !wifiViewRoot.backend.state.available ? "No adapter" : wifiViewRoot.backend.state.blocked ? "Blocked" : !wifiViewRoot.backend.state.enabled ? "Off" : wifiViewRoot.backend.state.connected || "Disconnected"
                            textFormat: Text.PlainText
                            color: "#928b96"
                            font.family: "sans-serif"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                    Row {
                        id: wifiViewHeaderActions
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        ToggleSwitch {
                            objectName: "wifiPower"
                            anchors.verticalCenter: parent.verticalCenter
                            checked: wifiViewRoot.powerEnabled
                            enabled: wifiViewRoot.backend.state.available && !wifiViewRoot.backend.state.blocked && !wifiViewRoot.backend.busy
                            opacity: enabled || wifiViewRoot.backend.powerPending ? 1 : 0.3
                            activeFocusOnTab: true
                            Accessible.role: Accessible.CheckBox
                            Accessible.name: "Wi-Fi power"
                            Accessible.checked: checked
                            Keys.onReturnPressed: wifiViewRoot.backend.setPower(!checked)
                            Keys.onSpacePressed: wifiViewRoot.backend.setPower(!checked)
                            onToggled: wifiViewRoot.backend.setPower(!checked)
                        }
                        WifiViewAction {
                            label: "Close"
                            glyph: "\uf00d"
                            onClicked: wifiViewRoot.backend.close()
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#302c36"
                }
                Text {
                    visible: wifiViewRoot.backend.busy || wifiViewRoot.backend.refreshing
                    text: wifiViewRoot.backend.busy ? wifiViewRoot.backend.lastAction === "scan" ? "Scanning…" : wifiViewRoot.backend.lastAction === "connect" ? "Connecting…" : wifiViewRoot.backend.lastAction === "band" ? "Switching…" : wifiViewRoot.backend.lastAction === "dns" ? "DNS…" : "Updating…" : "Updating…"
                    color: "#c3b7ff"
                    font.family: "sans-serif"
                    font.pixelSize: 11
                }
                Column {
                    width: parent.width
                    spacing: 9
                    visible: !!wifiViewRoot.backend.state.profileUuid || !!wifiViewRoot.backend.state.connected
                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            anchors.left: parent.left
                            text: "Band"
                            color: "#aaa6b5"
                            font.family: "sans-serif"
                            font.pixelSize: 11
                        }
                        Text {
                            anchors.right: parent.right
                            text: wifiViewRoot.backend.state.actualBand === "bg" ? "2.4 GHz" : wifiViewRoot.backend.state.actualBand === "a" ? "5 GHz" : wifiViewRoot.backend.state.actualBand === "6" ? "6 GHz" : ""
                            color: "#716c76"
                            font.family: "sans-serif"
                            font.pixelSize: 10
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 4
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
                                    label: "Auto"
                                }
                            ]
                            Rectangle {
                                id: wifiViewBand
                                required property var modelData
                                readonly property bool selected: (wifiViewRoot.backend.state.bandMode || "") === modelData.mode
                                objectName: "band-" + (modelData.mode || "auto")
                                width: (parent.width - 8) / 3
                                height: 32
                                radius: 8
                                enabled: !!wifiViewRoot.backend.state.connected && wifiViewRoot.backend.state.enabled && !wifiViewRoot.backend.busy && (!modelData.mode || (wifiViewRoot.backend.state.availableBands || []).indexOf(modelData.mode) >= 0)
                                opacity: enabled || selected ? 1 : 0.3
                                color: selected ? "#383044" : wifiViewBandHit.containsMouse || activeFocus ? "#29252f" : "#151319"
                                border.width: selected ? 1 : 0
                                border.color: "#625471"
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.label
                                Keys.onReturnPressed: wifiViewRoot.backend.setBand(modelData.mode)
                                Keys.onSpacePressed: wifiViewRoot.backend.setBand(modelData.mode)
                                Text {
                                    anchors.centerIn: parent
                                    text: wifiViewBand.modelData.label
                                    color: wifiViewBand.selected ? "#d8caff" : "#aaa6b5"
                                    font.family: "sans-serif"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    id: wifiViewBandHit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiViewRoot.backend.setBand(wifiViewBand.modelData.mode)
                                }
                            }
                        }
                    }
                }
                DnsPicker {
                    width: parent.width
                    visible: !!wifiViewRoot.backend.state.profileUuid || !!wifiViewRoot.backend.state.connected
                    mode: wifiViewRoot.backend.state.dnsMode || "automatic"
                    expanded: wifiViewRoot.dnsExpanded
                    busy: wifiViewRoot.backend.busy && wifiViewRoot.backend.lastAction === "dns"
                    canSelect: !!wifiViewRoot.backend.state.connected && wifiViewRoot.backend.state.enabled && !wifiViewRoot.backend.busy
                    enabled: !wifiViewRoot.backend.busy || wifiViewRoot.backend.lastAction === "dns"
                    onToggleRequested: wifiViewRoot.dnsExpanded = !wifiViewRoot.dnsExpanded
                    onSelected: function (provider) {
                        wifiViewRoot.dnsExpanded = false;
                        wifiViewRoot.backend.setDns(provider);
                    }
                }
                Column {
                    width: parent.width
                    spacing: 12
                    visible: !!wifiViewRoot.backend.passwordNetwork
                    Text {
                        width: parent.width
                        text: wifiViewRoot.backend.passwordNetwork ? "Join “" + wifiViewRoot.backend.passwordNetwork.ssid + "”" : ""
                        textFormat: Text.PlainText
                        color: "#eef3f8"
                        font.family: "sans-serif"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }
                    TextField {
                        id: wifiViewPassword
                        objectName: "networkPassword"
                        width: parent.width
                        height: 38
                        echoMode: TextInput.Password
                        maximumLength: 256
                        placeholderText: "Network password"
                        color: "#eef3f8"
                        placeholderTextColor: "#716c76"
                        font.family: "sans-serif"
                        font.pixelSize: 12
                        enabled: !wifiViewRoot.backend.busy
                        Accessible.name: "Network password"
                        background: Rectangle {
                            radius: 9
                            color: "#151319"
                            border.width: 1
                            border.color: wifiViewPassword.activeFocus ? "#625471" : "#37343f"
                        }
                        onAccepted: wifiViewRoot.connectSelected()
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 8
                        WifiViewTextButton {
                            label: "Cancel"
                            enabled: !wifiViewRoot.backend.busy
                            onClicked: wifiViewRoot.backend.cancelPassword()
                        }
                        WifiViewTextButton {
                            label: "Connect"
                            primary: true
                            enabled: !!wifiViewPassword.text && !wifiViewRoot.backend.busy
                            onClicked: wifiViewRoot.connectSelected()
                        }
                    }
                }
                Text {
                    width: parent.width
                    visible: !!wifiViewRoot.backend.error
                    text: wifiViewRoot.backend.error
                    textFormat: Text.PlainText
                    color: "#e28b9b"
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
                Column {
                    id: wifiViewNetworkSection
                    objectName: "networkSection"
                    width: parent.width
                    spacing: 10
                    HoverHandler {
                        margin: 8
                        onHoveredChanged: {
                            if (hovered) {
                                wifiViewCollapseNetworks.stop();
                                wifiViewExpandNetworks.restart();
                            } else {
                                wifiViewExpandNetworks.stop();
                                wifiViewCollapseNetworks.restart();
                            }
                        }
                    }
                    visible: wifiViewRoot.backend.state.available && wifiViewRoot.backend.state.enabled && !wifiViewRoot.backend.state.blocked
                    Item {
                        width: parent.width
                        height: 28
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Show nearby networks"
                        Keys.onReturnPressed: wifiViewRoot.networksHovered = !wifiViewRoot.networksHovered
                        Keys.onSpacePressed: wifiViewRoot.networksHovered = !wifiViewRoot.networksHovered
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: wifiViewRoot.networksExpanded ? "Networks" : "Nearby"
                            color: "#aaa6b5"
                            font.family: "sans-serif"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        WifiViewAction {
                            anchors.right: parent.right
                            label: "Refresh networks"
                            glyph: "\uf021"
                            enabled: !wifiViewRoot.backend.busy && !wifiViewRoot.backend.refreshing
                            onClicked: wifiViewRoot.backend.scan()
                        }
                    }
                    TextField {
                        id: wifiViewSearchInput
                        objectName: "networkSearch"
                        width: parent.width
                        height: 34
                        visible: wifiViewRoot.networksExpanded && ((wifiViewRoot.backend.state.networks || []).length > 5 || !!wifiViewRoot.search)
                        placeholderText: "Search networks"
                        color: "#eef3f8"
                        placeholderTextColor: "#716c76"
                        font.family: "sans-serif"
                        font.pixelSize: 11
                        Accessible.name: "Search networks"
                        background: Rectangle {
                            radius: 8
                            color: "#151319"
                            border.width: 1
                            border.color: "#37343f"
                        }
                        onTextEdited: wifiViewRoot.search = text
                    }
                    Column {
                        width: parent.width
                        spacing: 3
                        Repeater {
                            model: wifiViewRoot.networks
                            Rectangle {
                                id: wifiViewNetwork
                                required property var modelData
                                visible: wifiViewRoot.networksExpanded || modelData.active
                                width: parent.width
                                height: 58
                                radius: 11
                                color: modelData.active ? "#383044" : wifiViewHit.containsMouse || activeFocus ? "#29252f" : "transparent"
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.ssid + (modelData.active ? ", connected" : "")
                                function activate() {
                                    if (wifiViewRoot.backend.busy)
                                        return;
                                    if (modelData.active)
                                        wifiViewRoot.backend.setPower(false);
                                    else
                                        wifiViewRoot.backend.connectNetwork(modelData);
                                }
                                Keys.onReturnPressed: activate()
                                Keys.onSpacePressed: activate()
                                MouseArea {
                                    id: wifiViewHit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiViewNetwork.activate()
                                }
                                Text {
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\uf1eb"
                                    opacity: 0.3 + wifiViewNetwork.modelData.signal / 100 * 0.7
                                    color: wifiViewNetwork.modelData.active ? "#c3b7ff" : "#aaa6b5"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 16
                                }
                                Column {
                                    x: 43
                                    width: parent.width - 94
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5
                                    Text {
                                        width: parent.width
                                        text: wifiViewNetwork.modelData.ssid
                                        textFormat: Text.PlainText
                                        color: "#eef3f8"
                                        font.family: "sans-serif"
                                        font.pixelSize: 12
                                        font.weight: wifiViewNetwork.modelData.active ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: wifiViewNetwork.modelData.security + " · " + wifiViewNetwork.modelData.signal + "%"
                                        color: "#928b96"
                                        font.family: "sans-serif"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !wifiViewNetwork.modelData.active
                                    text: wifiViewNetwork.modelData.secured ? "\uf023" : "\uf105"
                                    color: "#716c76"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 11
                                }
                                WifiViewAction {
                                    objectName: "disconnectNetwork"
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: wifiViewNetwork.modelData.active
                                    enabled: !wifiViewRoot.backend.busy
                                    glyph: "\uf00d"
                                    label: "Disconnect"
                                    onClicked: wifiViewRoot.backend.disconnect()
                                }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: wifiViewRoot.networksExpanded && wifiViewRoot.networks.length === 0 && !wifiViewRoot.backend.refreshing && !wifiViewRoot.backend.busy
                        text: wifiViewRoot.search ? "No matching networks" : "No networks found. Try refreshing."
                        color: "#928b96"
                        font.family: "sans-serif"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
                Text {
                    width: parent.width
                    visible: !wifiViewRoot.backend.state.enabled || !wifiViewRoot.backend.state.available || wifiViewRoot.backend.state.blocked
                    text: !wifiViewRoot.backend.state.available ? "No Wi-Fi adapter was detected." : wifiViewRoot.backend.state.blocked ? "Enable wireless using your computer’s hardware switch." : "Turn on Wi-Fi to see nearby networks."
                    color: "#928b96"
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
