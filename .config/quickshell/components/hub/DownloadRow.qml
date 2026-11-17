import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

Rectangle {
    id: row
    property string title: ""
    property string url: ""
    property string mode: "video"
    property string status: "starting"
    property real percent: -1
    property string speed: ""
    property string eta: ""
    property string linesText: ""
    property string folder: ""
    property bool playlist: false
    property string phase: ""
    property string playlistTitle: ""
    property int item: 0
    property int total: 0
    property int failedItems: 0
    property int checked: 0
    property int checkTotal: 0
    property int skipped: 0
    property int alreadyDownloaded: 0
    readonly property int unavailable: skipped + failedItems
    readonly property real overall: playlist && total > 0 ? Math.min(100, ((Math.max(1, item) - 1) + (status === "done" ? 1 : percent >= 0 ? percent / 100 : 0)) / total * 100) : percent
    readonly property string liveLine: {
        if (!running || phase === "") return "";
        var glyph = status === "downloading" ? "↓" : status === "converting" ? "♫" : status === "checking" ? "⌕" : "◈";
        var out = glyph + " " + phase;
        if (percent >= 0) {
            var filled = Math.round(percent / 100 * 12);
            out += " " + percent.toFixed(1) + "% " + "━".repeat(filled) + "─".repeat(12 - filled);
        }
        if (speed !== "") out += " " + speed;
        if (eta !== "") out += " · " + eta;
        return out;
    }
    property bool expanded: false
    readonly property bool running: status !== "done" && status !== "failed"
    readonly property color statusColor: status === "failed" ? Theme.danger : status === "done" && phase === "Saved with errors" ? "#e8c99a" : status === "done" ? Theme.success : Theme.accent
    readonly property bool partial: status === "done" && phase === "Saved with errors"
    readonly property string statusLabel: status === "done" && (partial || phase === "Already downloaded") ? phase : phase !== "" && running ? phase : ({
        "starting": "Starting",
        "downloading": "Downloading",
        "processing": "Processing",
        "converting": mode === "audio" ? "Converting to MP3" : "Merging",
        "checking": "Checking",
        "done": "Done",
        "failed": "Failed"
    })[status] || status
    signal toggleLog

    width: ListView.view ? ListView.view.width : 0
    height: body.implicitHeight + 24
    radius: 14
    color: rowHover.hovered ? Qt.alpha(Theme.foreground, 0.06) : Qt.alpha(Theme.foreground, 0.03)
    border.width: 1
    border.color: status === "failed" ? Qt.alpha(Theme.danger, 0.35) : running ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.foreground, 0.07)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    clip: true

    HoverHandler { id: rowHover }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.leftMargin: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 11
                color: Qt.alpha(row.statusColor, 0.16)
                border.width: 1
                border.color: Qt.alpha(row.statusColor, 0.4)

                Text {
                    id: stateIcon
                    anchors.centerIn: parent
                    text: row.status === "done" ? "󰄬" : row.status === "failed" ? "󰅖" : row.status === "converting" || row.status === "processing" || row.status === "checking" ? "󰑓" : row.mode === "audio" ? "󰎆" : "󰕧"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: row.statusColor
                    RotationAnimation on rotation {
                        running: row.status === "converting" || row.status === "processing" || row.status === "checking"
                        from: 0
                        to: 360
                        duration: 1100
                        loops: Animation.Infinite
                        onStopped: stateIcon.rotation = 0
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: row.playlist ? "󰲸  " + (row.playlistTitle !== "" ? row.playlistTitle : row.title !== "" ? row.title : "Playlist") : row.title !== "" ? row.title : row.url
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.foreground
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: row.statusLabel.toUpperCase()
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: row.statusColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            var parts = [(row.playlist ? "Playlist " : "") + (row.mode === "audio" ? "MP3" : "MP4")];
                            if (row.status === "checking" && row.checkTotal > 0)
                                parts.push(row.checked + "/" + row.checkTotal + " checked");
                            else if (row.playlist && row.total > 0)
                                parts.push(row.item + "/" + row.total);
                            if (row.playlist && row.unavailable > 0)
                                parts.push(row.unavailable + " unavailable");
                            if (row.playlist && row.alreadyDownloaded > 0)
                                parts.push(row.alreadyDownloaded + " already saved");
                            if (row.playlist && row.running && row.status !== "checking" && row.title !== "")
                                parts.push(row.title);
                            if (row.running && row.percent >= 0)
                                parts.push(Math.round(row.percent) + "%");
                            if (row.speed !== "")
                                parts.push(row.speed);
                            if (row.eta !== "")
                                parts.push("󰔟 " + row.eta);
                            if (row.status === "done" && row.folder !== "")
                                parts.push(row.folder);
                            return "· " + parts.join("  ·  ");
                        }
                        font.pixelSize: 11
                        color: Theme.muted
                        elide: Text.ElideRight
                    }
                }
            }

            HubButton {
                icon: "󰦨"
                active: row.expanded
                onClicked: row.toggleLog()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            visible: row.running
            radius: 2
            color: Qt.alpha(Theme.foreground, 0.08)
            clip: true

            Rectangle {
                id: fill
                visible: row.overall >= 0
                height: parent.height
                width: parent.width * Math.max(0, Math.min(100, row.overall)) / 100
                radius: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.7) }
                    GradientStop { position: 1; color: Theme.accent }
                }
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                visible: row.overall < 0
                height: parent.height
                width: parent.width * 0.3
                radius: 2
                color: Theme.accent
                SequentialAnimation on x {
                    running: row.running && row.overall < 0
                    loops: Animation.Infinite
                    NumberAnimation { from: -row.width * 0.3; to: row.width; duration: 1200; easing.type: Easing.InOutQuad }
                }
            }
        }

        LogTerminal {
            Layout.fillWidth: true
            Layout.preferredHeight: 190
            visible: row.expanded
            caption: "yt-dlp · " + (row.playlist ? "playlist " : "") + (row.mode === "audio" ? "mp3" : "mp4")
            running: row.running
            tint: row.statusColor
            linesText: row.linesText
            liveLine: row.liveLine
        }
    }
}
