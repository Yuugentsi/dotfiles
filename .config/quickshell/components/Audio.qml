import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../controls"
import "../scripts/AudioModel.js" as Model
import Quickshell.Widgets

Item {
    id: root
    property bool opened: false
    property real popupX: 228
    property var bluetoothBackend: null
    signal backRequested
    signal panelRequested(string panel)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values
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
        opened = true;
    }
    function close() {
        opened = false;
    }
    function toggle() {
        opened = !opened;
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
                root.refreshModels();
                root.resolveVolumeSink();
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
    IpcHandler {
        target: "audio"
        function toggle(): void {
            root.toggle();
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
            currentPanel: "audio"
            onSelected: function (panel) {
                root.panelRequested(panel);
            }
        }
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(400, panel.width - 32)
            height: Math.min(view.implicitHeight, panel.height - 112)
            radius: 20
            color: "#1d1b22"
            clip: true
            border.width: 1
            border.color: "#3c3545"
            focus: true
            Keys.onEscapePressed: root.close()
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
        color: primary ? "#c3b7ff" : audioPlaybackPlaybackButtonHit.containsMouse || activeFocus ? "#383044" : "#222128"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            anchors.centerIn: parent
            text: audioPlaybackPlaybackButtonButton.glyph
            color: audioPlaybackPlaybackButtonButton.primary ? "#19171c" : audioPlaybackPlaybackButtonButton.danger ? "#e28b9b" : "#c3b7ff"
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
                    color: "#eef3f8"
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
                    color: "#aaa6b5"
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

    component AudioViewSettingsButton: Rectangle {
        id: audioViewSettingsButtonButton
        required property var contextRoot
        property string section: ""
        property string label: ""
        property string glyph: ""
        readonly property bool selected: contextRoot.settingsExpanded && contextRoot.settingsSection === section
        objectName: "settings-" + section
        width: glyph ? 28 : audioViewSettingsButtonCaption.implicitWidth + 16
        height: 28
        radius: 7
        color: selected ? "#383044" : audioViewSettingsButtonHit.containsMouse || activeFocus ? "#2a2630" : "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        function toggle() {
            contextRoot.settingsPointerOwned = false;
            if (selected)
                contextRoot.settingsExpanded = false;
            else {
                contextRoot.settingsSection = section;
                contextRoot.settingsExpanded = true;
            }
        }
        Keys.onReturnPressed: toggle()
        Keys.onSpacePressed: toggle()
        Text {
            id: audioViewSettingsButtonCaption
            anchors.centerIn: parent
            text: audioViewSettingsButtonButton.glyph || audioViewSettingsButtonButton.label
            color: audioViewSettingsButtonButton.selected ? "#d8caff" : "#aaa6b5"
            font.family: audioViewSettingsButtonButton.glyph ? "Symbols Nerd Font Mono" : "sans-serif"
            font.pixelSize: audioViewSettingsButtonButton.glyph ? 14 : 10
        }
        Timer {
            interval: 160
            running: audioViewSettingsButtonHit.containsMouse && !audioViewSettingsButtonButton.selected
            onTriggered: {
                contextRoot.settingsSection = audioViewSettingsButtonButton.section;
                contextRoot.settingsExpanded = true;
                contextRoot.settingsPointerOwned = true;
            }
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
    }

    component AudioViewCaption: Text {

        color: "#928b96"
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
        radius: width / 2
        opacity: enabled ? 1 : 0.25
        color: primary ? audioViewIconButtonHit.containsMouse ? "#ded4ff" : "#c3b7ff" : audioViewIconButtonHit.containsMouse || activeFocus ? "#302938" : "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            anchors.centerIn: parent
            text: audioViewIconButtonButton.glyph
            color: audioViewIconButtonButton.primary ? "#19171c" : "#aaa6b5"
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
                draw("#51465f", 0, width);
                draw("#c3b7ff", 0, end);
            }
        }
        handle: Rectangle {
            x: audioViewProgressSliderSlider.leftPadding + audioViewProgressSliderSlider.visualPosition * (audioViewProgressSliderSlider.availableWidth - width)
            y: (audioViewProgressSliderSlider.height - height) / 2
            width: 7
            height: 7
            radius: 4
            color: "#e2d8ff"
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
            color: "#3d3745"
            Rectangle {
                width: audioViewVolumeSliderSlider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: "#c3b7ff"
            }
        }
        handle: Rectangle {
            x: audioViewVolumeSliderSlider.leftPadding + audioViewVolumeSliderSlider.visualPosition * (audioViewVolumeSliderSlider.availableWidth - width)
            y: (audioViewVolumeSliderSlider.height - height) / 2
            width: 10
            height: 10
            radius: 5
            color: "#d8caff"
        }
    }

    component AudioViewDeviceButton: Rectangle {
        id: audioViewDeviceButtonButton
        property string label: ""
        property string glyph: ""
        property bool selected: false
        signal clicked
        height: 32
        radius: 7
        color: selected ? "#383044" : audioViewDeviceButtonHit.containsMouse || activeFocus ? "#2a2630" : "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: audioViewDeviceButtonButton.glyph
            color: "#c3b7ff"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 12
        }
        Text {
            x: 34
            width: parent.width - 64
            anchors.verticalCenter: parent.verticalCenter
            text: audioViewDeviceButtonButton.label
            color: "#aaa6b5"
            font.family: "sans-serif"
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "✓"
            visible: audioViewDeviceButtonButton.selected
            color: "#c3b7ff"
            font.pixelSize: 12
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
        property bool volumeExpanded: false
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
                    color: "#302938"
                    TrackSwipe {
                        player: audioViewRoot.backend.opened ? audioViewRoot.player : null
                        volumeEnabled: audioViewRoot.backend.opened
                        onVolumeAdjusted: function (steps) {
                            audioViewRoot.backend.setOutputVolume(Math.max(0, Math.min(1, audioViewRoot.backend.outputVolume + steps * 0.05)));
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
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
                        color: "#c3b7ff"
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
                                color: "#500e0b13"
                            }
                            GradientStop {
                                position: 1
                                color: "#f21d1b22"
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
                            color: "#e9e4ef"
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
                            color: "#801b1325"
                            border.width: 1
                            border.color: "#505f4b74"
                            Accessible.name: audioViewRoot.backend.headphoneBattery ? audioViewRoot.backend.headphoneBattery.name + ", " + audioViewRoot.backend.headphoneBattery.percentage + "% battery" : ""
                            Text {
                                id: audioViewBatteryLabel
                                objectName: "headphoneBatteryPercentage"
                                anchors.centerIn: parent
                                text: audioViewRoot.backend.headphoneBattery ? audioViewRoot.backend.headphoneBattery.percentage + "%" : ""
                                color: audioViewRoot.backend.headphoneBattery && audioViewRoot.backend.headphoneBattery.percentage <= 15 ? "#ffb18f" : "#d9c7ef"
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
                            color: "#f7f3fc"
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
                            color: "#bdb3c9"
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
                                    color: "#928b96"
                                    font.family: "sans-serif"
                                    font.pixelSize: 10
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: audioViewRoot.duration > 0 ? audioViewRoot.formatTime(audioViewRoot.duration) : "--:--"
                                    color: "#928b96"
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

                        Item {
                            width: parent.width
                            height: 32
                            Item {
                                id: audioViewVolumeControl
                                width: parent.width - audioViewShortcuts.width - 12
                                height: 32
                                readonly property bool expanded: audioViewRoot.volumeExpanded || audioViewOutputSlider.activeFocus || audioViewVolumeToggle.activeFocus
                                HoverHandler {
                                    onHoveredChanged: audioViewRoot.volumeExpanded = hovered
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    z: 10
                                    acceptedButtons: Qt.NoButton
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
                                AudioViewIconButton {
                                    id: audioViewVolumeToggle
                                    objectName: "volumeToggle"
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: audioViewRoot.backend.outputMuted ? "\uf6a9" : "\uf028"
                                    label: audioViewRoot.backend.outputMuted ? "Unmute output" : "Mute output"
                                    enabled: !!audioViewRoot.backend.volumeSink && !!audioViewRoot.backend.volumeSink.audio
                                    onClicked: audioViewRoot.backend.toggleOutputMute()
                                }
                                AudioViewVolumeSlider {
                                    id: audioViewOutputSlider
                                    objectName: "outputVolume"
                                    anchors.left: audioViewVolumeToggle.right
                                    anchors.right: audioViewPercentage.left
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: audioViewVolumeControl.expanded
                                    value: audioViewRoot.backend.outputVolume
                                    enabled: !!audioViewRoot.backend.volumeSink && !!audioViewRoot.backend.volumeSink.audio
                                    opacity: audioViewRoot.backend.outputMuted ? 0.35 : 1
                                    Accessible.name: "Output volume"
                                    onMoved: audioViewRoot.backend.setOutputVolume(value)
                                }
                                Text {
                                    id: audioViewPercentage
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    text: Math.round((audioViewOutputSlider.pressed ? audioViewOutputSlider.value : audioViewRoot.backend.outputVolume) * 100) + "%"
                                    color: "#aaa6b5"
                                    font.family: "sans-serif"
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    anchors.left: audioViewVolumeToggle.right
                                    anchors.right: audioViewPercentage.left
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !audioViewVolumeControl.expanded
                                    text: audioViewRoot.backend.sink ? audioViewRoot.backend.nodeLabel(audioViewRoot.backend.sink) : "No output"
                                    color: "#716c76"
                                    font.family: "sans-serif"
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                            Row {
                                id: audioViewShortcuts
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                AudioViewSettingsButton {
                                    contextRoot: audioViewRoot
                                    section: "output"
                                    label: "Output"
                                }
                                AudioViewSettingsButton {
                                    contextRoot: audioViewRoot
                                    section: "input"
                                    label: "Mic"
                                }
                                AudioViewSettingsButton {
                                    contextRoot: audioViewRoot
                                    section: "apps"
                                    label: "Apps"
                                }
                                AudioViewSettingsButton {
                                    contextRoot: audioViewRoot
                                    section: "bluetooth"
                                    label: "Bluetooth"
                                    glyph: "\uf293"
                                }
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
                            Bluetooth.QuickView {
                                objectName: "audioBluetoothDevices"
                                width: parent.width
                                visible: audioViewRoot.settingsSection === "bluetooth"
                                backend: audioViewRoot.bluetooth
                            }
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#302c36"
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
                                    text: "App volume"
                                }
                                Repeater {
                                    model: audioViewRoot.backend.streams
                                    Column {
                                        id: audioViewApp
                                        required property var modelData
                                        width: audioViewBodyContent.width
                                        spacing: 4
                                        Row {
                                            width: parent.width
                                            AudioViewCaption {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 26
                                                text: audioViewRoot.backend.streamLabel(audioViewApp.modelData)
                                            }
                                            AudioViewIconButton {
                                                glyph: audioViewApp.modelData.audio && audioViewApp.modelData.audio.muted ? "\uf6a9" : "\uf028"
                                                label: "Mute or unmute app"
                                                onClicked: {
                                                    if (audioViewApp.modelData.audio)
                                                        audioViewApp.modelData.audio.muted = !audioViewApp.modelData.audio.muted;
                                                }
                                            }
                                        }
                                        AudioViewVolumeSlider {
                                            objectName: "appVolume"
                                            width: parent.width
                                            to: 1.5
                                            value: audioViewApp.modelData.audio ? audioViewApp.modelData.audio.volume : 0
                                            opacity: audioViewApp.modelData.audio && audioViewApp.modelData.audio.muted ? 0.35 : 1
                                            Accessible.name: "App volume"
                                            onMoved: {
                                                if (audioViewApp.modelData.audio)
                                                    audioViewApp.modelData.audio.volume = value;
                                            }
                                        }
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
