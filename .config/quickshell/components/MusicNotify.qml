import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris

PanelWindow {
    id: popup
    property bool opened: false
    property bool suppressNotifications: false
    onSuppressNotificationsChanged: if (suppressNotifications) opened = false
    property string trackTitle: ""
    property string artist: ""
    property string mode: "playing"
    property string cover: ""
    readonly property color coverAccent: {
        if (mode === "scrobbled") return "#8dce9b"
        if (!cover || !coverPalette.colors.length) return "#b89ad3"
        var colors = coverPalette.colors
        var selected = colors[0]
        var score = -1
        for (var index = 0; index < colors.length; index++) {
            var color = colors[index]
            var value = color.hslSaturation * 0.7 + (1 - Math.abs(color.hslLightness - 0.5) * 2) * 0.3
            if (value > score) { selected = color; score = value }
        }
        return selected
    }
    readonly property color surfaceStart: Qt.tint("#19171e", Qt.rgba(coverAccent.r, coverAccent.g, coverAccent.b, 0.36))
    readonly property color surfaceEnd: Qt.tint("#17151c", Qt.rgba(coverAccent.r, coverAccent.g, coverAccent.b, 0.12))
    ColorQuantizer { id: coverPalette; source: popup.cover; depth: 2; rescaleSize: 64 }
    visible: opened && !suppressNotifications
    anchors { top: true; right: true }
    margins { top: 64; right: 24 }
    implicitWidth: Math.min(310, screen.width - 32)
    implicitHeight: 82
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "music-notification"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    IpcHandler {
        target: "musicNotify"
        function show(title: string, artist: string, mode: string): void {
            if (popup.suppressNotifications) return
            popup.trackTitle = title
            popup.artist = artist
            popup.mode = mode
            popup.cover = ""
            var player = Mpris.players.values.find(function(value) { return value.trackTitle === title && value.trackArtUrl })
            if (player) popup.cover = player.trackArtUrl
            else if (!coverQuery.running) coverQuery.running = true
            popup.opened = true
            hideTimer.restart()
        }
    }
    Process {
        id: coverQuery
        command: ["python3", "-B", Quickshell.env("HOME") + "/.config/quickshell/scripts/local_player.py", "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { var state = JSON.parse(text); if (state.title === popup.trackTitle && state.cover) popup.cover = state.cover } catch (error) {}
            }
        }
    }
    Timer { id: hideTimer; interval: popup.mode === "scrobbled" ? 1500 : 4200; onTriggered: popup.opened = false }
    Rectangle {
        anchors.fill: parent; anchors.margins: 3; radius: 16
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: popup.surfaceStart; Behavior on color { ColorAnimation { duration: 240 } } }
            GradientStop { position: 1; color: popup.surfaceEnd; Behavior on color { ColorAnimation { duration: 240 } } }
        }
        border.color: Qt.rgba(popup.coverAccent.r, popup.coverAccent.g, popup.coverAccent.b, 0.55); border.width: 1
        Behavior on border.color { ColorAnimation { duration: 240 } }
        ClippingRectangle {
            x: 10; anchors.verticalCenter: parent.verticalCenter
            width: 54; height: 54; radius: 11; color: popup.surfaceStart
            Text { anchors.centerIn: parent; text: "\uf001"; color: Qt.tint("#e8e0ef", Qt.rgba(popup.coverAccent.r, popup.coverAccent.g, popup.coverAccent.b, 0.3)); font.family: "Symbols Nerd Font Mono"; font.pixelSize: 20 }
            Image { anchors.fill: parent; source: popup.cover; visible: status === Image.Ready; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
        Column {
            x: 76; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - 14; spacing: 5
            Text { width: parent.width; text: popup.trackTitle; color: "#f3eaff"; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: -0.2; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight; textFormat: Text.PlainText }
            Text { width: parent.width; text: popup.artist; color: Qt.tint("#c2bac9", Qt.rgba(popup.coverAccent.r, popup.coverAccent.g, popup.coverAccent.b, 0.2)); font.pixelSize: 10; elide: Text.ElideRight; textFormat: Text.PlainText }
        }
        MouseArea { anchors.fill: parent; onClicked: popup.opened = false }
    }
}
