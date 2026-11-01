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

    function dismissPopups(keep) {
        volumeVisible = false;
        if (keep !== "workspace")
            workspaceNotice.opened = false;
        helpNotice.opened = false;
        if (keep !== "system")
            systemNotice.opened = false;
    }

    function showVolume() {
        workspaceNotice.opened = false;
        helpNotice.opened = false;
        systemNotice.opened = false;
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
        interval: 1000
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
        implicitWidth: Math.min(Math.ceil(volumeContent.implicitWidth) + 24, screen.width - 32)
        implicitHeight: 34
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "hypr-notify"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        HyprNoticeSurface {
            anchors.fill: parent
            hud: true
            accentColor: root.muted ? "#f38ba8" : "#cba6f7"
            HyprLevelIndicator {
                id: volumeContent
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                value: root.volume
                muted: root.muted
                symbol: root.muted ? "󰖁" : root.volume < 0.4 ? "󰖀" : "󰕾"
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
        readonly property int textOffset: appIcon ? 78 : 54
        visible: opened
        anchors {
            top: true
            right: true
        }
        margins {
            top: 16
            right: 16
        }
        implicitWidth: Math.min(Math.max(120, Math.ceil(Math.max(headingMeasurement.implicitWidth, detailMeasurement.implicitWidth)) + textOffset + 18), screen.width - 32)
        implicitHeight: Math.max(38, workspaceText.implicitHeight + 18)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "workspace-notify"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        IpcHandler {
            target: "workspaceNotify"
            function show(message: string, appClass: string, heading: string): void {
                if (!appClass.trim()) {
                    popup.opened = false;
                    hideTimer.stop();
                    return;
                }
                popup.controller.dismissPopups("workspace");
                const lines = message.split("\n");
                const label = heading || lines[0] || "Workspace";
                const markers = ["➊", "➋", "➌", "➍", "➎", "➏", "➐", "➑", "➒", "➓"];
                const workspaceIndex = markers.indexOf(label.charAt(0));
                popup.workspaceNumber = "";
                if (workspaceIndex >= 0) {
                    popup.workspaceNumber = String(workspaceIndex + 1);
                    popup.heading = label.slice(1).trim() || "Empty";
                } else {
                    popup.heading = label;
                }
                lines.shift();
                popup.details = lines.filter(line => line.trim() && !/^\d{2}:\d{2}:\d{2}$/.test(line.trim())).join(" · ");
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
            interval: 1000
            onTriggered: popup.opened = false
        }

        Text {
            id: headingMeasurement
            visible: false
            text: popup.heading
            textFormat: Text.PlainText
            font: workspaceHeading.font
        }
        Text {
            id: detailMeasurement
            visible: false
            text: popup.details
            textFormat: Text.PlainText
            font: workspaceDetail.font
        }

        HyprNoticeSurface {
            anchors.fill: parent
            hud: true
            accentColor: "#cba6f7"
            Rectangle {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                color: "#14cba6f7"
                border.width: 1
                border.color: "#40cba6f7"
                Rectangle { width: 7; height: 1; color: "#cba6f7" }
                Rectangle { width: 1; height: 7; color: "#cba6f7" }
                Text {
                    anchors.centerIn: parent
                    text: popup.workspaceNumber ? popup.workspaceNumber.padStart(2, "0") : "󰖲"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#cba6f7"
                }
            }
            Rectangle {
                x: 43
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                rotation: 12
                color: "#585b70"
            }
            Image {
                x: 54
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: popup.appIcon
                visible: status === Image.Ready
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
            }
            Column {
                id: workspaceText
                x: popup.textOffset
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 18
                spacing: 3
                Text {
                    id: workspaceHeading
                    width: parent.width
                    text: popup.heading
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    color: "#cdd6f4"
                }
                Text {
                    id: workspaceDetail
                    visible: text.length > 0
                    width: parent.width
                    text: popup.details
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                    color: "#bac2de"
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

        HyprNoticeSurface {
            anchors.fill: parent
            clip: true

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
                        radius: 4
                        color: "#24b4befe"
                        Text {
                            anchors.centerIn: parent
                            text: "󰌌"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 24
                            color: "#b4befe"
                        }
                    }
                    Text {
                        x: 58
                        y: 2
                        width: parent.width - x - 75
                        text: popup.heading
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: "JetBrains Mono"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: "#cdd6f4"
                    }
                    Text {
                        x: 58
                        y: 26
                        text: "Navigation & image controls"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        color: "#a6adc8"
                    }
                    Text {
                        anchors.right: parent.right
                        y: 8
                        text: popup.rows.length + " KEYS"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        color: "#b4befe"
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
                                radius: 3
                                color: "#08cdd6f4"
                            }
                            Rectangle {
                                id: keycap
                                x: 2
                                y: 2
                                width: Math.min(126, keyLabel.implicitWidth + 14)
                                height: parent.height - 4
                                radius: 3
                                color: "#313244"
                                border.width: 1
                                border.color: "#80585b70"
                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: shortcut.key.replace("Right", "→").replace("Left", "←").replace("Next", "PgDn").replace("Prior", "PgUp").replace("BackSpace", "⌫")
                                    textFormat: Text.PlainText
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    color: "#cdd6f4"
                                }
                            }
                            Text {
                                x: keycap.x + keycap.width + 9
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - 8
                                text: shortcut.description
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                color: "#bac2de"
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
        property color accent: "#b4befe"
        property real level: -1
        property var quickSettings: []
        readonly property bool compactLevel: !quickSettings.length && level >= 0
        readonly property bool compactText: !quickSettings.length && level < 0
        visible: opened
        anchors {
            top: true
            right: true
        }
        margins {
            top: 16
            right: 16
        }
        implicitWidth: compactLevel ? Math.min(Math.ceil(systemLevelContent.implicitWidth) + 24, screen.width - 32) : compactText ? Math.min(Math.max(54, Math.ceil(noticeMeasurement.implicitWidth) + 38), screen.width - 32) : Math.min(quickSettings.length ? 250 : 360, screen.width - 32)
        implicitHeight: compactLevel ? 34 : compactText ? Math.max(38, Math.ceil(body.implicitHeight) + 22) : quickSettings.length ? 22 + quickSettings.length * 30 : level >= 0 ? 120 : Math.max(98, Math.min(180, body.implicitHeight + 62))
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "hypr-system-notify"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        function show(icon, duration, color, message) {
            controller.dismissPopups("system");
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
                    { glyph: "󰕾", label: "Volume", accent: "#b4befe", pattern: /󰕾\s*([\d.]+%)/ },
                    { glyph: "󰃟", label: "Brightness", accent: "#f9e2af", pattern: /󰃟\s*([\d.]+%)/ },
                    { glyph: "󰍛", label: "Memory", accent: "#a6e3a1", pattern: /󰘚\s*([\d.]+\s*GB)/ }
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
            const temperature = details.match(/^(\d+)K$/);
            level = percent ? Math.max(0, Math.min(1, Number(percent[1]) / 100)) : temperature ? Math.max(0, Math.min(1, (Number(temperature[1]) - 1200) / 1500)) : -1;
            const match = color.match(/^rgb\(([0-9a-fA-F]{6})\)$/);
            accent = match ? "#" + match[1] : "#b4befe";
            const monitor = Hyprland.focusedMonitor;
            const target = Quickshell.screens.find(screen => monitor && screen.name === monitor.name);
            if (target)
                screen = target;
            opened = true;
            lifetime.interval = compactLevel ? 1000 : Math.max(250, Math.min(60000, duration || 2000));
            lifetime.restart();
        }

        Timer {
            id: lifetime
            onTriggered: systemNotice.opened = false
        }

        Text {
            id: noticeMeasurement
            visible: false
            text: systemNotice.details
            textFormat: Text.PlainText
            font: body.font
            renderType: body.renderType
        }

        HyprNoticeSurface {
            anchors.fill: parent
            hud: systemNotice.compactLevel
            accentColor: systemLevelContent.accentColor
            HyprLevelIndicator {
                id: systemLevelContent
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: systemNotice.compactLevel
                value: systemNotice.level
                symbol: systemNotice.glyph
                label: systemNotice.details
                accentColor: "#cba6f7"
                progressEndColor: "#b4befe"
            }

            Rectangle {
                x: 18
                y: 22
                visible: !systemNotice.quickSettings.length && !systemNotice.compactText && !systemNotice.compactLevel
                width: 46
                height: 46
                radius: 4
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
                visible: !systemNotice.quickSettings.length && !systemNotice.compactText && !systemNotice.compactLevel
                y: 18
                width: parent.width - x - 18
                text: systemNotice.heading.toUpperCase()
                font.family: "JetBrains Mono"
                font.pixelSize: 9
                font.letterSpacing: 1.4
                color: systemNotice.accent
            }
            Text {
                id: body
                visible: !systemNotice.quickSettings.length && !systemNotice.compactLevel
                x: systemNotice.compactText ? 18 : 80
                y: systemNotice.compactText ? (parent.height - implicitHeight) / 2 : 38
                width: parent.width - x - 18
                text: systemNotice.details
                textFormat: Text.PlainText
                font.family: "JetBrains Mono"
                font.pixelSize: systemNotice.level >= 0 ? 26 : 12
                font.weight: systemNotice.level >= 0 ? Font.DemiBold : Font.Normal
                maximumLineCount: systemNotice.compactText ? 2147483647 : 3
                elide: systemNotice.compactText ? Text.ElideNone : Text.ElideRight
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: "#cdd6f4"
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
                            radius: 3
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
                            color: "#bac2de"
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

        }
    }
}
