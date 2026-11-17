import "../controls/PanelTheme.js" as Theme
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../controls"
import "../scripts/AudioModel.js" as Model
import Quickshell.Widgets
import "library"

Item {
    id: root
    property bool opened: false
    property bool libraryOpen: false
    property bool autoPlay: true
    property bool autoPlayPreferencesReady: false
    property bool autoPlayAttempted: false
    property real popupX: 228
    property var bluetoothBackend: null
    signal backRequested
    signal panelRequested(string panel)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values
    readonly property string playerScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/player.py"
    readonly property var mprisPlayers: Model.listSnapshot(Mpris.players.values).filter(function (player) {
        return player && !Model.mprisPlayerIsProxy(player) && (player.isPlaying || !!player.trackTitle);
    })
    LocalPlayer {
        id: localMusic
        polling: root.opened
    }
    readonly property var players: {
        var registered = mprisPlayers.some(function (value) {
            return String(value.dbusName).indexOf("y_music") >= 0;
        });
        return localMusic.available && !registered ? mprisPlayers.concat([localMusic]) : mprisPlayers;
    }
    property int playerIndex: 0
    readonly property var player: {
        var playing = players.filter(function (value) {
            return value.isPlaying;
        });
        var candidates = playing.length ? playing : players;
        return candidates.length ? candidates[Math.min(playerIndex, candidates.length - 1)] : null;
    }
    readonly property var candidateSinks: Model.listSnapshot(nodes).filter(function (node) {
        return node && node.isSink && !node.isStream;
    })
    readonly property var candidateSources: Model.listSnapshot(nodes).filter(function (node) {
        return node && !node.isSink && !node.isStream && node.name !== "quickshell";
    })
    readonly property var candidateStreams: Model.listSnapshot(nodes).filter(function (node) {
        return Model.isPlaybackStream(node) && String(node.name || "").indexOf("omarchy_speaker_tuning") !== 0;
    })
    property var outputs: []
    property var inputs: []
    property var streams: []
    property string volumeSinkName: ""
    readonly property var volumeSink: {
        for (var i = 0; i < candidateSinks.length; i++) {
            if (candidateSinks[i].name === volumeSinkName && candidateSinks[i].audio)
                return candidateSinks[i];
        }
        return sink;
    }
    readonly property real outputVolume: volumeSink && volumeSink.audio ? volumeSink.audio.volume : 0
    readonly property bool outputMuted: volumeSink && volumeSink.audio ? volumeSink.audio.muted : false
    readonly property real inputVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool inputMuted: source && source.audio ? source.audio.muted : false

    readonly property var headphoneBattery: {
        var bluetooth = bluetoothBackend;
        if (!bluetooth)
            return null;
        return Model.headphoneBattery(bluetooth.connectedRows || [], sink || volumeSink, function (device) {
            return bluetooth.bluetoothAudioSink(device);
        });
    }
    function open() {
        autoPlayAttempted = false;
        opened = true;
        maybeStartAutoplay();
    }
    function close() {
        opened = false;
        libraryOpen = false;
    }
    function openLibrary() {
        if (!opened)
            open();
        libraryOpen = true;
    }
    function toggle() {
        if (opened)
            close();
        else
            open();
    }
    function maybeStartAutoplay() {
        if (!opened || !autoPlayPreferencesReady || autoPlayAttempted)
            return;
        autoPlayAttempted = true;
        if (!autoPlay)
            return;
        var externalPlayerIsPlaying = mprisPlayers.some(function (value) {
            var name = String(value.dbusName || "");
            return name.indexOf("y_music") < 0 && name.indexOf("playerctld") < 0 && value.isPlaying;
        });
        if (!externalPlayerIsPlaying && !autoplayAction.running)
            autoplayAction.running = true;
    }
    function toggleAutoplay() {
        if (autoplayPreferencesSave.running)
            return;
        autoPlay = !autoPlay;
        autoplayPreferencesSave.command = ["python3", "-B", playerScript, "autoplay", autoPlay ? "on" : "off"];
        autoplayPreferencesSave.running = true;
    }
    function nodeLabel(node) {
        return Model.nodeLabel(node);
    }
    function sinkGlyph(node) {
        return Model.sinkGlyph(node);
    }
    function streamLabel(node) {
        return Model.streamLabel(node, players, streams);
    }
    function streamPlayer(node) {
        return Model.playerForStream(node, players, streams);
    }
    function setOutputVolume(value) {
        if (volumeSink && volumeSink.audio)
            volumeSink.audio.volume = Math.max(0, Math.min(1, value));
    }
    function setInputVolume(value) {
        if (source && source.audio)
            source.audio.volume = Math.max(0, Math.min(1, value));
    }
    function toggleOutputMute() {
        if (volumeSink && volumeSink.audio)
            volumeSink.audio.muted = !volumeSink.audio.muted;
    }
    function toggleInputMute() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }
    function setDefaultSink(node) {
        if (!node)
            return;
        Pipewire.preferredDefaultAudioSink = node;
        Quickshell.execDetached(["wpctl", "set-default", String(node.id)]);
    }
    function setDefaultSource(node) {
        if (!node)
            return;
        Pipewire.preferredDefaultAudioSource = node;
        Quickshell.execDetached(["wpctl", "set-default", String(node.id)]);
    }
    function cyclePlayer() {
        var playing = players.filter(function (value) {
            return value.isPlaying;
        });
        var count = playing.length || players.length;
        if (count > 1)
            playerIndex = (playerIndex + 1) % count;
    }
    function refreshModels() {
        if (!opened)
            return;
        outputs = candidateSinks.filter(function (node) {
            return !!node.audio;
        });
        inputs = candidateSources.filter(function (node) {
            return !!node.audio && Model.isAudioSource(node);
        });
        streams = candidateStreams.filter(function (node) {
            return !!node.audio;
        });
    }
    function resolveVolumeSink() {
        if (!volumeSinkProc.running)
            volumeSinkProc.running = true;
    }
    onSinkChanged: resolveVolumeSink()
    onCandidateSinksChanged: if (opened)
        modelRefresh.restart()
    onCandidateSourcesChanged: if (opened)
        modelRefresh.restart()
    onCandidateStreamsChanged: if (opened)
        modelRefresh.restart()
    Connections {
        target: root
        function onOpenedChanged() {
            if (root.opened) {
                root.autoPlayAttempted = false;
                root.refreshModels();
                root.resolveVolumeSink();
                root.maybeStartAutoplay();
                modelRefresh.restart();
                Qt.callLater(function () {
                    view.reset();
                    card.forceActiveFocus();
                });
            } else {
                root.outputs = [];
                root.inputs = [];
                root.streams = [];
            }
        }
    }
    PwObjectTracker {
        objects: root.candidateSinks
    }
    PwObjectTracker {
        objects: root.candidateSources
    }
    PwObjectTracker {
        objects: root.candidateStreams
    }
    Timer {
        id: modelRefresh
        interval: 100
        onTriggered: root.refreshModels()
    }
    Timer {
        interval: 1000
        running: root.opened
        repeat: true
        onTriggered: root.refreshModels()
    }
    Timer {
        interval: 15000
        running: root.opened
        repeat: true
        onTriggered: root.resolveVolumeSink()
    }
    Process {
        id: volumeSinkProc
        command: ["python3", "-B", Quickshell.env("HOME") + "/.config/quickshell/scripts/default_sink.py"]
        stdout: StdioCollector {
            onStreamFinished: root.volumeSinkName = text.trim()
        }
    }
    Component.onCompleted: autoplayPreferencesQuery.running = true
    Process {
        id: autoplayPreferencesQuery
        command: ["python3", "-B", root.playerScript, "preferences"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.autoPlay = JSON.parse(text).autoplay;
                } catch (error) {}
                root.autoPlayPreferencesReady = true;
                root.maybeStartAutoplay();
            }
        }
    }
    Process {
        id: autoplayPreferencesSave
        onExited: if (!autoplayPreferencesQuery.running)
            autoplayPreferencesQuery.running = true
    }
    Process {
        id: autoplayAction
        command: ["python3", "-B", root.playerScript, "random-if-idle"]
    }
    IpcHandler {
        target: "audio"
        function toggle(): void {
            root.toggle();
        }
        function close(): void {
            root.close();
        }
        function library(): void {
            root.openLibrary();
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
        WlrLayershell.namespace: "audio"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Shortcut {
            sequence: "B"
            context: Qt.WindowShortcut
            enabled: root.opened
            onActivated: {
                root.close();
                root.backRequested();
            }
        }
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
            currentPanel: "audio"
            onSelected: function (panel) {
                root.panelRequested(panel);
            }
        }
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(root.libraryOpen ? 440 : 400, panel.width - 32)
            height: root.libraryOpen ? Math.min(640, panel.height - 112) : Math.min(view.implicitHeight, panel.height - 112)
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            radius: Theme.panelRadius
            gradient: PanelGradient {}
            clip: true
            border.width: 1
            border.color: Theme.border
            PanelAura { radius: parent.radius }
            focus: true
            Keys.onEscapePressed: {
                if (root.libraryOpen)
                    musicLibrary.back();
                else
                    root.close();
            }
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_M) {
                    root.toggleOutputMute();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Space && root.player && (root.player.isPlaying ? root.player.canPause : root.player.canPlay)) {
                    root.player.togglePlaying();
                    event.accepted = true;
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            AudioView {
                id: view
                anchors.fill: parent
                backend: root
                visible: opacity > 0
                opacity: root.libraryOpen ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
            MusicLibrary {
                id: musicLibrary
                anchors.fill: parent
                player: localMusic
                active: root.opened && root.libraryOpen
                visible: opacity > 0
                opacity: root.libraryOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                onCloseRequested: {
                    root.libraryOpen = false;
                    card.forceActiveFocus();
                }
            }
        }
    }

    component AudioPlaybackPlaybackButton: Rectangle {
        id: audioPlaybackPlaybackButtonButton
        property string glyph: ""
        property string label: ""
        property bool primary: false
        property bool danger: false
        signal clicked
        width: 32
        height: 30
        radius: 8
        opacity: enabled ? 1 : 0.3
        color: primary ? Theme.accent : audioPlaybackPlaybackButtonHit.containsMouse || activeFocus ? Theme.hover : Theme.surface
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            anchors.centerIn: parent
            text: audioPlaybackPlaybackButtonButton.glyph
            color: audioPlaybackPlaybackButtonButton.primary ? Theme.background : audioPlaybackPlaybackButtonButton.danger ? "#d9737f" : Theme.accent
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 12
        }
        MouseArea {
            id: audioPlaybackPlaybackButtonHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: audioPlaybackPlaybackButtonButton.clicked()
        }
        PanelToolTip {
            visible: audioPlaybackPlaybackButtonHit.containsMouse
            text: audioPlaybackPlaybackButtonButton.label
        }
    }

    component AudioPlayback: Item {
        id: audioPlaybackRoot
        property var player: null
        visible: !!player
        implicitHeight: visible ? audioPlaybackDetails.implicitHeight + 16 : 0
        height: implicitHeight

        Column {
            id: audioPlaybackDetails
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 8

            Column {
                width: parent.width
                spacing: 3
                Text {
                    width: parent.width
                    text: audioPlaybackRoot.player ? audioPlaybackRoot.player.trackTitle || "Unknown track" : ""
                    textFormat: Text.PlainText
                    color: Theme.foreground
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: audioPlaybackRoot.player ? audioPlaybackRoot.player.trackArtist || audioPlaybackRoot.player.identity || "" : ""
                    textFormat: Text.PlainText
                    color: Theme.muted
                    font.family: "sans-serif"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Row {
                spacing: 6
                AudioPlaybackPlaybackButton {
                    glyph: "\uf048"
                    label: "Previous"
                    enabled: !!audioPlaybackRoot.player && audioPlaybackRoot.player.canGoPrevious
                    onClicked: audioPlaybackRoot.player.previous()
                }
                AudioPlaybackPlaybackButton {
                    glyph: audioPlaybackRoot.player && audioPlaybackRoot.player.isPlaying ? "\uf04c" : "\uf04b"
                    label: audioPlaybackRoot.player && audioPlaybackRoot.player.isPlaying ? "Pause" : "Play"
                    primary: true
                    enabled: !!audioPlaybackRoot.player && (audioPlaybackRoot.player.isPlaying ? audioPlaybackRoot.player.canPause : audioPlaybackRoot.player.canPlay)
                    onClicked: audioPlaybackRoot.player.togglePlaying()
                }
                AudioPlaybackPlaybackButton {
                    glyph: "\uf051"
                    label: "Next"
                    enabled: !!audioPlaybackRoot.player && audioPlaybackRoot.player.canGoNext
                    onClicked: audioPlaybackRoot.player.next()
                }
                AudioPlaybackPlaybackButton {
                    glyph: "\uf00d"
                    label: audioPlaybackRoot.player && audioPlaybackRoot.player.canQuit ? "Quit player" : "Stop playback"
                    danger: true
                    enabled: !!audioPlaybackRoot.player && (audioPlaybackRoot.player.canQuit || audioPlaybackRoot.player.canControl)
                    onClicked: {
                        if (audioPlaybackRoot.player.canQuit)
                            audioPlaybackRoot.player.quit();
                        else
                            audioPlaybackRoot.player.stop();
                    }
                }
            }
        }
    }

    component AudioViewSettingsButton: Item {
        id: audioViewSettingsButtonButton
        required property var contextRoot
        property string section: ""
        property string label: ""
        property string glyph: ""
        property string detail: ""
        property bool lit: false
        property color tint: Theme.accent
        readonly property bool selected: contextRoot.settingsExpanded && contextRoot.settingsSection === section
        readonly property bool hovered: audioViewSettingsButtonHit.containsMouse || activeFocus
        objectName: "settings-" + section
        height: 74
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label + ", " + detail
        function toggle() {
            contextRoot.settingsPointerOwned = false;
            if (selected) {
                contextRoot.settingsExpanded = false;
                return;
            }
            contextRoot.settingsSection = section;
            contextRoot.settingsExpanded = true;
        }
        Keys.onReturnPressed: toggle()
        Keys.onSpacePressed: toggle()
        Rectangle {
            id: audioViewSettingsButtonHalo
            anchors.horizontalCenter: audioViewSettingsButtonOrb.horizontalCenter
            anchors.verticalCenter: audioViewSettingsButtonOrb.verticalCenter
            width: audioViewSettingsButtonOrb.width + 10
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(audioViewSettingsButtonButton.tint.r, audioViewSettingsButtonButton.tint.g, audioViewSettingsButtonButton.tint.b, 0.35)
            opacity: audioViewSettingsButtonButton.selected ? 1 : 0
            scale: audioViewSettingsButtonButton.selected ? 1 : 0.8
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        }
        Rectangle {
            id: audioViewSettingsButtonOrb
            anchors.horizontalCenter: parent.horizontalCenter
            y: 5
            width: 44
            height: 44
            radius: 22
            scale: audioViewSettingsButtonHit.pressed ? 0.9 : audioViewSettingsButtonButton.hovered && !audioViewSettingsButtonButton.selected ? 1.06 : 1
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: audioViewSettingsButtonButton.selected ? Qt.lighter(audioViewSettingsButtonButton.tint, 1.12) : audioViewSettingsButtonButton.hovered ? Theme.hover : Theme.surface
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                GradientStop {
                    position: 1
                    color: audioViewSettingsButtonButton.selected ? Qt.darker(audioViewSettingsButtonButton.tint, 1.25) : audioViewSettingsButtonButton.hovered ? Theme.surface : "#221c21"
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }
            border.width: 1
            border.color: audioViewSettingsButtonButton.selected ? Qt.rgba(0.902, 0.843, 0.863, 0.28) : audioViewSettingsButtonButton.hovered ? Theme.border : "#362d34"
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 160 } }
            Text {
                anchors.centerIn: parent
                text: audioViewSettingsButtonButton.glyph
                color: audioViewSettingsButtonButton.selected ? "#221c21" : audioViewSettingsButtonButton.lit ? audioViewSettingsButtonButton.tint : audioViewSettingsButtonButton.hovered ? Theme.foreground : Theme.muted
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 17
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 1
                anchors.topMargin: 1
                width: 10
                height: 10
                radius: 5
                color: audioViewSettingsButtonButton.tint
                border.width: 2
                border.color: "#221c21"
                visible: audioViewSettingsButtonButton.lit && !audioViewSettingsButtonButton.selected
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: audioViewSettingsButtonOrb.bottom
            anchors.topMargin: 8
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: audioViewSettingsButtonButton.label
            color: audioViewSettingsButtonButton.selected ? Theme.foreground : audioViewSettingsButtonButton.hovered ? Theme.foreground : Theme.muted
            font.family: "sans-serif"
            font.pixelSize: 10
            font.weight: audioViewSettingsButtonButton.selected ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        MouseArea {
            id: audioViewSettingsButtonHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: audioViewSettingsButtonButton.toggle()
            onEntered: {
                contextRoot.hoveredSettings = audioViewSettingsButtonButton.section;
                if (audioViewSettingsButtonButton.selected)
                    contextRoot.settingsPointerOwned = true;
            }
            onExited: if (contextRoot.hoveredSettings === audioViewSettingsButtonButton.section)
                contextRoot.hoveredSettings = ""
        }
        PanelToolTip {
            visible: audioViewSettingsButtonHit.containsMouse && !audioViewSettingsButtonButton.selected
            text: audioViewSettingsButtonButton.detail
        }
    }

    component AudioViewAppCard: Rectangle {
        id: appCardRoot
        required property var node
        required property var backend
        property int position: 0
        readonly property var tints: ["#d69aac", "#d69aac", "#d69aac", "#d69aac", "#dda07f"]
        readonly property color tint: tints[position % tints.length]
        readonly property var audio: node ? node.audio : null
        readonly property bool muted: !!audio && audio.muted
        readonly property real level: audio ? audio.volume : 0
        readonly property var props: node && node.properties ? node.properties : ({})
        readonly property string appKey: String(props["application.process.binary"] || props["application.id"] || props["application.name"] || props["node.name"] || "")
        readonly property var entry: {
            var keys = [props["application.icon-name"], props["application.process.binary"], props["application.id"], props["application.name"]];
            for (var index = 0; index < keys.length; index++) {
                if (!keys[index])
                    continue;
                var found = DesktopEntries.heuristicLookup(String(keys[index]));
                if (found && found.icon)
                    return found;
            }
            return null;
        }
        readonly property string iconSource: {
            var name = entry ? entry.icon : props["application.icon-name"] || "";
            return name ? Quickshell.iconPath(name, true) : "";
        }
        readonly property string fallbackGlyph: /music|spotify|audio|player/i.test(appKey) ? "󰝚" : /firefox|librewolf|zen|brave|chrom/i.test(appKey) ? "󰈹" : /discord|telegram|vesktop/i.test(appKey) ? "󰍪" : ""
        width: parent ? parent.width : 0
        height: 78
        radius: 18
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(appCardRoot.tint.r, appCardRoot.tint.g, appCardRoot.tint.b, appCardRoot.muted ? 0.04 : 0.13) }
            GradientStop { position: 0.55; color: "#14e6d7dc" }
            GradientStop { position: 1; color: "#08e6d7dc" }
        }
        border.width: 1
        border.color: Qt.rgba(tint.r, tint.g, tint.b, appCardHover.hovered ? 0.55 : 0.25)
        Behavior on border.color { ColorAnimation { duration: 160 } }
        HoverHandler {
            id: appCardHover
        }
        Rectangle {
            x: 18
            y: 0
            width: parent.width * 0.4
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(appCardRoot.tint.r, appCardRoot.tint.g, appCardRoot.tint.b, 0.8) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Item {
            id: appCardOrb
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 54
            height: 54
            Rectangle {
                anchors.centerIn: parent
                width: 54
                height: 54
                radius: 27
                color: Qt.rgba(appCardRoot.tint.r, appCardRoot.tint.g, appCardRoot.tint.b, 0.18)
                visible: !appCardRoot.muted
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 24
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "#2ae6d7dc"
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 27
                        centerY: 27
                        radiusX: 24
                        radiusY: 24
                        startAngle: 135
                        sweepAngle: 270
                    }
                }
                ShapePath {
                    strokeColor: appCardRoot.muted ? "#45393f" : appCardRoot.tint
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 27
                        centerY: 27
                        radiusX: 24
                        radiusY: 24
                        startAngle: 135
                        sweepAngle: Math.max(0.5, Math.min(1, appCardRoot.level / 1.5)) * 270
                        Behavior on sweepAngle { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Item {
                anchors.fill: parent
                rotation: appCardSpin.angle
                visible: !appCardRoot.muted
                QtObject {
                    id: appCardSpin
                    property real angle: 0
                }
                NumberAnimation {
                    target: appCardSpin
                    property: "angle"
                    from: 0
                    to: 360
                    duration: 6000
                    loops: Animation.Infinite
                    running: appCardRoot.visible && !appCardRoot.muted && !!appCardRoot.backend.opened
                }
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property real angle: index * 2.0944
                        x: 27 + Math.cos(angle) * 18 - 1.5
                        y: 27 + Math.sin(angle) * 18 - 1.5
                        width: 3
                        height: 3
                        radius: 1.5
                        color: appCardRoot.tint
                        opacity: 0.8
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 32
                height: 32
                radius: 16
                color: "#221c21"
                border.width: 1
                border.color: Qt.rgba(appCardRoot.tint.r, appCardRoot.tint.g, appCardRoot.tint.b, 0.45)
                Image {
                    id: appCardIcon
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: appCardRoot.iconSource
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                    opacity: appCardRoot.muted ? 0.4 : 1
                }
                Text {
                    anchors.centerIn: parent
                    visible: appCardIcon.status !== Image.Ready
                    text: appCardRoot.fallbackGlyph || (appCardRoot.backend.streamLabel(appCardRoot.node) || "?").charAt(0).toUpperCase()
                    color: appCardRoot.muted ? "#45393f" : appCardRoot.tint
                    font.family: appCardRoot.fallbackGlyph ? "Symbols Nerd Font Mono" : "sans-serif"
                    font.pixelSize: appCardRoot.fallbackGlyph ? 16 : 14
                    font.weight: Font.Bold
                }
            }
        }
        Column {
            anchors.left: appCardOrb.right
            anchors.leftMargin: 12
            anchors.right: appCardMute.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Row {
                width: parent.width
                spacing: 8
                Text {
                    id: appCardName
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - appCardPercent.implicitWidth - appCardBars.width - 16)
                    text: appCardRoot.backend.streamLabel(appCardRoot.node)
                    color: appCardRoot.muted ? Theme.dim : Theme.foreground
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
                Row {
                    id: appCardBars
                    anchors.verticalCenter: parent.verticalCenter
                    height: 12
                    spacing: 2
                    visible: !appCardRoot.muted
                    Repeater {
                        model: 4
                        Rectangle {
                            id: appCardBar
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 2
                            radius: 1
                            height: 4
                            color: appCardRoot.tint
                            SequentialAnimation on height {
                                running: appCardBars.visible && appCardRoot.visible && !!appCardRoot.backend.opened
                                loops: Animation.Infinite
                                NumberAnimation { to: 4 + (appCardBar.index * 5 % 9); duration: 260 + appCardBar.index * 70; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 3; duration: 300 + appCardBar.index * 50; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 12 - appCardBar.index * 2; duration: 220 + appCardBar.index * 60; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
                Item {
                    width: Math.max(0, parent.width - appCardName.width - appCardBars.width - appCardPercent.implicitWidth - 16)
                    height: 1
                }
                Text {
                    id: appCardPercent
                    anchors.verticalCenter: parent.verticalCenter
                    text: appCardRoot.muted ? "MUTED" : String(Math.round(appCardRoot.level * 100)).padStart(3, "0") + "%"
                    color: appCardRoot.muted ? Theme.danger : appCardRoot.tint
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
            }
            Slider {
                id: appCardSlider
                objectName: "appVolume"
                width: parent.width
                height: 16
                from: 0
                to: 1.5
                stepSize: 0.01
                leftPadding: 0
                rightPadding: 0
                value: appCardRoot.level
                enabled: !!appCardRoot.audio
                opacity: appCardRoot.muted ? 0.4 : 1
                Accessible.name: "App volume"
                onMoved: {
                    if (appCardRoot.audio)
                        appCardRoot.audio.volume = value;
                }
                background: Item {
                    x: appCardSlider.leftPadding
                    y: (appCardSlider.height - height) / 2
                    width: appCardSlider.availableWidth
                    height: 6
                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: "#1ae6d7dc"
                    }
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            x: parent.width * (index + 1) / 3 - 0.5
                            width: 1
                            height: parent.height
                            color: "#33000000"
                        }
                    }
                    Rectangle {
                        width: appCardSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.darker(appCardRoot.tint, 1.6) }
                            GradientStop { position: 1; color: appCardRoot.tint }
                        }
                    }
                }
                handle: Rectangle {
                    x: appCardSlider.leftPadding + appCardSlider.visualPosition * (appCardSlider.availableWidth - width)
                    y: (appCardSlider.height - height) / 2
                    width: 4
                    height: appCardSlider.pressed || appCardSlider.hovered ? 16 : 12
                    radius: 2
                    color: "#e6d7dc"
                    Behavior on height { NumberAnimation { duration: 120 } }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: appCardRoot.tint
                        shadowBlur: 0.8
                        shadowOpacity: 0.9
                    }
                }
            }
        }
        Rectangle {
            id: appCardMute
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: appCardRoot.muted ? Qt.rgba(0.851, 0.451, 0.498, 0.18) : appCardMuteHit.containsMouse ? "#26e6d7dc" : "#12e6d7dc"
            border.width: 1
            border.color: appCardRoot.muted ? Theme.danger : appCardMuteHit.containsMouse ? Qt.rgba(appCardRoot.tint.r, appCardRoot.tint.g, appCardRoot.tint.b, 0.6) : "#26e6d7dc"
            scale: appCardMuteHit.pressed ? 0.9 : 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text: appCardRoot.muted ? "" : ""
                color: appCardRoot.muted ? Theme.danger : Theme.foreground
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 13
            }
            MouseArea {
                id: appCardMuteHit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (appCardRoot.audio)
                        appCardRoot.audio.muted = !appCardRoot.audio.muted;
                }
            }
            PanelToolTip {
                visible: appCardMuteHit.containsMouse
                text: appCardRoot.muted ? "Unmute app" : "Mute app"
            }
        }
    }

    component AudioViewCaption: Text {

        color: Theme.dim
        font.family: "sans-serif"
        font.pixelSize: 11
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }

    component AudioViewIconButton: Rectangle {
        id: audioViewIconButtonButton
        property string glyph: ""
        property string label: ""
        property bool primary: false
        signal clicked
        width: 26
        height: 26
        radius: 9
        opacity: enabled ? 1 : 0.25
        color: primary ? Theme.accent : audioViewIconButtonHit.containsMouse || activeFocus ? Theme.hover : Theme.background
        border.width: 1
        border.color: primary ? Qt.rgba(0.902, 0.843, 0.863, 0.22) : audioViewIconButtonHit.containsMouse || activeFocus ? Theme.border : "#40362d34"
        scale: audioViewIconButtonHit.pressed ? 0.93 : 1
        activeFocusOnTab: true
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            anchors.centerIn: parent
            text: audioViewIconButtonButton.glyph
            color: audioViewIconButtonButton.primary ? Theme.background : Theme.foreground
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: audioViewIconButtonButton.primary ? 13 : 11
        }
        MouseArea {
            id: audioViewIconButtonHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: audioViewIconButtonButton.clicked()
        }
        PanelToolTip {
            visible: audioViewIconButtonHit.containsMouse
            text: audioViewIconButtonButton.label
        }
    }

    component AudioViewProgressSlider: Slider {
        id: audioViewProgressSliderSlider
        from: 0
        to: 1
        height: 24
        leftPadding: 0
        rightPadding: 0
        hoverEnabled: true
        onVisualPositionChanged: audioViewProgressSliderWave.requestPaint()
        background: Canvas {
            id: audioViewProgressSliderWave
            x: audioViewProgressSliderSlider.leftPadding
            y: (audioViewProgressSliderSlider.height - height) / 2
            width: audioViewProgressSliderSlider.availableWidth
            height: 14
            onWidthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 1.5;
                ctx.lineCap = "round";
                var end = audioViewProgressSliderSlider.visualPosition * width;
                function draw(color, start, finish) {
                    if (finish <= start)
                        return;
                    ctx.beginPath();
                    ctx.strokeStyle = color;
                    for (var x = start; x <= finish; x += 1) {
                        var y = height / 2 + Math.sin(x * Math.PI / 12) * 2.3;
                        if (x === start)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }
                draw(Theme.track, 0, width);
                draw(Theme.accent, 0, end);
            }
        }
        handle: Rectangle {
            x: audioViewProgressSliderSlider.leftPadding + audioViewProgressSliderSlider.visualPosition * (audioViewProgressSliderSlider.availableWidth - width)
            y: (audioViewProgressSliderSlider.height - height) / 2
            width: 7
            height: 7
            radius: 4
            color: Theme.accent
            opacity: audioViewProgressSliderSlider.hovered || audioViewProgressSliderSlider.pressed || audioViewProgressSliderSlider.activeFocus ? 1 : 0
        }
    }

    component AudioViewVolumeSlider: Slider {
        id: audioViewVolumeSliderSlider
        from: 0
        to: 1
        stepSize: 0.01
        height: 26
        leftPadding: 0
        rightPadding: 0
        background: Rectangle {
            x: audioViewVolumeSliderSlider.leftPadding
            y: (audioViewVolumeSliderSlider.height - height) / 2
            width: audioViewVolumeSliderSlider.availableWidth
            height: 3
            radius: 2
            color: Theme.track
            Rectangle {
                width: audioViewVolumeSliderSlider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        handle: Rectangle {
            x: audioViewVolumeSliderSlider.leftPadding + audioViewVolumeSliderSlider.visualPosition * (audioViewVolumeSliderSlider.availableWidth - width)
            y: (audioViewVolumeSliderSlider.height - height) / 2
            width: 10
            height: 10
            radius: 5
            color: Theme.accent
        }
    }

    component AudioViewDeviceButton: Rectangle {
        id: audioViewDeviceButtonButton
        property string label: ""
        property string glyph: ""
        property bool selected: false
        signal clicked
        height: 38
        radius: 11
        color: selected ? Theme.selected : audioViewDeviceButtonHit.containsMouse || activeFocus ? Theme.hover : Theme.background
        border.width: 1
        border.color: selected ? Qt.rgba(0.878, 0.667, 0.733, 0.45) : audioViewDeviceButtonHit.containsMouse || activeFocus ? Theme.border : "#40362d34"
        scale: audioViewDeviceButtonHit.pressed ? 0.985 : 1
        activeFocusOnTab: true
        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            text: audioViewDeviceButtonButton.glyph
            color: audioViewDeviceButtonButton.selected ? Theme.accent : Theme.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 14
        }
        Text {
            x: 38
            width: parent.width - 70
            anchors.verticalCenter: parent.verticalCenter
            text: audioViewDeviceButtonButton.label
            color: audioViewDeviceButtonButton.selected ? Theme.foreground : Theme.muted
            font.family: "sans-serif"
            font.pixelSize: 11
            font.weight: audioViewDeviceButtonButton.selected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "✓"
            visible: audioViewDeviceButtonButton.selected
            color: Theme.accent
            font.pixelSize: 13
        }
        MouseArea {
            id: audioViewDeviceButtonHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: audioViewDeviceButtonButton.clicked()
        }
    }

    component AudioView: Item {
        id: audioViewRoot
        required property var backend
        readonly property var player: backend.player
        readonly property var bluetooth: backend.bluetoothBackend || null
        readonly property bool bluetoothExpanded: !!backend.opened && settingsExpanded && settingsSection === "bluetooth"
        function syncBluetooth() {
            if (bluetooth)
                bluetooth.embeddedOpened = bluetoothExpanded;
        }
        onBluetoothExpandedChanged: syncBluetooth()
        onBluetoothChanged: syncBluetooth()
        Component.onDestruction: if (bluetooth)
            bluetooth.embeddedOpened = false
        property bool settingsExpanded: false
        property string settingsSection: "output"
        property string hoveredSettings: ""
        property bool settingsPointerOwned: false
        Timer {
            interval: 220
            running: audioViewRoot.settingsExpanded && audioViewRoot.settingsPointerOwned && audioViewRoot.hoveredSettings === "" && !audioViewSettingsAreaHover.hovered
            onTriggered: {
                audioViewRoot.settingsExpanded = false;
                audioViewRoot.settingsPointerOwned = false;
            }
        }
        property real playbackPosition: 0
        readonly property real duration: player && player.lengthSupported && Number.isFinite(player.length) ? Math.max(0, player.length) : 0
        function updatePosition() {
            playbackPosition = player && player.positionSupported && Number.isFinite(player.position) ? Math.max(0, player.position) : 0;
        }
        function formatTime(seconds) {
            var total = Math.max(0, Math.floor(Number(seconds) || 0));
            var hours = Math.floor(total / 3600);
            var minutes = Math.floor(total / 60) % 60;
            var remainder = total % 60;
            return (hours ? hours + ":" + String(minutes).padStart(2, "0") : String(minutes)) + ":" + String(remainder).padStart(2, "0");
        }
        function seekTo(seconds) {
            if (!player || !player.canSeek || !player.positionSupported || duration <= 0 || !Number.isFinite(seconds))
                return;
            var target = Math.max(0, Math.min(duration, seconds));
            if (typeof player.seekTo === "function")
                player.seekTo(target);
            else
                player.position = target;
            updatePosition();
        }
        onPlayerChanged: updatePosition()
        Connections {
            target: audioViewRoot.player
            ignoreUnknownSignals: true
            function onPositionChanged() {
                audioViewRoot.updatePosition();
            }
            function onPostTrackChanged() {
                audioViewRoot.updatePosition();
            }
        }
        Timer {
            interval: 500
            running: !!audioViewRoot.backend.opened && !!audioViewRoot.player && !!audioViewRoot.player.positionSupported
            repeat: true
            triggeredOnStart: true
            onTriggered: audioViewRoot.updatePosition()
        }
        implicitHeight: audioViewContent.implicitHeight
        function reset() {
            audioViewScroll.contentItem.contentY = 0;
            settingsExpanded = false;
            settingsPointerOwned = false;
            hoveredSettings = "";
        }

        ScrollView {
            id: audioViewScroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: audioViewContent.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            Column {
                id: audioViewContent
                width: audioViewScroll.availableWidth
                spacing: 0

                ClippingRectangle {
                    id: audioViewArtwork
                    objectName: "artwork"
                    width: parent.width
                    height: audioViewCover.status === Image.Ready ? Math.min(300, width * 0.8) : 180
                    radius: 20
                    color: Theme.surface
                    TrackSwipe {
                        player: audioViewRoot.backend.opened ? audioViewRoot.player : null
                        volumeEnabled: audioViewRoot.backend.opened && !audioViewRoot.settingsExpanded
                        onVolumeAdjusted: function (steps) {
                            audioViewRoot.backend.setOutputVolume(Math.max(0, Math.min(1, audioViewRoot.backend.outputVolume + steps * 0.05)));
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        enabled: !audioViewRoot.settingsExpanded
                        onWheel: function (event) {
                            var delta = event.angleDelta.y / 120;
                            if (!delta && event.pixelDelta.y)
                                delta = event.pixelDelta.y / 30;
                            if (delta) {
                                audioViewRoot.backend.setOutputVolume(Math.max(0, Math.min(1, audioViewRoot.backend.outputVolume + delta * 0.05)));
                                event.accepted = true;
                            }
                        }
                    }
                    Image {
                        id: audioViewCover
                        anchors.fill: parent
                        source: audioViewRoot.player ? audioViewRoot.player.trackArtUrl : ""
                        sourceSize.width: 900
                        sourceSize.height: 900
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: audioViewCover.status !== Image.Ready
                        text: "♫"
                        color: Theme.accent
                        font.pixelSize: 46
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: "#48000000"
                            }
                            GradientStop {
                                position: 0.35
                                color: "#00000000"
                            }
                            GradientStop {
                                position: 0.65
                                color: "#50221c21"
                            }
                            GradientStop {
                                position: 1
                                color: "#f2221c21"
                            }
                        }
                    }
                    Row {
                        id: audioViewPlayerHeader
                        x: 20
                        y: 18
                        width: parent.width - 76
                        spacing: 8
                        Text {
                            objectName: "playerBluetoothToggle"
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: !!audioViewRoot.bluetooth && !!audioViewRoot.bluetooth.adapter
                            activeFocusOnTab: enabled
                            Accessible.role: Accessible.Button
                            Accessible.name: (audioViewRoot.player ? audioViewRoot.player.identity : "Audio") + (audioViewRoot.bluetooth && audioViewRoot.bluetooth.adapter && audioViewRoot.bluetooth.adapter.enabled ? ", turn Bluetooth off" : ", turn Bluetooth on")
                            Keys.onReturnPressed: audioViewRoot.bluetooth.toggleBluetooth()
                            Keys.onSpacePressed: audioViewRoot.bluetooth.toggleBluetooth()
                            width: Math.min(implicitWidth, audioViewPlayerHeader.width - (audioViewBatteryBadge.visible ? audioViewBatteryBadge.width + 8 : 0))
                            text: audioViewRoot.player ? audioViewRoot.player.identity.toUpperCase() : "SOUND"
                            color: "#e6d7dc"
                            font.family: "sans-serif"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.6
                            elide: Text.ElideRight
                            MouseArea {
                                id: audioViewAppBluetoothHit
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: audioViewRoot.bluetooth.toggleBluetooth()
                            }
                            PanelToolTip {
                                visible: audioViewAppBluetoothHit.containsMouse
                                text: audioViewRoot.bluetooth && audioViewRoot.bluetooth.adapter && audioViewRoot.bluetooth.adapter.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on"
                            }
                        }
                        Rectangle {
                            id: audioViewBatteryBadge
                            objectName: "headphoneBatteryBadge"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!audioViewRoot.backend.headphoneBattery
                            width: audioViewBatteryLabel.implicitWidth + 14
                            height: 20
                            radius: 6
                            color: "#80221c21"
                            border.width: 1
                            border.color: "#5045393f"
                            Accessible.name: audioViewRoot.backend.headphoneBattery ? audioViewRoot.backend.headphoneBattery.name + ", " + audioViewRoot.backend.headphoneBattery.percentage + "% battery" : ""
                            Text {
                                id: audioViewBatteryLabel
                                objectName: "headphoneBatteryPercentage"
                                anchors.centerIn: parent
                                text: audioViewRoot.backend.headphoneBattery ? audioViewRoot.backend.headphoneBattery.percentage + "%" : ""
                                color: audioViewRoot.backend.headphoneBattery && audioViewRoot.backend.headphoneBattery.percentage <= 15 ? "#dda07f" : "#d69aac"
                                font.family: "sans-serif"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: audioViewBatteryHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                            PanelToolTip {
                                visible: audioViewBatteryHover.containsMouse
                                text: audioViewRoot.backend.headphoneBattery ? audioViewRoot.backend.headphoneBattery.name + " battery" : ""
                            }
                        }
                    }
                    AudioViewIconButton {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 48
                        anchors.topMargin: 12
                        glyph: "󰲸"
                        label: "Music library"
                        onClicked: audioViewRoot.backend.openLibrary()
                        color: "#70000000"
                    }
                    AudioViewIconButton {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 14
                        anchors.topMargin: 12
                        glyph: "\uf00d"
                        label: "Close"
                        onClicked: audioViewRoot.backend.close()
                        color: "#70000000"
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 22
                        anchors.rightMargin: 22
                        anchors.bottomMargin: 12
                        spacing: 7
                        Text {
                            width: parent.width
                            text: audioViewRoot.player ? audioViewRoot.player.trackTitle || "Unknown track" : "Nothing playing"
                            textFormat: Text.PlainText
                            color: "#e6d7dc"
                            font.family: "sans-serif"
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.5
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: audioViewRoot.player ? audioViewRoot.player.trackArtist || audioViewRoot.player.identity : "Play something to get started"
                            textFormat: Text.PlainText
                            color: "#d69aac"
                            font.family: "sans-serif"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: audioViewBodyContent.implicitHeight + 40
                    Column {
                        id: audioViewBodyContent
                        x: 20
                        y: 20
                        width: parent.width - 40
                        spacing: 16
                        Column {
                            width: parent.width
                            spacing: 0
                            AudioViewProgressSlider {
                                id: audioViewProgress
                                objectName: "playbackProgress"
                                property var seekPlayer: null
                                property string seekTitle: ""
                                width: parent.width
                                to: Math.max(1, audioViewRoot.duration)
                                stepSize: 1
                                value: Math.min(audioViewRoot.playbackPosition, audioViewRoot.duration)
                                enabled: !!audioViewRoot.player && audioViewRoot.player.canSeek && audioViewRoot.player.positionSupported && audioViewRoot.duration > 0
                                Accessible.name: "Playback progress"
                                onMoved: if (!pressed)
                                    audioViewRoot.seekTo(value)
                                onPressedChanged: {
                                    if (pressed) {
                                        seekPlayer = audioViewRoot.player;
                                        seekTitle = audioViewRoot.player ? audioViewRoot.player.trackTitle : "";
                                    } else if (seekPlayer && seekPlayer === audioViewRoot.player && seekTitle === audioViewRoot.player.trackTitle) {
                                        audioViewRoot.seekTo(value);
                                        seekPlayer = null;
                                    }
                                }
                            }
                            Item {
                                width: parent.width
                                height: 14
                                Text {
                                    anchors.left: parent.left
                                    text: audioViewRoot.formatTime(audioViewProgress.pressed ? audioViewProgress.value : Math.min(audioViewRoot.playbackPosition, audioViewRoot.duration || audioViewRoot.playbackPosition))
                                    color: Theme.dim
                                    font.family: "sans-serif"
                                    font.pixelSize: 10
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: audioViewRoot.duration > 0 ? audioViewRoot.formatTime(audioViewRoot.duration) : "--:--"
                                    color: Theme.dim
                                    font.family: "sans-serif"
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 40
                            Row {
                                anchors.centerIn: parent
                                spacing: 24
                                AudioViewIconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: "\uf048"
                                    label: "Previous"
                                    enabled: !!audioViewRoot.player && audioViewRoot.player.canGoPrevious
                                    onClicked: audioViewRoot.player.previous()
                                }
                                AudioViewIconButton {
                                    width: 40
                                    height: 40
                                    primary: true
                                    glyph: audioViewRoot.player && audioViewRoot.player.isPlaying ? "\uf04c" : "\uf04b"
                                    label: audioViewRoot.player && audioViewRoot.player.isPlaying ? "Pause" : "Play"
                                    enabled: !!audioViewRoot.player && (audioViewRoot.player.isPlaying ? audioViewRoot.player.canPause : audioViewRoot.player.canPlay)
                                    onClicked: audioViewRoot.player.togglePlaying()
                                }
                                AudioViewIconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: "\uf051"
                                    label: "Next"
                                    enabled: !!audioViewRoot.player && audioViewRoot.player.canGoNext
                                    onClicked: audioViewRoot.player.next()
                                }
                            }
                            AudioViewIconButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: "\uf04d"
                                label: audioViewRoot.player && audioViewRoot.player.canQuit ? "Quit player" : "Stop playback"
                                enabled: !!audioViewRoot.player && (audioViewRoot.player.canQuit || audioViewRoot.player.canControl)
                                onClicked: {
                                    if (audioViewRoot.player.canQuit)
                                        audioViewRoot.player.quit();
                                    else
                                        audioViewRoot.player.stop();
                                }
                            }
                        }

                        Row {
                            id: audioViewSettingsGrid
                            readonly property real cell: (width - spacing * 4) / 5
                            readonly property var current: {
                                for (var index = 0; index < children.length; index++) {
                                    var child = children[index];
                                    if (child.section === audioViewRoot.settingsSection)
                                        return child;
                                }
                                return null;
                            }
                            width: parent.width
                            spacing: 4
                            AudioViewSettingsButton {
                                contextRoot: audioViewRoot
                                section: "output"
                                label: "Output"
                                glyph: ""
                                tint: "#d69aac"
                                lit: !!audioViewRoot.backend.sink
                                detail: audioViewRoot.backend.sink ? audioViewRoot.backend.nodeLabel(audioViewRoot.backend.sink) : "No output device"
                                width: audioViewSettingsGrid.cell
                            }
                            AudioViewSettingsButton {
                                contextRoot: audioViewRoot
                                section: "input"
                                label: "Mic"
                                glyph: ""
                                tint: "#d69aac"
                                lit: !!audioViewRoot.backend.source
                                detail: audioViewRoot.backend.source ? audioViewRoot.backend.nodeLabel(audioViewRoot.backend.source) : "No microphone"
                                width: audioViewSettingsGrid.cell
                            }
                            AudioViewSettingsButton {
                                contextRoot: audioViewRoot
                                section: "apps"
                                label: "Apps"
                                glyph: ""
                                tint: "#dda07f"
                                lit: audioViewRoot.backend.streams.length > 0
                                detail: audioViewRoot.backend.streams.length + (audioViewRoot.backend.streams.length === 1 ? " active stream" : " active streams")
                                width: audioViewSettingsGrid.cell
                            }
                            AudioViewSettingsButton {
                                contextRoot: audioViewRoot
                                section: "bluetooth"
                                label: "Bluetooth"
                                glyph: ""
                                tint: "#d69aac"
                                lit: !!audioViewRoot.bluetooth && !!audioViewRoot.bluetooth.adapter && !!audioViewRoot.bluetooth.adapter.enabled
                                detail: !audioViewRoot.bluetooth || !audioViewRoot.bluetooth.adapter ? "No adapter" : !audioViewRoot.bluetooth.adapter.enabled ? "Off" : audioViewRoot.bluetooth.connectedRows ? audioViewRoot.bluetooth.connectedRows.length + " connected" : "On"
                                width: audioViewSettingsGrid.cell
                            }
                            AudioViewSettingsButton {
                                contextRoot: audioViewRoot
                                section: "playback"
                                label: "Playback"
                                glyph: ""
                                tint: "#a9c4a0"
                                lit: audioViewRoot.backend.autoPlay
                                detail: audioViewRoot.backend.autoPlay ? "Autoplay enabled" : "Autoplay disabled"
                                width: audioViewSettingsGrid.cell
                            }
                        }
                        Column {
                            id: audioViewSettingsArea
                            objectName: "settingsArea"
                            width: parent.width
                            spacing: 12
                            visible: audioViewRoot.settingsExpanded
                            HoverHandler {
                                id: audioViewSettingsAreaHover
                            }
                            Rectangle {
                                id: audioViewSettingsStatus
                                readonly property var current: audioViewSettingsGrid.current
                                readonly property color tint: current ? current.tint : Theme.accent
                                width: parent.width
                                height: 34
                                radius: 17
                                color: Qt.rgba(tint.r, tint.g, tint.b, 0.1)
                                border.width: 1
                                border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.3)
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on border.color { ColorAnimation { duration: 180 } }
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        color: audioViewSettingsStatus.tint
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }
                                    Text {
                                        id: audioViewSettingsStatusLabel
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: audioViewSettingsStatus.current ? audioViewSettingsStatus.current.label : ""
                                        color: Theme.foreground
                                        font.family: "sans-serif"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - audioViewSettingsStatusLabel.implicitWidth - 31
                                        text: audioViewSettingsStatus.current ? audioViewSettingsStatus.current.detail : ""
                                        color: Theme.muted
                                        font.family: "sans-serif"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            Bluetooth.QuickView {
                                objectName: "audioBluetoothDevices"
                                width: parent.width
                                visible: audioViewRoot.settingsSection === "bluetooth"
                                backend: audioViewRoot.bluetooth
                            }
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#2c252b"
                            }
                            Rectangle {
                                id: audioViewAutoplayToggle
                                width: parent.width
                                height: 54
                                radius: 11
                                visible: audioViewRoot.settingsSection === "playback"
                                color: Theme.background
                                border.width: 1
                                border.color: "#40362d34"
                                activeFocusOnTab: true
                                Accessible.role: Accessible.CheckBox
                                Accessible.name: "Autoplay music when Audio opens"
                                Accessible.checked: audioViewRoot.backend.autoPlay
                                Keys.onReturnPressed: audioViewRoot.backend.toggleAutoplay()
                                Keys.onSpacePressed: audioViewRoot.backend.toggleAutoplay()
                                Text {
                                    x: 12
                                    y: 9
                                    text: "Autoplay on open"
                                    color: Theme.foreground
                                    font.family: "sans-serif"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    x: 12
                                    y: 27
                                    width: parent.width - 72
                                    text: "Play random music when nothing else is playing"
                                    color: Theme.muted
                                    font.family: "sans-serif"
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    id: audioViewAutoplaySwitch
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 38
                                    height: 22
                                    radius: 11
                                    color: audioViewRoot.backend.autoPlay ? Theme.accent : Theme.surface
                                    border.width: 1
                                    border.color: audioViewRoot.backend.autoPlay ? Qt.rgba(0.902, 0.843, 0.863, 0.22) : Theme.border
                                    Rectangle {
                                        x: audioViewRoot.backend.autoPlay ? parent.width - width - 3 : 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: audioViewRoot.backend.autoPlay ? Theme.background : Theme.muted
                                        Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audioViewRoot.backend.toggleAutoplay()
                                }
                            }
                            Column {
                                width: parent.width
                                spacing: 6
                                visible: audioViewRoot.settingsSection === "output"
                                AudioViewCaption {
                                    text: "Output devices"
                                }
                                Repeater {
                                    model: audioViewRoot.backend.outputs
                                    AudioViewDeviceButton {
                                        required property var modelData
                                        width: audioViewBodyContent.width
                                        label: audioViewRoot.backend.nodeLabel(modelData)
                                        glyph: audioViewRoot.backend.sinkGlyph(modelData)
                                        selected: !!audioViewRoot.backend.sink && audioViewRoot.backend.sink.id === modelData.id
                                        onClicked: audioViewRoot.backend.setDefaultSink(modelData)
                                    }
                                }
                                AudioViewCaption {
                                    visible: audioViewRoot.backend.outputs.length === 0
                                    text: "No output devices available"
                                }
                            }
                            Column {
                                width: parent.width
                                spacing: 10
                                visible: audioViewRoot.settingsSection === "input"
                                Row {
                                    width: parent.width
                                    AudioViewCaption {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Microphone"
                                        width: parent.width - 26
                                    }
                                    AudioViewIconButton {
                                        glyph: audioViewRoot.backend.inputMuted ? "\uf131" : "\uf130"
                                        label: audioViewRoot.backend.inputMuted ? "Unmute microphone" : "Mute microphone"
                                        enabled: !!audioViewRoot.backend.source && !!audioViewRoot.backend.source.audio
                                        onClicked: audioViewRoot.backend.toggleInputMute()
                                    }
                                }
                                AudioViewVolumeSlider {
                                    objectName: "microphoneVolume"
                                    width: parent.width
                                    value: audioViewRoot.backend.inputVolume
                                    enabled: !!audioViewRoot.backend.source && !!audioViewRoot.backend.source.audio
                                    opacity: audioViewRoot.backend.inputMuted ? 0.35 : 1
                                    Accessible.name: "Microphone volume"
                                    onMoved: audioViewRoot.backend.setInputVolume(value)
                                }
                                Repeater {
                                    model: audioViewRoot.backend.inputs
                                    AudioViewDeviceButton {
                                        required property var modelData
                                        width: audioViewBodyContent.width
                                        label: audioViewRoot.backend.nodeLabel(modelData)
                                        glyph: "\uf130"
                                        selected: !!audioViewRoot.backend.source && audioViewRoot.backend.source.id === modelData.id
                                        onClicked: audioViewRoot.backend.setDefaultSource(modelData)
                                    }
                                }
                                AudioViewCaption {
                                    visible: audioViewRoot.backend.inputs.length === 0
                                    text: "No microphone available"
                                }
                            }
                            Column {
                                width: parent.width
                                spacing: 10
                                visible: audioViewRoot.settingsSection === "apps"
                                AudioViewCaption {
                                    text: "APP MIXER"
                                    color: Theme.muted
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.6
                                }
                                Repeater {
                                    model: audioViewRoot.backend.streams
                                    AudioViewAppCard {
                                        required property var modelData
                                        required property int index
                                        node: modelData
                                        backend: audioViewRoot.backend
                                        position: index
                                        width: audioViewBodyContent.width
                                    }
                                }
                                AudioViewCaption {
                                    visible: audioViewRoot.backend.streams.length === 0
                                    text: "No apps playing audio"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component LocalPlayer: Item {
        id: localPlayerRoot
        property bool polling: false
        property var state: ({
                path: ""
            })
        readonly property string identity: "Music"
        readonly property string desktopEntry: "y_music"
        readonly property string dbusName: "local.y_music"
        readonly property bool available: !!state.path
        readonly property bool isPlaying: available && !state.paused
        readonly property string trackTitle: state.title || ""
        readonly property string trackArtist: state.artist || ""
        readonly property string trackArtUrl: state.cover || ""
        readonly property real length: state.duration || 0
        readonly property real position: state.position || 0
        readonly property bool lengthSupported: available
        readonly property bool positionSupported: available
        readonly property bool canSeek: available && length > 0
        readonly property bool canPlay: available
        readonly property bool canPause: available
        readonly property bool canControl: available
        readonly property bool canGoNext: available
        readonly property bool canGoPrevious: available
        readonly property bool canQuit: false
        readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/local_player.py"
        function refresh() {
            if (!localPlayerQuery.running)
                localPlayerQuery.running = true;
        }
        function run(command, value) {
            if (localPlayerAction.running || !available)
                return;
            localPlayerAction.command = ["python3", "-B", script, command];
            if (value !== undefined)
                localPlayerAction.command = localPlayerAction.command.concat([String(value)]);
            localPlayerAction.running = true;
        }
        function next() {
            run("next");
        }
        function previous() {
            run("previous");
        }
        function togglePlaying() {
            run("toggle");
        }
        function stop() {
            run("stop");
        }
        function seekTo(value) {
            run("seek", value);
        }
        Timer {
            interval: 500
            running: localPlayerRoot.polling
            triggeredOnStart: true
            repeat: true
            onTriggered: localPlayerRoot.refresh()
        }
        Process {
            id: localPlayerQuery
            command: ["python3", "-B", localPlayerRoot.script, "state"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        localPlayerRoot.state = JSON.parse(text);
                    } catch (error) {
                        localPlayerRoot.state = {
                            path: ""
                        };
                    }
                }
            }
        }
        Process {
            id: localPlayerAction
            onExited: localPlayerRoot.refresh()
        }
    }

    component TrackSwipe: DragHandler {
        id: trackSwipeGesture
        property var player: null
        property var gesturePlayer: null
        property bool triggered: false
        property bool volumeEnabled: false
        property string direction: ""
        property int volumeSteps: 0
        signal volumeAdjusted(int steps)
        target: null
        enabled: !!player || volumeEnabled
        xAxis.enabled: true
        yAxis.enabled: volumeEnabled
        dragThreshold: 12
        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
        onActiveChanged: {
            if (active) {
                gesturePlayer = player;
                triggered = false;
                direction = "";
                volumeSteps = 0;
            }
        }
        onActiveTranslationChanged: {
            if (!active)
                return;
            var horizontal = Math.abs(activeTranslation.x);
            var vertical = Math.abs(activeTranslation.y);
            if (!direction && Math.max(horizontal, vertical) >= 20)
                direction = volumeEnabled && vertical > horizontal ? "volume" : "track";
            if (direction === "volume") {
                var steps = Math.trunc(-activeTranslation.y / 24);
                if (steps !== volumeSteps) {
                    var delta = steps - volumeSteps;
                    volumeSteps = steps;
                    volumeAdjusted(delta);
                }
                return;
            }
            if (direction !== "track" || triggered || horizontal < 48)
                return;
            triggered = true;
            if (!player || player !== gesturePlayer)
                return;
            if (activeTranslation.x < 0 && player.canGoNext)
                player.next();
            else if (activeTranslation.x > 0 && player.canGoPrevious)
                player.previous();
        }
    }
}
