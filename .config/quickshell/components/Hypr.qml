import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    required property var audioBackend
    property bool volumeVisible: false
    readonly property bool volumeAvailable: !!audioBackend.volumeSink && !!audioBackend.volumeSink.audio
    readonly property real volume: audioBackend.outputVolume
    readonly property bool muted: audioBackend.outputMuted

    function dismissPopups() {
        volumeVisible = false;
        workspaceNotice.opened = false;
        helpNotice.opened = false;
        systemNotice.opened = false;
    }

    function showVolume() {
        dismissPopups();
        const monitor = Hyprland.focusedMonitor;
        const screen = Quickshell.screens.find(candidate => monitor && candidate.name === monitor.name);
        if (screen)
            volumePopup.screen = screen;
        volumeVisible = true;
        volumeTimeout.restart();
    }

    function adjustVolume(action) {
        if (!volumeAvailable || !["mute", "down", "up"].includes(action))
            return false;
        if (action === "mute")
            audioBackend.toggleOutputMute();
        else {
            const percent = Math.round(volume * 100);
            audioBackend.setOutputVolume(Math.max(30, Math.min(95, percent + (action === "up" ? 5 : -5))) / 100);
        }
        showVolume();
        return true;
    }

    IpcHandler {
        target: "hypr"
        function volume(action: string): bool {
            return root.adjustVolume(action);
        }
        function notify(icon: string, duration: int, color: string, message: string): void {
            systemNotice.show(icon, duration, color, message);
        }
        function dismiss(): void {
            root.dismissPopups();
        }
        function status(): string {
            return JSON.stringify({
                visible: root.volumeVisible,
                noticeVisible: systemNotice.opened,
                noticeKind: systemNotice.heading,
                available: root.volumeAvailable,
                volume: Math.round(root.volume * 100),
                muted: root.muted
            });
        }
    }

    Timer {
        id: volumeTimeout
        interval: 1500
        onTriggered: root.volumeVisible = false
    }

    PanelWindow {
        id: volumePopup
        visible: root.volumeVisible
        anchors {
            top: true
            right: true
        }
        margins {
            top: 16
            right: 16
        }
        implicitWidth: Math.min(312, screen.width - 32)
        implicitHeight: 108
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "hypr-notify"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            radius: 20
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#2c2435"
                }
                GradientStop {
                    position: 1
                    color: "#1b1822"
                }
            }
            border.width: 1
            border.color: root.muted ? "#807b4b53" : "#70695782"
            opacity: root.volumeVisible ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 130
                }
            }

            Rectangle {
                x: 18
                y: 18
                width: 48
                height: 48
                radius: 15
                color: root.muted ? "#30ff9c80" : "#25c6abff"
                border.width: 1
                border.color: root.muted ? "#35ff9c80" : "#35c6abff"
                Text {
                    anchors.centerIn: parent
                    text: root.muted ? "󰖁" : root.volume < 0.4 ? "󰖀" : "󰕾"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 26
                    color: root.muted ? "#ffac94" : "#d4bfff"
                }
            }

            Text {
                x: 80
                y: 22
                text: root.muted ? "Sound muted" : "Volume"
                font.family: "sans-serif"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: "#f4eefa"
            }
            Text {
                x: 80
                y: 44
                text: "SYSTEM AUDIO"
                font.family: "sans-serif"
                font.pixelSize: 8
                font.letterSpacing: 1.5
                color: "#a699b4"
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 18
                y: 22
                spacing: 2
                Text {
                    text: Math.round(root.volume * 100)
                    font.family: "sans-serif"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    color: root.muted ? "#ffac94" : "#f4eefa"
                }
                Text {
                    y: 12
                    text: "%"
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    color: "#a699b4"
                }
            }
            Row {
                x: 18
                y: 84
                width: parent.width - 36
                spacing: 4
                Repeater {
                    model: 24
                    Rectangle {
                        required property int index
                        width: (parent.width - 23 * 4) / 24
                        height: 5
                        radius: 2.5
                        color: index < Math.round(Math.max(0, Math.min(1, root.volume)) * 24) ? root.muted ? "#dd927e" : "#c6abff" : "#44374f"
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                }
            }
        }
    }

    WorkspacePopup {
        id: workspaceNotice
        controller: root
    }
    HelpPopup {
        id: helpNotice
        controller: root
    }

    component WorkspacePopup: PanelWindow {
        id: popup
        required property var controller
        property string heading: ""
        property string details: ""
        property string appIcon: ""
        property string workspaceNumber: ""
        property bool opened: false
        visible: opened
        anchors {
            top: true
            right: true
        }
        margins {
            top: 12
            right: 12
        }
        implicitWidth: Math.min(300, screen.width - 24)
        implicitHeight: 92
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "workspace-notify"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        IpcHandler {
            target: "workspaceNotify"
            function show(message: string, appClass: string, heading: string): void {
                popup.controller.dismissPopups();
                const lines = message.split("\n");
                const label = heading || lines[0] || "Workspace";
                const markers = ["➊", "➋", "➌", "➍", "➎", "➏", "➐", "➑", "➒", "➓"];
                const workspaceIndex = markers.indexOf(label.charAt(0));
                popup.workspaceNumber = "";
                if (workspaceIndex >= 0) {
                    popup.workspaceNumber = String(workspaceIndex + 1);
                    popup.heading = label.slice(1).trim() || "Workspace";
                } else {
                    popup.heading = label;
                }
                lines.shift();
                popup.details = lines.join(" · ");
                const entry = appClass ? DesktopEntries.heuristicLookup(appClass.replace(/-float$/, "")) : null;
                popup.appIcon = entry ? Quickshell.iconPath(entry.icon) : "";
                const monitor = Hyprland.focusedMonitor;
                if (monitor) {
                    const screens = Quickshell.screens;
                    for (let i = 0; i < screens.length; i++) {
                        if (screens[i].name === monitor.name) {
                            popup.screen = screens[i];
                            break;
                        }
                    }
                }
                popup.opened = true;
                hideTimer.restart();
            }
        }

        Timer {
            id: hideTimer
            interval: 1200
            onTriggered: popup.opened = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#2c2435"
                }
                GradientStop {
                    position: 1
                    color: "#1b1822"
                }
            }
            border.width: 1
            border.color: "#70695782"

            Rectangle {
                x: 16
                y: 22
                width: 46
                height: 46
                radius: 14
                color: "#25c6abff"
                Image {
                    id: applicationIcon
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    source: popup.appIcon
                    visible: status === Image.Ready
                    sourceSize.width: 52
                    sourceSize.height: 52
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.centerIn: parent
                    visible: applicationIcon.status !== Image.Ready
                    text: "󰖲"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 23
                    color: "#d4bfff"
                }
            }
            Text {
                x: 76
                y: 16
                text: "WORKSPACE"
                font.family: "sans-serif"
                font.pixelSize: 8
                font.letterSpacing: 1.4
                color: "#a699b4"
            }
            Text {
                x: 76
                y: 32
                width: parent.width - x - 42
                text: popup.heading
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "sans-serif"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: "#f4eefa"
            }
            Text {
                x: 76
                y: 55
                width: parent.width - x - 16
                text: popup.details
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "sans-serif"
                font.pixelSize: 10
                color: "#b6a8c3"
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 14
                width: 24
                height: 24
                radius: 8
                visible: popup.workspaceNumber !== ""
                color: "#25c6abff"
                Text {
                    anchors.centerIn: parent
                    text: popup.workspaceNumber
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#d4bfff"
                }
            }
        }
    }

    component HelpPopup: PanelWindow {
        id: popup
        required property var controller
        property string heading: ""
        property string details: ""
        property bool opened: false
        readonly property var rows: details.split("\n").filter(line => line.trim().length > 0)
        readonly property int columns: width >= 560 ? 2 : 1
        visible: opened
        anchors {
            top: true
            right: true
        }
        margins {
            top: 12
            right: 12
        }
        implicitWidth: Math.min(650, screen.width - 24)
        implicitHeight: Math.min(content.implicitHeight + 36, screen.height - 24)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "help-notify"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        IpcHandler {
            target: "helpNotify"
            function show(title: string, message: string): void {
                popup.controller.dismissPopups();
                popup.heading = title || "Help";
                popup.details = message;
                const monitor = Hyprland.focusedMonitor;
                const target = Quickshell.screens.find(screen => monitor && screen.name === monitor.name);
                if (target)
                    popup.screen = target;
                popup.opened = true;
                hideTimer.restart();
            }
            function status(): string {
                return JSON.stringify({
                    visible: popup.opened,
                    lines: popup.details ? popup.details.split("\n").length : 0,
                    screen: popup.screen ? popup.screen.name : ""
                });
            }
        }

        Timer {
            id: hideTimer
            interval: 2000
            onTriggered: popup.opened = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            clip: true
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#2c2435"
                }
                GradientStop {
                    position: 1
                    color: "#1b1822"
                }
            }
            border.width: 1
            border.color: "#70695782"

            Column {
                id: content
                x: 18
                y: 18
                width: parent.width - 36
                spacing: 18

                Item {
                    width: parent.width
                    height: 44
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 14
                        color: "#25c6abff"
                        Text {
                            anchors.centerIn: parent
                            text: "󰌌"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 24
                            color: "#d4bfff"
                        }
                    }
                    Text {
                        x: 58
                        y: 2
                        width: parent.width - x - 75
                        text: popup.heading
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: "sans-serif"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: "#f4eefa"
                    }
                    Text {
                        x: 58
                        y: 26
                        text: "Navigation & image controls"
                        font.family: "sans-serif"
                        font.pixelSize: 10
                        color: "#a699b4"
                    }
                    Text {
                        anchors.right: parent.right
                        y: 8
                        text: popup.rows.length + " KEYS"
                        font.family: "sans-serif"
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        color: "#c6abff"
                    }
                }

                Grid {
                    id: shortcuts
                    width: parent.width
                    columns: popup.columns
                    columnSpacing: 14
                    rowSpacing: 5
                    Repeater {
                        model: popup.rows
                        Item {
                            id: shortcut
                            required property string modelData
                            readonly property int separator: modelData.indexOf(":")
                            readonly property string key: separator >= 0 ? modelData.slice(0, separator) : ""
                            readonly property string description: separator >= 0 ? modelData.slice(separator + 1).trim() : modelData
                            width: (shortcuts.width - (popup.columns - 1) * shortcuts.columnSpacing) / popup.columns
                            height: 28

                            Rectangle {
                                anchors.fill: parent
                                radius: 7
                                color: "#08ffffff"
                            }
                            Rectangle {
                                id: keycap
                                x: 2
                                y: 2
                                width: Math.min(126, keyLabel.implicitWidth + 14)
                                height: parent.height - 4
                                radius: 6
                                color: "#302334"
                                border.width: 1
                                border.color: "#665a456b"
                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: shortcut.key.replace("Right", "→").replace("Left", "←").replace("Next", "PgDn").replace("Prior", "PgUp").replace("BackSpace", "⌫")
                                    textFormat: Text.PlainText
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    color: "#dfcff2"
                                }
                            }
                            Text {
                                x: keycap.x + keycap.width + 9
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - 8
                                text: shortcut.description
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font.family: "sans-serif"
                                font.pixelSize: 11
                                color: "#c5b8d0"
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: systemNotice
        readonly property var controller: root
        property bool opened: false
        property string heading: "System"
        property string details: ""
        property string glyph: "󰋽"
        property color accent: "#c6abff"
        property real level: -1
        property var quickSettings: []
        visible: opened
        anchors {
            top: true
            right: true
        }
        margins {
            top: 16
            right: 16
        }
        implicitWidth: Math.min(quickSettings.length ? 250 : 360, screen.width - 32)
        implicitHeight: quickSettings.length ? 22 + quickSettings.length * 30 : level >= 0 ? 120 : Math.max(98, Math.min(180, body.implicitHeight + 62))
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "hypr-system-notify"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        function show(icon, duration, color, message) {
            controller.dismissPopups();
            const raw = message.replace(/^fontsize:\d+\s*/, "").trim();
            quickSettings = [];
            const first = raw ? String.fromCodePoint(raw.codePointAt(0)) : "";
            const hasSymbol = first && first.codePointAt(0) >= 0x2300;
            glyph = hasSymbol ? first : icon === "3" ? "󰅚" : icon === "5" ? "󰄬" : "󰋽";
            details = hasSymbol ? raw.slice(first.length).trim() : raw;
            heading = "System";
            if (["󰃞", "󰃟", "󰃠"].includes(glyph))
                heading = "Brightness";
            else if (["󰃛", "󰃜"].includes(glyph))
                heading = "Night light";
            else if (["󰕾", "󰖀", "󰖁", "", ""].includes(glyph))
                heading = glyph === "󰖁" ? "Muted" : "Volume";
            else if (["󰎇", "󰎊"].includes(glyph))
                heading = "Music";
            else if (glyph === "🎬")
                heading = "Video";
            else if (raw.toLowerCase().includes("recording")) {
                heading = "Recording";
                glyph = "󰑋";
            } else if (raw.toLowerCase().includes("timer")) {
                heading = "Timer";
                glyph = "󰔟";
            } else if (raw.toLowerCase().includes("wallpaper")) {
                heading = "Wallpaper";
                glyph = "󰋩";
            }
            if (raw.includes("󰕾") && raw.includes("󰃟")) {
                heading = "Quick settings";
                const fields = [
                    { glyph: "󰕾", label: "Volume", accent: "#ff8e86", pattern: /󰕾\s*([\d.]+%)/ },
                    { glyph: "󰃟", label: "Brightness", accent: "#f1c27c", pattern: /󰃟\s*([\d.]+%)/ },
                    { glyph: "󰍛", label: "Memory", accent: "#7ddbd7", pattern: /󰘚\s*([\d.]+\s*GB)/ }
                ];
                const rows = [];
                for (const field of fields) {
                    const result = raw.match(field.pattern);
                    if (result)
                        rows.push({ glyph: field.glyph, label: field.label, value: result[1], accent: field.accent });
                }
                quickSettings = rows;
            }
            if (!details)
                details = heading === "Muted" ? "Output muted" : heading === "Volume" ? "Output unmuted" : "Done";
            const percent = details.match(/^(\d+(?:\.\d+)?)%$/);
            level = percent ? Math.max(0, Math.min(1, Number(percent[1]) / 100)) : -1;
            const match = color.match(/^rgb\(([0-9a-fA-F]{6})\)$/);
            accent = match ? "#" + match[1] : "#c6abff";
            const monitor = Hyprland.focusedMonitor;
            const target = Quickshell.screens.find(screen => monitor && screen.name === monitor.name);
            if (target)
                screen = target;
            opened = true;
            lifetime.interval = Math.max(250, Math.min(60000, duration || 2000));
            lifetime.restart();
        }

        Timer {
            id: lifetime
            onTriggered: systemNotice.opened = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#2c2435"
                }
                GradientStop {
                    position: 1
                    color: "#1b1822"
                }
            }
            border.width: 1
            border.color: "#70695782"

            Rectangle {
                x: 18
                y: 22
                visible: !systemNotice.quickSettings.length
                width: 46
                height: 46
                radius: 14
                color: Qt.rgba(systemNotice.accent.r, systemNotice.accent.g, systemNotice.accent.b, 0.16)
                Text {
                    anchors.centerIn: parent
                    text: systemNotice.glyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 25
                    color: systemNotice.accent
                }
            }
            Text {
                x: systemNotice.quickSettings.length ? 20 : 80
                visible: !systemNotice.quickSettings.length
                y: 18
                width: parent.width - x - 18
                text: systemNotice.heading.toUpperCase()
                font.family: "sans-serif"
                font.pixelSize: 9
                font.letterSpacing: 1.4
                color: systemNotice.accent
            }
            Text {
                id: body
                visible: !systemNotice.quickSettings.length
                x: 80
                y: 38
                width: parent.width - x - 18
                text: systemNotice.details
                textFormat: Text.PlainText
                font.family: "sans-serif"
                font.pixelSize: systemNotice.level >= 0 ? 26 : 12
                font.weight: systemNotice.level >= 0 ? Font.DemiBold : Font.Normal
                maximumLineCount: 3
                elide: Text.ElideRight
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: "#f4eefa"
            }
            Column {
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 6
                visible: systemNotice.quickSettings.length > 0
                Repeater {
                    model: systemNotice.quickSettings
                    delegate: Item {
                        id: settingRow
                        required property var modelData
                        readonly property color tone: modelData.accent
                        width: parent.width
                        height: 24
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: 8
                            color: Qt.rgba(settingRow.tone.r, settingRow.tone.g, settingRow.tone.b, 0.12)
                            Text {
                                anchors.centerIn: parent
                                text: settingRow.modelData.glyph
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: settingRow.tone
                            }
                        }
                        Text {
                            x: 34
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.label
                            font.pixelSize: 11
                            color: "#d4c7df"
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.value
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: settingRow.tone
                        }
                    }
                }
            }
            Rectangle {
                x: 80
                y: 94
                width: parent.width - x - 18
                height: 5
                radius: 2.5
                visible: systemNotice.level >= 0
                color: "#44374f"
                Rectangle {
                    width: parent.width * Math.max(0, systemNotice.level)
                    height: parent.height
                    radius: parent.radius
                    color: systemNotice.accent
                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
            }
        }
    }
}
