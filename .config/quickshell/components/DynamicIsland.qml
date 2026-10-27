pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Wayland

Item {
    id: root
    required property var audioBackend
    required property var displayBackend
    property bool available: true
    property bool automaticNotifications: false
    property bool initialized: false
    property bool doNotDisturb: false
    property bool settingsReady: false
    property string settingsError: ""
    property int interactions: 0
    property string eventType: ""
    property string eventTitle: ""
    property string eventDetail: ""
    property real eventValue: -1
    property int eventSerial: 0
    property string targetScreen: ""
    property string backlightPath: ""
    property string userId: ""
    property real brightness: -1
    property real maximumBrightness: 0
    property bool recording: false
    property var currentNotification: null
    readonly property var notifications: notificationServer.trackedNotifications.values
    readonly property var player: audioBackend.player
    readonly property var playerWindow: {
        if (!player)
            return null;
        const normalize = value => String(value || "").toLowerCase().replace(/\.desktop$/, "").replace(/\s+/g, "");
        const entry = player.desktopEntry ? DesktopEntries.heuristicLookup(player.desktopEntry) : null;
        const identifiers = [player.desktopEntry, player.identity, entry ? entry.startupClass : "", entry ? entry.id : ""].map(normalize).filter(value => value.length > 0);
        const windows = Array.from(ToplevelManager.toplevels.values).filter(window => {
            const appId = normalize(window.appId);
            return appId && identifiers.some(identifier => appId === identifier || appId.endsWith("." + identifier));
        });
        return windows.find(window => window.activated) || windows[0] || null;
    }
    readonly property bool playing: !!player && player.isPlaying
    readonly property string trackTitle: player ? player.trackTitle || player.identity || "Music" : "Nothing playing"
    readonly property string trackArtist: player ? player.trackArtist || player.identity || "" : "Open a music player"
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery && battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * 100) : -1
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property bool microphoneActive: Pipewire.linkGroups.values.some(group => group.state === PwLinkState.Active && group.source && !group.source.isStream && !group.source.isSink && group.target && group.target.isStream)
    readonly property real volume: audioBackend.outputVolume
    readonly property bool muted: audioBackend.outputMuted
    readonly property bool volumeAvailable: !!audioBackend.volumeSink && !!audioBackend.volumeSink.audio

    function showEvent(type, title, detail, value, duration, force) {
        if ((!automaticNotifications && !force) || !initialized || !settingsReady || !available || (doNotDisturb && (type === "notification" || type === "music") && !force))
            return;
        const monitor = Hyprland.focusedMonitor;
        targetScreen = monitor ? monitor.name : "";
        eventType = type;
        eventTitle = title;
        eventDetail = detail || "";
        eventValue = value === undefined ? -1 : value;
        eventSerial++;
        eventTimeout.interval = duration || 3000;
        if (interactions === 0)
            eventTimeout.restart();
    }
    function clearEvent() {
        eventTimeout.stop();
        eventType = "";
    }
    function setVolume(value) {
        audioBackend.setOutputVolume(value);
    }
    function setBrightness(value) {
        displayBackend.setValue("brightness", Math.round(value));
    }
    function dismissNotification() {
        if (currentNotification)
            currentNotification.dismiss();
        currentNotification = null;
        clearEvent();
    }
    function nextNotification() {
        if (!notifications.length)
            return;
        const index = notifications.indexOf(currentNotification);
        currentNotification = notifications[(index + 1) % notifications.length];
        showEvent("notification", currentNotification.summary, currentNotification.body, -1, 6000, true);
    }
    function batteryEvent() {
        if (hasBattery)
            showEvent("battery", charging ? "Charging" : "Battery", batteryPercent + "% charge", batteryPercent / 100, 3500);
    }
    onDoNotDisturbChanged: {
        if (doNotDisturb)
            clearEvent();
        if (settingsReady)
            settings.setText(JSON.stringify({
                doNotDisturb: doNotDisturb
            }) + "\n");
    }

    FileView {
        id: settings
        path: Quickshell.statePath("island.json")
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (typeof saved.doNotDisturb !== "boolean")
                    throw new Error("Invalid setting");
                root.doNotDisturb = saved.doNotDisturb;
                root.settingsError = "";
                root.settingsReady = true;
            } catch (error) {
                root.settingsError = "Could not load island settings";
            }
        }
        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound)
                root.settingsReady = true;
            else
                root.settingsError = "Could not load island settings";
        }
        onSaved: root.settingsError = ""
        onSaveFailed: root.settingsError = "Could not save island settings"
    }
    onInteractionsChanged: {
        if (interactions > 0)
            eventTimeout.stop();
        else if (eventType)
            eventTimeout.restart();
    }
    onVolumeChanged: if (volumeAvailable)
        showEvent("volume", muted ? "Muted" : "Volume", Math.round(volume * 100) + "%", Math.min(1, volume), 2000)
    onMutedChanged: if (volumeAvailable)
        showEvent("volume", muted ? "Muted" : "Volume", Math.round(volume * 100) + "%", muted ? 0 : Math.min(1, volume), 2000)
    onTrackTitleChanged: if (playing)
        showEvent("music", trackTitle, trackArtist, -1, 4500)
    onPlayingChanged: if (player)
        showEvent("music", playing ? trackTitle : "Playback paused", trackArtist, -1, 3000)
    onChargingChanged: batteryEvent()
    onBatteryPercentChanged: if (hasBattery && (batteryPercent === 20 || batteryPercent === 10 || batteryPercent === 5))
        batteryEvent()
    onMicrophoneActiveChanged: showEvent("activity", microphoneActive ? "Microphone in use" : "Microphone released", "Audio activity", -1, 3000)
    onRecordingChanged: showEvent("activity", recording ? "Screen recording" : "Recording finished", recording ? "Capture in progress" : "Capture ended", -1, 3500)
    onNotificationsChanged: {
        if (currentNotification && notifications.indexOf(currentNotification) < 0) {
            currentNotification = null;
            if (eventType === "notification")
                clearEvent();
        }
    }

    Timer {
        interval: 1800
        running: true
        onTriggered: root.initialized = true
    }
    Timer {
        id: eventTimeout
        onTriggered: root.eventType = ""
    }
    Timer {
        interval: 1200
        repeat: true
        running: true
        onTriggered: {
            if (root.backlightPath)
                brightnessFile.reload();
            recordingPid.reload();
            if (recordingName.path)
                recordingName.reload();
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "for device in /sys/class/backlight/*; do if [ -r \"$device/max_brightness\" ]; then printf '%s\\n' \"$device\"; break; fi; done; id -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.userId = lines.pop() || "";
                root.backlightPath = lines[0] || "";
            }
        }
    }
    FileView {
        id: maximumFile
        path: root.backlightPath ? root.backlightPath + "/max_brightness" : ""
        printErrors: false
        onLoaded: root.maximumBrightness = Number(text().trim())
    }
    FileView {
        id: brightnessFile
        path: root.backlightPath ? root.backlightPath + "/actual_brightness" : ""
        printErrors: false
        onLoaded: {
            if (root.maximumBrightness <= 0)
                return;
            const value = Math.round(Number(text().trim()) / root.maximumBrightness * 100);
            if (!Number.isFinite(value))
                return;
            const previous = root.brightness;
            root.brightness = value;
            if (previous >= 0 && previous !== value)
                root.showEvent("brightness", "Brightness", value + "%", value / 100, 2000);
        }
        onLoadFailed: root.brightness = -1
    }
    FileView {
        id: recordingPid
        path: root.userId ? (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr-recording-" + root.userId + ".pid" : ""
        printErrors: false
        onLoaded: {
            const pid = text().trim();
            recordingName.path = /^[0-9]+$/.test(pid) ? "/proc/" + pid + "/comm" : "";
            if (!recordingName.path)
                root.recording = false;
        }
        onLoadFailed: {
            recordingName.path = "";
            root.recording = false;
        }
    }
    FileView {
        id: recordingName
        printErrors: false
        onLoaded: root.recording = text().trim() === "wf-recorder"
        onLoadFailed: root.recording = false
    }
    NotificationServer {
        id: notificationServer
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        persistenceSupported: true
        keepOnReload: true
        onNotification: function (notification) {
            notification.tracked = true;
            if (notification.lastGeneration)
                return;
            root.currentNotification = notification;
            if (root.notifications.length > 20)
                root.notifications[0].dismiss();
            root.showEvent("notification", notification.summary, notification.body, -1, notification.urgency === NotificationUrgency.Critical ? 9000 : 6000);
        }
    }
    Repeater {
        model: root.notifications
        Item {
            id: lifetime
            required property var modelData
            Timer {
                id: expiry
                interval: lifetime.modelData.expireTimeout > 0 ? Math.min(2147483647, lifetime.modelData.expireTimeout) : 8000
                running: root.interactions === 0 && lifetime.modelData.expireTimeout !== 0 && lifetime.modelData.urgency !== NotificationUrgency.Critical
                onTriggered: lifetime.modelData.expire()
            }
            Connections {
                target: lifetime.modelData
                function onSummaryChanged() {
                    if (root.interactions === 0 && lifetime.modelData.expireTimeout !== 0 && lifetime.modelData.urgency !== NotificationUrgency.Critical)
                        expiry.restart();
                }
            }
        }
    }
    IpcHandler {
        target: "island"
        function toggle(): void {
            root.available = !root.available;
        }
        function toggleDnd(): void {
            root.doNotDisturb = !root.doNotDisturb;
            if (root.doNotDisturb)
                root.clearEvent();
        }
        function show(title: string, detail: string): void {
            root.showEvent("activity", title, detail, -1, 4000, true);
        }
        function collapse(): void {
            root.clearEvent();
        }
        function status(): string {
            return JSON.stringify({
                visible: root.available,
                automaticNotifications: root.automaticNotifications,
                event: root.eventType,
                notifications: root.notifications.length,
                dnd: root.doNotDisturb,
                settingsReady: root.settingsReady,
                settingsError: root.settingsError,
                brightness: root.brightness,
                battery: root.batteryPercent,
                recording: root.recording,
                microphone: root.microphoneActive,
                playing: root.playing,
                windows: Array.from(islandWindows.instances).map(panel => ({
                            screen: panel.screen.name,
                            expanded: panel.expanded,
                            hovered: panel.hovered,
                            pointerOwned: panel.pointerOwned,
                            pointerInside: panel.pointerInside
                        }))
            });
        }
    }
    Variants {
        id: islandWindows
        model: Quickshell.screens
        IslandWindow {
            required property var modelData
            screen: modelData
            controller: root
        }
    }

    component IslandButton: Rectangle {
        id: islandButtonRoot
        property string glyph: ""
        property string label: ""
        property bool primary: false
        signal clicked
        implicitWidth: 30
        implicitHeight: 30
        radius: Math.min(width, height) / 2
        color: primary ? (islandButtonHit.containsMouse ? "#ffab94" : "#ff786b") : islandButtonHit.containsMouse ? "#3b253e" : "transparent"
        scale: islandButtonHit.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
        border.width: primary ? 1 : 0
        border.color: primary ? "#ffbc9e" : islandButtonHit.containsMouse ? "#b56d9e" : "#70395e"
        opacity: enabled ? 1 : 0.32
        Accessible.role: Accessible.Button
        Accessible.name: label
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
        Text {
            anchors.centerIn: parent
            text: islandButtonRoot.glyph
            color: islandButtonRoot.primary ? "#19171c" : "#aaa6b5"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 13
        }
        MouseArea {
            id: islandButtonHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: islandButtonRoot.clicked()
        }
        ToolTip {
            visible: islandButtonHit.containsMouse
            delay: 600
            text: islandButtonRoot.label
            padding: 8
            contentItem: Text {
                text: islandButtonRoot.label
                color: "#e9e4ef"
                font.family: "sans-serif"
                font.pixelSize: 10
            }
            background: Rectangle {
                radius: 8
                color: "#f21d1b22"
                border.width: 1
                border.color: "#609d6c9f"
            }
        }
    }

    component IslandPlayer: Item {
        id: islandPlayerRoot
        required property var controller
        property bool active: false
        property var pointerTracker: null
        readonly property var player: controller.player
        readonly property real duration: player && player.lengthSupported && Number.isFinite(player.length) ? Math.max(0, player.length) : 0
        property real position: 0
        signal notificationsRequested
        signal playerRequested
        implicitHeight: islandPlayerLayout.implicitHeight

        function updatePosition() {
            position = player && player.positionSupported && Number.isFinite(player.position) ? Math.max(0, player.position) : 0;
        }
        function formatTime(value) {
            const seconds = Math.max(0, Math.floor(Number(value) || 0));
            const hours = Math.floor(seconds / 3600);
            const minutes = Math.floor(seconds / 60) % 60;
            return (hours ? hours + ":" + String(minutes).padStart(2, "0") : String(minutes)) + ":" + String(seconds % 60).padStart(2, "0");
        }
        function seek(value) {
            if (!player || !player.canSeek || !player.positionSupported || duration <= 0 || !Number.isFinite(value))
                return;
            const target = Math.max(0, Math.min(duration, value));
            if (typeof player.seekTo === "function")
                player.seekTo(target);
            else
                player.position = target;
            updatePosition();
        }
        onPlayerChanged: updatePosition()
        onActiveChanged: if (active)
            updatePosition()
        Connections {
            target: islandPlayerRoot.player
            ignoreUnknownSignals: true
            function onPositionChanged() {
                if (islandPlayerRoot.active)
                    islandPlayerRoot.updatePosition();
            }
            function onPostTrackChanged() {
                if (islandPlayerRoot.active)
                    islandPlayerRoot.updatePosition();
            }
        }
        Timer {
            interval: 500
            running: islandPlayerRoot.active && !!islandPlayerRoot.player && !!islandPlayerRoot.player.positionSupported
            repeat: true
            triggeredOnStart: true
            onTriggered: islandPlayerRoot.updatePosition()
        }

        Column {
            id: islandPlayerLayout
            width: parent.width
            spacing: 6

            ClippingRectangle {
                width: parent.width
                height: 148
                radius: 20
                color: "#2e1d35"
                Image {
                    anchors.fill: parent
                    source: islandPlayerRoot.player ? islandPlayerRoot.player.trackArtUrl || "" : ""
                    sourceSize.width: 400
                    sourceSize.height: 240
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 1
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#08000000"
                        }
                        GradientStop {
                            position: 0.35
                            color: "#102c1430"
                        }
                        GradientStop {
                            position: 1
                            color: "#ed21132d"
                        }
                    }
                }
                Column {
                    x: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 13
                    width: parent.width - 28
                    spacing: 4
                    Text {
                        width: parent.width
                        text: islandPlayerRoot.controller.trackTitle
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "sans-serif"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        font.letterSpacing: -0.35
                        color: "#f7f3fc"
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: islandPlayerRoot.controller.trackArtist
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "sans-serif"
                        font.pixelSize: 11
                        color: "#e0bdd4"
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: islandPlayerGestures
                    anchors.fill: parent
                    enabled: !!islandPlayerRoot.player
                    preventStealing: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    property real startX: 0
                    property real startY: 0
                    property real startVolume: 0
                    property string dragAxis: ""
                    property real horizontalScroll: 0
                    property double lastHorizontalScroll: 0
                    property bool horizontalTriggered: false
                    onWheel: function (wheel) {
                        const horizontal = wheel.angleDelta.x || wheel.pixelDelta.x;
                        const vertical = wheel.angleDelta.y || wheel.pixelDelta.y;
                        if (Math.abs(horizontal) > Math.abs(vertical)) {
                            const now = Date.now();
                            if (now - lastHorizontalScroll > 500) {
                                horizontalScroll = 0;
                                horizontalTriggered = false;
                            }
                            lastHorizontalScroll = now;
                            if (horizontalTriggered) {
                                wheel.accepted = true;
                                return;
                            }
                            horizontalScroll += horizontal;
                            const threshold = wheel.angleDelta.x ? 120 : 60;
                            if (Math.abs(horizontalScroll) >= threshold) {
                                if (horizontalScroll < 0 && islandPlayerRoot.player.canGoNext)
                                    islandPlayerRoot.player.next();
                                else if (horizontalScroll > 0 && islandPlayerRoot.player.canGoPrevious)
                                    islandPlayerRoot.player.previous();
                                horizontalScroll = 0;
                                horizontalTriggered = true;
                            }
                            wheel.accepted = true;
                        } else if (vertical && islandPlayerRoot.controller.volumeAvailable) {
                            const change = wheel.angleDelta.y ? wheel.angleDelta.y / 120 * 0.02 : wheel.pixelDelta.y * 0.001;
                            islandPlayerRoot.controller.setVolume(Math.max(0, Math.min(1, islandPlayerRoot.controller.volume + change)));
                            wheel.accepted = true;
                        }
                    }
                    onPressed: function (mouse) {
                        startX = mouse.x;
                        startY = mouse.y;
                        startVolume = islandPlayerRoot.controller.volume;
                        dragAxis = "";
                    }
                    onPositionChanged: function (mouse) {
                        if (!pressed)
                            return;
                        const horizontal = mouse.x - startX;
                        const vertical = startY - mouse.y;
                        if (!dragAxis && Math.max(Math.abs(horizontal), Math.abs(vertical)) >= 12)
                            dragAxis = Math.abs(horizontal) > Math.abs(vertical) ? "horizontal" : "vertical";
                        if (dragAxis === "vertical" && islandPlayerRoot.controller.volumeAvailable)
                            islandPlayerRoot.controller.setVolume(Math.max(0, Math.min(1, startVolume + vertical / 180)));
                    }
                    onReleased: function (mouse) {
                        if (dragAxis !== "horizontal" || !islandPlayerRoot.player)
                            return;
                        const distance = mouse.x - startX;
                        if (distance >= 36 && islandPlayerRoot.player.canGoNext)
                            islandPlayerRoot.player.next();
                        else if (distance <= -36 && islandPlayerRoot.player.canGoPrevious)
                            islandPlayerRoot.player.previous();
                    }
                    onClicked: if (!dragAxis && islandPlayerRoot.controller.playerWindow)
                        islandPlayerRoot.playerRequested()
                }


            }

            Column {
                width: parent.width
                spacing: 0
                Slider {
                    id: islandPlayerProgress
                    property var seekPlayer: null
                    property string seekTitle: ""
                    width: parent.width
                    height: 18
                    leftPadding: 0
                    rightPadding: 0
                    from: 0
                    to: Math.max(1, islandPlayerRoot.duration)
                    value: Math.min(islandPlayerRoot.position, islandPlayerRoot.duration)
                    enabled: !!islandPlayerRoot.player && islandPlayerRoot.player.canSeek && islandPlayerRoot.player.positionSupported && islandPlayerRoot.duration > 0
                    Accessible.name: "Playback progress"
                    onVisualPositionChanged: islandPlayerWave.requestPaint()
                    onMoved: if (!pressed)
                        islandPlayerRoot.seek(value)
                    onPressedChanged: {
                        if (pressed) {
                            seekPlayer = islandPlayerRoot.player;
                            seekTitle = islandPlayerRoot.controller.trackTitle;
                        } else if (seekPlayer && seekPlayer === islandPlayerRoot.player && seekTitle === islandPlayerRoot.controller.trackTitle) {
                            islandPlayerRoot.seek(value);
                            seekPlayer = null;
                        }
                    }
                    background: Canvas {
                        id: islandPlayerWave
                        width: islandPlayerProgress.availableWidth
                        height: 14
                        y: (islandPlayerProgress.height - height) / 2
                        onWidthChanged: requestPaint()
                        onPaint: {
                            const context = getContext("2d");
                            context.reset();
                            context.lineWidth = 1.5;
                            context.lineCap = "round";
                            function draw(color, finish) {
                                context.beginPath();
                                context.strokeStyle = color;
                                for (let x = 0; x <= finish; x++) {
                                    const y = height / 2 + Math.sin(x * Math.PI / 12) * 2.3;
                                    if (x === 0)
                                        context.moveTo(x, y);
                                    else
                                        context.lineTo(x, y);
                                }
                                context.stroke();
                            }
                            draw("#59405f", width);
                            const gradient = context.createLinearGradient(0, 0, width, 0);
                            gradient.addColorStop(0, "#ff786b");
                            gradient.addColorStop(0.55, "#e59bd4");
                            gradient.addColorStop(1, "#70d8df");
                            draw(gradient, width * islandPlayerProgress.visualPosition);
                        }
                    }
                    handle: Rectangle {
                        x: islandPlayerProgress.visualPosition * (islandPlayerProgress.availableWidth - width)
                        y: (islandPlayerProgress.height - height) / 2
                        width: 7
                        height: 7
                        radius: 4
                        color: "#ffc4ba"
                        opacity: islandPlayerProgress.hovered || islandPlayerProgress.pressed ? 1 : 0
                    }
                }
                Item {
                    width: parent.width
                    height: 12
                    Text {
                        anchors.left: parent.left
                        text: islandPlayerRoot.formatTime(islandPlayerProgress.pressed ? islandPlayerProgress.value : islandPlayerRoot.position)
                        color: "#928b96"
                        font.pixelSize: 9
                    }
                    Text {
                        anchors.right: parent.right
                        text: islandPlayerRoot.duration > 0 ? islandPlayerRoot.formatTime(islandPlayerRoot.duration) : "--:--"
                        color: "#928b96"
                        font.pixelSize: 9
                    }
                }
            }

            Item {
                width: parent.width
                height: 38
                Row {
                    anchors.centerIn: parent
                    spacing: 24
                    IslandButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "\uf048"
                        label: "Previous track"
                        enabled: !!islandPlayerRoot.player && islandPlayerRoot.player.canGoPrevious
                        onClicked: islandPlayerRoot.player.previous()
                    }
                    IslandButton {
                        width: 38
                        height: 38
                        primary: true
                        glyph: islandPlayerRoot.controller.playing ? "\uf04c" : "\uf04b"
                        label: islandPlayerRoot.controller.playing ? "Pause" : "Play"
                        enabled: !!islandPlayerRoot.player && (islandPlayerRoot.controller.playing ? islandPlayerRoot.player.canPause : islandPlayerRoot.player.canPlay)
                        onClicked: islandPlayerRoot.player.togglePlaying()
                    }
                    IslandButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "\uf051"
                        label: "Next track"
                        enabled: !!islandPlayerRoot.player && islandPlayerRoot.player.canGoNext
                        onClicked: islandPlayerRoot.player.next()
                    }
                }
            }


            Text {
                width: parent.width
                visible: !!islandPlayerRoot.controller.displayBackend.error || islandPlayerRoot.controller.recording || islandPlayerRoot.controller.microphoneActive
                text: islandPlayerRoot.controller.displayBackend.error ? "Could not adjust display" : islandPlayerRoot.controller.recording ? "● Recording screen" : "● Microphone in use"
                color: islandPlayerRoot.controller.displayBackend.error ? "#ffac8c" : "#b5a8c2"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    component IslandSlider: Item {
        id: islandSliderRoot
        property string glyph: ""
        property string label: ""
        property color accent: "#ff786b"
        property real value: 0
        property real minimum: 0
        property real maximum: 1
        signal moved(real value)
        implicitHeight: 24
        opacity: enabled ? 1 : 0.35
        Text {
            x: 2
            anchors.verticalCenter: parent.verticalCenter
            text: islandSliderRoot.glyph
            color: islandSliderRoot.accent
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 15
        }
        Slider {
            id: islandSliderSlider
            x: 28
            width: parent.width - 70
            height: parent.height
            from: islandSliderRoot.minimum
            to: islandSliderRoot.maximum
            value: islandSliderRoot.value
            Accessible.name: islandSliderRoot.label
            onMoved: islandSliderRoot.moved(value)
            background: Rectangle {
                x: islandSliderSlider.leftPadding
                anchors.verticalCenter: parent.verticalCenter
                width: islandSliderSlider.availableWidth
                height: 3
                radius: 3
                color: "#403647"
                Rectangle {
                    width: parent.width * islandSliderSlider.visualPosition
                    height: parent.height
                    radius: 3
                    color: islandSliderRoot.accent
                }
            }
            handle: Rectangle {
                x: islandSliderSlider.leftPadding + islandSliderSlider.visualPosition * (islandSliderSlider.availableWidth - width)
                y: (islandSliderSlider.height - height) / 2
                width: 9
                height: 9
                radius: 5
                color: islandSliderSlider.pressed ? "#ffffff" : "#ffbc9e"
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 0
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(islandSliderRoot.maximum === 100 ? islandSliderSlider.value : islandSliderSlider.value * 100) + "%"
            color: "#aaa6b5"
            font.pixelSize: 11
        }
    }

    component IslandWindow: PanelWindow {
        id: islandWindowWindow
        required property var controller
        property bool pinned: false
        property bool hovered: false
        property bool pointerOwned: false
        readonly property bool pointerInside: islandWindowSurfaceHover.hovered
        readonly property bool edgeInside: pointerInside && islandWindowSurfaceHover.point.position.x >= islandWindowRevealZone.x && islandWindowSurfaceHover.point.position.x < islandWindowRevealZone.x + islandWindowRevealZone.width && islandWindowSurfaceHover.point.position.y >= islandWindowRevealZone.y && islandWindowSurfaceHover.point.position.y < islandWindowRevealZone.y + islandWindowRevealZone.height
        property bool suppressed: false
        readonly property bool hasEvent: controller.eventType !== "" && (!controller.targetScreen || controller.targetScreen === screen.name)
        readonly property bool expanded: !suppressed && (pinned || hovered || hasEvent)
        onExpandedChanged: if (expanded) controller.displayBackend.refresh()
        readonly property string mode: hasEvent && (controller.eventType === "notification" || (!pinned && !hovered)) ? controller.eventType : "dashboard"
        readonly property bool notificationMode: expanded && mode === "notification" && controller.currentNotification !== null
        onHoveredChanged: controller.interactions = Math.max(0, controller.interactions + (hovered ? 1 : -1))
        Timer {
            interval: 3000
            running: islandWindowWindow.expanded
            repeat: true
            onTriggered: islandWindowWindow.controller.displayBackend.refresh()
        }
        visible: controller.available
        anchors.top: true
        margins.top: 0
        implicitWidth: Math.min(410, screen.width - 20)
        implicitHeight: Math.min(screen.height - 12, islandWindowPlayerView.implicitHeight + 65)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dynamic-island"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            Region {
                x: Math.round(islandWindowPill.x)
                y: Math.round(islandWindowPill.y)
                width: Math.round(islandWindowPill.width)
                height: Math.round(islandWindowPill.height)
                radius: islandWindowPill.radius
            }
            Region {
                x: Math.round(islandWindowRevealZone.x)
                y: Math.round(islandWindowRevealZone.y)
                width: islandWindowRevealZone.width
                height: islandWindowRevealZone.height
            }
        }

        function collapse() {
            pinned = false;
            suppressed = true;
            pointerOwned = false;
            hovered = false;
            islandWindowLeaveDelay.stop();
            islandWindowRevealDelay.stop();
            controller.clearEvent();
        }
        Connections {
            target: islandWindowWindow.controller
            function onEventSerialChanged() {
                islandWindowWindow.suppressed = false;
            }
            function onAvailableChanged() {
                if (!islandWindowWindow.controller.available) {
                    islandWindowWindow.pinned = false;
                    islandWindowWindow.hovered = false;
                    islandWindowWindow.pointerOwned = false;
                }
            }
        }
        Timer {
            id: islandWindowLeaveDelay
            interval: 90
            running: islandWindowWindow.expanded && islandWindowWindow.pointerOwned && !islandWindowWindow.pointerInside
            onTriggered: islandWindowWindow.collapse()
        }

        HoverHandler {
            id: islandWindowSurfaceHover
            parent: islandWindowWindow.contentItem
            blocking: false
            onHoveredChanged: if (hovered && islandWindowWindow.expanded) {
                islandWindowWindow.pointerOwned = true;
                islandWindowWindow.hovered = true;
            }
        }

        Rectangle {
            id: islandWindowRevealZone
            color: "#03000000"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(48, islandWindowWindow.width)
            height: islandWindowWindow.expanded ? 12 : 3
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 1
                height: 1
                radius: 0.5
                color: "#70d8df"
                opacity: islandWindowWindow.expanded ? 0 : islandWindowWindow.edgeInside ? 0.9 : 0.5
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
        }
        Timer {
            id: islandWindowRevealDelay
            interval: 160
            running: islandWindowWindow.visible && !islandWindowWindow.expanded && islandWindowWindow.edgeInside
            onTriggered: if (islandWindowWindow.edgeInside) {
                islandWindowWindow.pointerOwned = true;
                islandWindowWindow.suppressed = false;
                islandWindowWindow.hovered = true;
            }
        }

        Rectangle {
            id: islandWindowPill
            anchors.horizontalCenter: parent.horizontalCenter
            y: islandWindowWindow.expanded ? 10 : -height - 4
            opacity: islandWindowWindow.expanded ? 1 : 0
            enabled: islandWindowWindow.expanded
            width: islandWindowWindow.expanded ? islandWindowWindow.width - 4 : Math.min(islandWindowWindow.width - 4, islandWindowWindow.controller.playing ? 250 : 196)
            height: !islandWindowWindow.expanded ? 38 : islandWindowWindow.notificationMode ? 202 : islandWindowWindow.mode === "dashboard" || islandWindowWindow.mode === "music" ? Math.min(islandWindowWindow.height - 10, islandWindowPlayerView.implicitHeight + 54) : 106
            radius: islandWindowWindow.expanded ? 24 : 19
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#703c1935"
                }
                GradientStop {
                    position: 0.45
                    color: "#70201936"
                }
                GradientStop {
                    position: 1
                    color: "#881b1834"
                }
            }
            border.width: 1
            border.color: "#609d6c9f"
            clip: true
            Behavior on y {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on radius {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                x: 22
                y: 39
                width: parent.width - 44
                height: 1
                color: "#40302c36"
                visible: islandWindowWindow.expanded
            }

            Item {
                id: islandWindowHeader
                z: 3
                x: 16
                width: parent.width - 32
                height: 38
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (islandWindowWindow.expanded)
                            islandWindowWindow.collapse();
                        else {
                            islandWindowWindow.suppressed = false;
                            islandWindowWindow.pinned = true;
                        }
                    }
                    onWheel: function (wheel) {
                        const change = wheel.angleDelta.y ? wheel.angleDelta.y / 120 * 0.02 : wheel.pixelDelta.y * 0.001;
                        islandWindowWindow.controller.setVolume(Math.max(0, Math.min(1, islandWindowWindow.controller.volume + change)));
                        wheel.accepted = true;
                    }
                }
                Row {
                    id: islandWindowWave
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: 4
                        Rectangle {
                            id: islandWindowBar
                            required property int index
                            width: 3
                            height: 5
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            color: islandWindowWindow.controller.recording ? "#ff5a64" : islandWindowWindow.controller.playing ? "#70d8df" : "#80658f"
                            SequentialAnimation on height {
                                running: islandWindowWindow.visible && islandWindowWindow.expanded && islandWindowWindow.controller.playing
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 7 + islandWindowBar.index * 3
                                    duration: 280 + islandWindowBar.index * 60
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 4
                                    duration: 240 + islandWindowBar.index * 90
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }
            Item {
                id: islandAdjustments
                property bool expanded: false
                readonly property point pointerPosition: islandWindowSurfaceHover ? mapFromItem(islandWindowSurfaceHover.parent, islandWindowSurfaceHover.point.position.x, islandWindowSurfaceHover.point.position.y) : Qt.point(-1, -1)
                readonly property bool pointerInside: islandWindowWindow.expanded && islandWindowSurfaceHover && islandWindowSurfaceHover.hovered && pointerPosition.x >= 0 && pointerPosition.x <= width && pointerPosition.y >= 0 && pointerPosition.y <= height
                x: 26
                y: 5
                z: 2
                width: expanded ? parent.width - 52 : parent.width - 180
                height: expanded ? 76 : 28
                clip: true
                onVisibleChanged: if (!visible) expanded = false
                Connections {
                    target: islandWindowWindow
                    function onExpandedChanged() {
                        if (!islandWindowWindow.expanded)
                            islandAdjustments.expanded = false;
                    }
                }
                Timer {
                    interval: 160
                    running: islandAdjustments.pointerInside && !islandAdjustments.expanded
                    onTriggered: islandAdjustments.expanded = true
                }
                Timer {
                    interval: 350
                    running: islandAdjustments.expanded && !islandAdjustments.pointerInside
                    onTriggered: islandAdjustments.expanded = false
                }
                Rectangle {
                    y: 28
                    width: parent.width
                    height: parent.height - 28
                    visible: islandAdjustments.expanded
                    radius: 12
                    color: "#b32a1835"
                    border.width: islandAdjustments.expanded ? 1 : 0
                    border.color: "#608b4d72"
                }
                Item {
                    width: islandWindowHeader.width - 180
                    height: 28
                    Text {
                        x: 4
                        width: parent.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindowWindow.controller.recording ? "Screen recording" : islandWindowWindow.controller.player ? islandWindowWindow.controller.player.identity || "Audio" : "Dynamic Island"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: "#f3eaff"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: islandAdjustmentsHeader
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: islandAdjustments.expanded = !islandAdjustments.expanded
                    }
                }
                Row {
                    x: 4
                    y: 28
                    visible: islandAdjustments.expanded
                    width: parent.width - 8
                    spacing: 6
                    IslandControl {
                        id: islandBrightnessControl
                        width: (parent.width - parent.spacing * 3) / 4
                        label: "Brightness"
                        glyph: "\uf185"
                        accent: "#ff9777"
                        minimum: 10
                        value: islandWindowWindow.controller.displayBackend.state.brightness
                        enabled: islandWindowWindow.controller.displayBackend.state.brightnessAvailable
                        onMoved: {
                            islandWindowWindow.controller.setBrightness(islandBrightnessControl.value);
                        }
                    }
                    IslandControl {
                        id: islandGammaControl
                        width: (parent.width - parent.spacing * 3) / 4
                        label: "Gamma"
                        glyph: "\uf042"
                        accent: "#74dce2"
                        minimum: 30
                        value: islandWindowWindow.controller.displayBackend.state.gamma
                        enabled: islandWindowWindow.controller.displayBackend.state.sunsetAvailable
                        onMoved: {
                            islandWindowWindow.controller.displayBackend.setValue("gamma", Math.round(islandGammaControl.value));
                        }
                    }
                    IslandControl {
                        id: islandVolumeControl
                        width: (parent.width - parent.spacing * 3) / 4
                        label: "Volume"
                        glyph: "\uf028"
                        accent: "#dba1ec"
                        minimum: 0
                        value: Math.min(100, islandWindowWindow.controller.volume * 100)
                        enabled: islandWindowWindow.controller.volumeAvailable
                        onMoved: {
                            islandWindowWindow.controller.setVolume(islandVolumeControl.value / 100);
                        }
                    }
                    IslandControl {
                        id: islandTemperatureControl
                        width: (parent.width - parent.spacing * 3) / 4
                        label: "Night light temperature"
                        glyph: "\uf186"
                        accent: "#ffd08a"
                        minimum: 1000
                        maximum: 2700
                        wheelStep: 100
                        unit: "K"
                        value: islandWindowWindow.controller.displayBackend.state.temperature
                        enabled: islandWindowWindow.controller.displayBackend.state.sunsetAvailable
                        onMoved: {
                            islandWindowWindow.controller.displayBackend.setValue("temperature", Math.round(islandTemperatureControl.value));
                        }
                    }
                }
            }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 32
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    IslandButton {
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: islandWindowWindow.controller.doNotDisturb ? "\uf1f6" : "\uf0f3"
                        label: islandWindowWindow.controller.doNotDisturb ? "Disable do not disturb" : "Enable do not disturb"
                        color: islandWindowWindow.controller.doNotDisturb ? "#604e284c" : "transparent"
                        onClicked: {
                            islandWindowWindow.controller.doNotDisturb = !islandWindowWindow.controller.doNotDisturb;
                            islandWindowWindow.controller.clearEvent();
                        }
                    }
                    IslandButton {
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "\uf0e5"
                        label: islandWindowWindow.controller.notifications.length + " notifications"
                        enabled: islandWindowWindow.controller.notifications.length > 0
                        onClicked: {
                            islandWindowWindow.pinned = false;
                            islandWindowWindow.hovered = false;
                            islandWindowWindow.controller.nextNotification();
                        }
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: 4
                            height: 4
                            radius: 2
                            color: "#70d8df"
                            visible: islandWindowWindow.controller.notifications.length > 0
                        }
                    }
                    Rectangle {
                        visible: islandWindowWindow.controller.microphoneActive || islandWindowWindow.controller.recording
                        width: 6
                        height: 6
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: islandWindowWindow.controller.recording ? "#ff5a64" : "#ff9c66"
                    }
                    Text {
                        text: islandWindowWindow.controller.hasBattery ? (islandWindowWindow.controller.charging ? "ϟ " : "") + islandWindowWindow.controller.batteryPercent + "%" : "◦"
                        color: islandWindowWindow.controller.charging ? "#70d8df" : islandWindowWindow.controller.batteryPercent >= 0 && islandWindowWindow.controller.batteryPercent <= 20 ? "#ff9c66" : "#c7aacb"
                        font.pixelSize: 11
                    }
                }
                IslandButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    glyph: "×"
                    label: "Close island"
                    onClicked: islandWindowWindow.collapse()
                }
            }

            Column {
                id: islandWindowContent
                x: 22
                y: 42
                width: islandWindowPill.width - 44
                spacing: 9
                opacity: islandWindowWindow.expanded ? 1 : 0
                visible: islandWindowPill.height > 55
                enabled: islandWindowWindow.expanded
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }

                Column {
                    width: parent.width
                    visible: islandWindowWindow.notificationMode
                    spacing: 8
                    Text {
                        width: parent.width
                        text: islandWindowWindow.controller.currentNotification ? islandWindowWindow.controller.currentNotification.appName : "Notification"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.pixelSize: 10
                        color: "#c7aacb"
                    }
                    Text {
                        width: parent.width
                        text: islandWindowWindow.controller.currentNotification ? islandWindowWindow.controller.currentNotification.summary : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "#f3eaff"
                    }
                    Text {
                        width: parent.width
                        height: 32
                        text: islandWindowWindow.controller.currentNotification ? islandWindowWindow.controller.currentNotification.body : ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        color: "#c7aacb"
                    }
                    Row {
                        spacing: 7
                        Repeater {
                            model: islandWindowWindow.controller.currentNotification ? islandWindowWindow.controller.currentNotification.actions.slice(0, 3) : []
                            IslandButton {
                                required property var modelData
                                width: 48
                                glyph: modelData.identifier === "default" ? "↗" : "✓"
                                label: modelData.text
                                onClicked: {
                                    modelData.invoke();
                                    islandWindowWindow.controller.clearEvent();
                                }
                            }
                        }
                        IslandButton {
                            glyph: "×"
                            label: "Dismiss notification"
                            onClicked: islandWindowWindow.controller.dismissNotification()
                        }
                        IslandButton {
                            glyph: "→"
                            label: "Next notification"
                            enabled: islandWindowWindow.controller.notifications.length > 1
                            onClicked: islandWindowWindow.controller.nextNotification()
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: !islandWindowWindow.notificationMode && islandWindowWindow.mode !== "dashboard" && islandWindowWindow.mode !== "music"
                    spacing: 12
                    Row {
                        width: parent.width
                        spacing: 12
                        Text {
                            text: islandWindowWindow.mode === "volume" ? "\uf028" : islandWindowWindow.mode === "brightness" ? "\uf185" : islandWindowWindow.mode === "battery" ? "\uf240" : "\uf111"
                            font.family: "Symbols Nerd Font Mono"
                            color: islandWindowWindow.mode === "activity" ? "#ff9c66" : "#70d8df"
                            font.pixelSize: 21
                        }
                        Text {
                            width: parent.width - 42
                            text: islandWindowWindow.controller.eventTitle + (islandWindowWindow.controller.eventValue >= 0 ? "   " + Math.round(islandWindowWindow.controller.eventValue * 100) + "%" : "")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: "#f3eaff"
                            font.pixelSize: 14
                        }
                    }
                    Text {
                        width: parent.width
                        visible: islandWindowWindow.controller.eventValue < 0
                        text: islandWindowWindow.controller.eventDetail
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: "#c7aacb"
                        font.pixelSize: 11
                    }
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: "#493451"
                        visible: islandWindowWindow.controller.eventValue >= 0
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, islandWindowWindow.controller.eventValue))
                            height: parent.height
                            radius: 2
                            color: "#f3eaff"
                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                    }
                }

                IslandPlayer {
                    id: islandWindowPlayerView
                    width: parent.width
                    controller: islandWindowWindow.controller
                    pointerTracker: islandWindowSurfaceHover
                    active: islandWindowWindow.expanded && visible
                    onPlayerRequested: {
                        const window = islandWindowWindow.controller.playerWindow;
                        if (window) {
                            window.activate();
                            islandWindowWindow.collapse();
                        }
                    }
                    visible: !islandWindowWindow.notificationMode && (islandWindowWindow.mode === "dashboard" || islandWindowWindow.mode === "music")
                    onNotificationsRequested: {
                        islandWindowWindow.pinned = false;
                        islandWindowWindow.hovered = false;
                        islandWindowWindow.controller.nextNotification();
                    }
                }
            }
        }
    }
}
