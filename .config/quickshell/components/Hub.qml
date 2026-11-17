import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../controls/PanelTheme.js" as Theme
import "../controls"
import "hub"

Item {
    id: root

    signal backRequested
    signal panelRequested(string panel)

    IpcHandler {
        target: "hub"
        function toggle(): void {
            root.toggle();
        }
        function open(section: string): void {
            root.open(JSON.stringify({ section: section }));
        }
        function close(): void {
            root.dismiss();
        }
    }

    property var shell: null
    property var manifest: null
    property bool opened: false

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/scripts"
    readonly property color onAccent: "#221c21"
    readonly property var sections: [
        { id: "watchers", label: "Watchers", icon: "󰈺", hint: "Fish background watchers" },
        { id: "bots", label: "Bots", icon: "󰚩", hint: "Systemd bot services" },
        { id: "downloads", label: "Downloads", icon: "󰇚", hint: "Grab media with yt-dlp" },
        { id: "nyaa", label: "Nyaa", icon: "󰊓", hint: "Anime release torrents" }
    ]

    function open(payloadJson) {
        try {
            var payload = JSON.parse(payloadJson || "{}");
            if (payload.section) {
                var s = payload.section === "fish" ? "watchers" : payload.section === "ytdlp" ? "downloads" : payload.section;
                hubContent.currentSection = s;
            }
        } catch (e) {}
        opened = true;
        hubContent.refreshSection();
        Qt.callLater(function() {
            card.forceActiveFocus();
        });
    }

    function close() {
        opened = false;
    }

    function dismiss() {
        opened = false;
        if (shell)
            shell.hide("y.hub");
    }

    function toggle() {
        if (opened)
            dismiss();
        else
            open("{}");
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.opened
        onActivated: root.dismiss()
    }

    PanelWindow {
        id: panel

        Shortcut {
            sequence: "B"
            context: Qt.WindowShortcut
            enabled: root.opened
            onActivated: {
                root.close();
                root.backRequested();
            }
        }

        PanelNavigation {
            x: 16
            y: 8
            width: parent.width - 32
            z: 100
            currentPanel: "hub"
            onSelected: function (p) {
                root.panelRequested(p);
            }
        }

        visible: root.opened
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        WlrLayershell.namespace: "y-hub"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.00, 0.00, 0.00, 0.45)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Rectangle {
            anchors.fill: card
            anchors.topMargin: 6
            anchors.bottomMargin: -10
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: card.radius + 2
            color: "#55000000"
            opacity: card.opacity
            scale: card.scale
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(620, panel.width - 32)
            height: Math.min(520, panel.height - 112, hubMainColumn.implicitHeight + 36)
            radius: Theme.panelRadius
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            gradient: PanelGradient {}
            border.color: Theme.border
            border.width: 1
            PanelAura { radius: parent.radius }
            clip: true
            opacity: root.opened ? 1 : 0
            scale: root.opened ? 1 : 0.97
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            focus: true
            Keys.onEscapePressed: root.dismiss()

            MouseArea {
                anchors.fill: parent
                onClicked: card.forceActiveFocus()
            }

            Item {
                id: hubContent
                anchors.fill: parent
                anchors.margins: 18

                property string currentSection: "watchers"
                property var watchersList: []
                property var botsList: []
                property string activeLogName: ""
                property string activeLogType: "watchers"
                property var activeLogEntries: []

                property string downloadUrl: ""
                property string downloadFormat: "video"
                property string ytQuery: ""
                property bool ytSearching: false
                property bool ytLoadingMore: false
                property int ytPage: 1
                property bool ytHasMore: false
                property string ytActiveQuery: ""
                property string ytKind: "videos"
                property var ytPlaylist: null
                property var ytPlaylistCache: null
                property bool downloadPlaylist: false
                readonly property bool urlIsPlaylist: /[?&]list=[A-Za-z0-9_-]+/.test(downloadUrl)
                property var liveDownload: null

                ListModel { id: ytModel }

                property string nyaaQuery: ""
                property var nyaaResults: []
                property bool nyaaSearching: false

                property string toast: ""
                property int downloadsView: 0
                property var expandedDownloads: ({})
                property int activeDownloadsCount: 0

                ListModel { id: downloadsModel }

                readonly property int activeWatchersCount: watchersList.filter(item => item && item.running).length
                readonly property int activeBotsCount: botsList.filter(item => item && item.running).length
                readonly property int sectionIndex: Math.max(0, root.sections.map(s => s.id).indexOf(currentSection))
                readonly property var sectionInfo: root.sections[sectionIndex]
                readonly property bool serviceSection: currentSection === "watchers" || currentSection === "bots"
                readonly property bool refreshing: watchersProc.running || botsProc.running || actionProc.running

                function formatMemory(mem) {
                    if (!mem) return "";
                    if (typeof mem === "string") return mem;
                    if (typeof mem === "number") return (mem / (1024 * 1024)).toFixed(1) + " MB";
                    return String(mem);
                }

                function notify(message) {
                    toast = message;
                    toastTimer.restart();
                }

                function refreshSection() {
                    if (currentSection === "watchers") {
                        watchersProc.running = false;
                        watchersProc.running = true;
                    } else if (currentSection === "bots") {
                        botsProc.running = false;
                        botsProc.running = true;
                    }
                }

                function toggleWatcher(name, running) {
                    actionProc.command = ["python3", root.scriptsDir + "/fish.py", running ? "stop" : "start", name];
                    actionProc.running = false;
                    actionProc.running = true;
                }

                function toggleBot(name, running) {
                    actionProc.command = ["python3", root.scriptsDir + "/bots.py", running ? "stop" : "start", name];
                    actionProc.running = false;
                    actionProc.running = true;
                }

                function viewLogs(name, type) {
                    activeLogName = name;
                    activeLogType = type;
                    activeLogEntries = [];
                    logsProc.command = ["python3", root.scriptsDir + (type === "watchers" ? "/fish.py" : "/bots.py"), type === "watchers" ? "logs" : "activity", name];
                    logsProc.running = false;
                    logsProc.running = true;
                }

                function triggerDownload(url, mode) {
                    if (!url || url.trim() === "") return;
                    mode = mode || downloadFormat;
                    Quickshell.execDetached(["python3", root.scriptsDir + "/download.py", mode, url.trim()]);
                    notify((mode.indexOf("playlist") === 0 ? "Playlist " : "") + (mode.indexOf("audio") >= 0 ? "audio" : "video") + " download started");
                    downloadsKick.restart();
                }

                function pollDownloads() {
                    if (!downloadsProc.running)
                        downloadsProc.running = true;
                }

                function toggleDownloadLog(id) {
                    var next = Object.assign({}, expandedDownloads);
                    next[id] = !next[id];
                    expandedDownloads = next;
                }

                function clearDownloads() {
                    Quickshell.execDetached(["python3", root.scriptsDir + "/downloads_status.py", "clear"]);
                    downloadsKick.restart();
                }

                function syncDownloads(items, nowSeconds) {
                    var ids = items.map(item => item.id);
                    for (var i = downloadsModel.count - 1; i >= 0; i--) {
                        if (ids.indexOf(downloadsModel.get(i).downloadId) < 0)
                            downloadsModel.remove(i);
                    }
                    var running = 0;
                    for (var j = 0; j < items.length; j++) {
                        var item = items[j];
                        if (item.running)
                            running++;
                        var entry = {
                            downloadId: item.id,
                            title: item.title || "",
                            url: item.url || "",
                            mode: item.mode || "video",
                            status: item.status || "starting",
                            percent: typeof item.percent === "number" ? item.percent : -1,
                            speed: item.speed || "",
                            eta: item.eta || "",
                            folder: item.folder || "",
                            linesText: (item.lines || []).join("\n"),
                            playlist: !!item.playlist,
                            phase: item.phase || "",
                            playlistTitle: item.playlistTitle || "",
                            item: item.item || 0,
                            total: item.total || 0,
                            failedItems: item.failedItems || 0,
                            checked: item.checked || 0,
                            checkTotal: item.checkTotal || 0,
                            skipped: item.skipped || 0,
                            alreadyDownloaded: item.alreadyDownloaded || 0
                        };
                        var found = -1;
                        for (var k = 0; k < downloadsModel.count; k++) {
                            if (downloadsModel.get(k).downloadId === item.id) {
                                found = k;
                                break;
                            }
                        }
                        if (found < 0) {
                            downloadsModel.insert(Math.min(j, downloadsModel.count), entry);
                        } else {
                            if (found !== j)
                                downloadsModel.move(found, j, 1);
                            downloadsModel.set(j, entry);
                        }
                    }
                    activeDownloadsCount = running;
                    var live = null;
                    for (var r = 0; r < items.length; r++) {
                        if (items[r].running) {
                            live = items[r];
                            break;
                        }
                    }
                    if (!live && items.length > 0 && nowSeconds - (items[0].updated || 0) < 12)
                        live = items[0];
                    liveDownload = live;
                }

                function searchYoutube() {
                    if (!ytQuery || ytQuery.trim() === "") return;
                    ytActiveQuery = ytQuery.trim();
                    ytPlaylist = null;
                    ytPlaylistCache = null;
                    ytSearching = true;
                    ytLoadingMore = false;
                    ytHasMore = false;
                    ytModel.clear();
                    fetchYoutubePage(1);
                }

                function loadMoreYoutube() {
                    if (!ytHasMore || ytSearching || ytLoadingMore || ytActiveQuery === "") return;
                    ytLoadingMore = true;
                    fetchYoutubePage(ytPage + 1);
                }

                function setYoutubeKind(kind) {
                    if (ytKind === kind && !ytPlaylist) return;
                    ytKind = kind;
                    ytPlaylist = null;
                    ytPlaylistCache = null;
                    ytModel.clear();
                    ytHasMore = false;
                    if (ytQuery.trim() !== "")
                        searchYoutube();
                }

                function snapshotYoutube() {
                    var items = [];
                    for (var i = 0; i < ytModel.count; i++) {
                        var row = ytModel.get(i);
                        items.push({ url: row.url, title: row.title, channel: row.channel, thumbnail: row.thumbnail, duration: row.duration, isPlaylist: row.isPlaylist });
                    }
                    return items;
                }

                function openPlaylist(url, title) {
                    if (!ytPlaylist)
                        ytPlaylistCache = { items: snapshotYoutube(), page: ytPage, hasMore: ytHasMore };
                    ytPlaylist = { url: url, title: title };
                    ytModel.clear();
                    ytHasMore = false;
                    ytLoadingMore = false;
                    ytSearching = true;
                    fetchYoutubePage(1);
                }

                function closePlaylist() {
                    var cache = ytPlaylistCache;
                    ytPlaylist = null;
                    ytPlaylistCache = null;
                    ytSearchProc.running = false;
                    ytSearching = false;
                    ytLoadingMore = false;
                    ytModel.clear();
                    if (cache) {
                        appendYoutube(cache.items, true);
                        ytPage = cache.page;
                        ytHasMore = cache.hasMore;
                    }
                }

                function fetchYoutubePage(page) {
                    ytPage = page;
                    var kind = ytPlaylist ? "tracks" : ytKind;
                    var query = ytPlaylist ? ytPlaylist.url : ytActiveQuery;
                    ytSearchProc.command = ["python3", root.scriptsDir + "/youtube.py", query, String(page), kind];
                    ytSearchProc.running = false;
                    ytSearchProc.running = true;
                }

                function appendYoutube(items, playlists) {
                    var seen = {};
                    for (var i = 0; i < ytModel.count; i++)
                        seen[ytModel.get(i).url] = true;
                    for (var j = 0; j < items.length; j++) {
                        var item = items[j] || {};
                        if (!item.url || seen[item.url]) continue;
                        seen[item.url] = true;
                        ytModel.append({
                            url: item.url,
                            title: item.title || "",
                            channel: item.uploader || item.channel || "",
                            thumbnail: item.thumbnail || "",
                            duration: String(item.duration || item.duration_string || ""),
                            isPlaylist: item.isPlaylist !== undefined ? !!item.isPlaylist : !!playlists
                        });
                    }
                }

                function searchNyaa() {
                    if (!nyaaQuery || nyaaQuery.trim() === "") return;
                    nyaaSearching = true;
                    nyaaProc.command = ["python3", root.scriptsDir + "/nyaa.py", nyaaQuery.trim()];
                    nyaaProc.running = false;
                    nyaaProc.running = true;
                }

                function downloadTorrent(magnet) {
                    if (!magnet) return;
                    Quickshell.execDetached(["python3", root.scriptsDir + "/nyaa.py", "--download", magnet]);
                    notify("Torrent sent to client");
                }

                Component.onCompleted: refreshSection()

                onCurrentSectionChanged: {
                    activeLogName = "";
                    refreshSection();
                }

                Timer {
                    id: downloadsKick
                    interval: 700
                    onTriggered: hubContent.pollDownloads()
                }

                Timer {
                    interval: hubContent.activeDownloadsCount > 0 ? 600 : 4000
                    repeat: true
                    triggeredOnStart: true
                    running: root.opened && hubContent.currentSection === "downloads"
                    onTriggered: hubContent.pollDownloads()
                }

                Process {
                    id: downloadsProc
                    command: ["python3", root.scriptsDir + "/downloads_status.py"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                var data = JSON.parse(text || "{}");
                                hubContent.syncDownloads(data.items || [], data.now || 0);
                            } catch (e) {}
                        }
                    }
                }

                Timer {
                    id: toastTimer
                    interval: 2400
                    onTriggered: hubContent.toast = ""
                }

                Process {
                    id: watchersProc
                    command: ["python3", root.scriptsDir + "/fish.py", "list"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                hubContent.watchersList = JSON.parse(text || "[]");
                            } catch (e) {
                                hubContent.watchersList = [];
                            }
                        }
                    }
                }

                Process {
                    id: botsProc
                    command: ["python3", root.scriptsDir + "/bots.py", "list"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                hubContent.botsList = JSON.parse(text || "[]");
                            } catch (e) {
                                hubContent.botsList = [];
                            }
                        }
                    }
                }

                Process {
                    id: actionProc
                    onExited: code => hubContent.refreshSection()
                }

                Process {
                    id: logsProc
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                var data = JSON.parse(text || "{}");
                                hubContent.activeLogEntries = data.entries || [];
                            } catch (e) {
                                hubContent.activeLogEntries = [];
                            }
                        }
                    }
                }

                Process {
                    id: ytSearchProc
                    stdout: StdioCollector {
                        onStreamFinished: {
                            var hasMore = false;
                            try {
                                var data = JSON.parse(text || "{}");
                                var items = Array.isArray(data) ? data : (data.results || data.entries || []);
                                hubContent.appendYoutube(items, hubContent.ytKind === "playlists" && !hubContent.ytPlaylist);
                                hasMore = !Array.isArray(data) && !!data.hasMore;
                            } catch (e) {}
                            hubContent.ytHasMore = hasMore;
                            hubContent.ytSearching = false;
                            hubContent.ytLoadingMore = false;
                        }
                    }
                }

                Process {
                    id: nyaaProc
                    stdout: StdioCollector {
                        onStreamFinished: {
                            hubContent.nyaaSearching = false;
                            try {
                                var data = JSON.parse(text || "{}");
                                hubContent.nyaaResults = data.results || [];
                            } catch (e) {
                                hubContent.nyaaResults = [];
                            }
                        }
                    }
                }

                readonly property real fitHeight: activeLogName !== "" ? 2000 : currentSection === "watchers" ? watchersHubList.fitHeight : currentSection === "bots" ? botsHubList.fitHeight : currentSection === "downloads" ? downloadsColumn.implicitHeight : currentSection === "nyaa" ? nyaaColumn.implicitHeight : 2000

                ColumnLayout {
                    id: hubMainColumn
                    anchors.fill: parent
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 13
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.32) }
                                GradientStop { position: 1; color: Qt.alpha(Theme.accent, 0.1) }
                            }
                            border.width: 1
                            border.color: Qt.alpha(Theme.accent, 0.4)

                            Text {
                                anchors.centerIn: parent
                                text: hubContent.sectionInfo.icon
                                font.family: Theme.iconFont
                                font.pixelSize: 20
                                color: Theme.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                visible: hubContent.currentSection !== "downloads"
                                text: hubContent.sectionInfo.label
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                color: Theme.foreground
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: hubContent.currentSection !== "downloads"
                                text: hubContent.toast !== "" ? "󰄬  " + hubContent.toast : hubContent.sectionInfo.hint
                                font.pixelSize: 11
                                color: hubContent.toast !== "" ? Theme.success : Theme.dim
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            ColumnLayout {
                                id: headerProgress
                                readonly property var item: hubContent.liveDownload
                                readonly property real trackPercent: item && typeof item.percent === "number" ? item.percent : -1
                                readonly property bool isPlaylist: !!item && !!item.playlist && (item.total || 0) > 0
                                readonly property real percent: isPlaylist ? Math.min(100, ((Math.max(1, item.item) - 1) + (item.status === "done" ? 1 : trackPercent >= 0 ? trackPercent / 100 : 0)) / item.total * 100) : trackPercent
                                readonly property color tint: item && item.status === "failed" ? Theme.danger : item && item.status === "done" ? Theme.success : Theme.accent
                                readonly property string statusText: {
                                    if (!item) return "";
                                    if (item.status === "done") return "✓ Done";
                                    if (item.status === "failed") return "✗ Failed";
                                    var glyph = item.status === "downloading" ? "↓" : item.status === "converting" ? "♫" : item.status === "processing" ? "◈" : item.status === "checking" ? "⌕" : "◌";
                                    var parts = [glyph + " " + (item.phase || "Starting")];
                                    if (item.status === "checking" && item.checkTotal) parts.push(item.checked + "/" + item.checkTotal);
                                    else if (isPlaylist) parts.push(item.item + "/" + item.total);
                                    if (item.playlist && (item.skipped || 0) + (item.failedItems || 0) > 0) parts.push(((item.skipped || 0) + (item.failedItems || 0)) + " unavailable");
                                    if (trackPercent >= 0 && item.status !== "checking") parts.push(trackPercent.toFixed(0) + "%");
                                    if (item.speed) parts.push(item.speed);
                                    if (item.eta) parts.push(item.eta);
                                    return parts.join(" · ");
                                }
                                Layout.fillWidth: true
                                visible: hubContent.currentSection === "downloads"
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: hubContent.toast !== "" ? hubContent.toast : headerProgress.item ? (headerProgress.item.playlist ? "󰲸  " + (headerProgress.item.playlistTitle || "Playlist") + (headerProgress.item.title ? "  ·  " + headerProgress.item.title : "") : (headerProgress.item.title || "Preparing download…")) : "Nothing downloading"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: hubContent.toast !== "" ? Theme.success : headerProgress.item ? Theme.foreground : Theme.muted
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 5
                                        radius: 3
                                        color: Qt.alpha(Theme.foreground, 0.08)
                                        clip: true

                                        Rectangle {
                                            visible: headerProgress.percent >= 0 || (headerProgress.item && headerProgress.item.status === "done")
                                            height: parent.height
                                            width: headerProgress.item && headerProgress.item.status === "done" ? parent.width : parent.width * Math.max(0, Math.min(100, headerProgress.percent)) / 100
                                            radius: 3
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0; color: Qt.alpha(headerProgress.tint, 0.55) }
                                                GradientStop { position: 1; color: headerProgress.tint }
                                            }
                                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                        }

                                        Rectangle {
                                            id: sweep
                                            visible: headerProgress.item !== null && headerProgress.percent < 0 && headerProgress.item.status !== "done"
                                            height: parent.height
                                            width: parent.width * 0.25
                                            radius: 3
                                            color: headerProgress.tint
                                            SequentialAnimation on x {
                                                running: sweep.visible
                                                loops: Animation.Infinite
                                                NumberAnimation { from: -sweep.width; to: sweep.parent.width; duration: 1200; easing.type: Easing.InOutQuad }
                                            }
                                        }
                                    }

                                    Text {
                                        visible: headerProgress.item !== null
                                        text: headerProgress.statusText
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: headerProgress.tint
                                    }
                                }

                                TapHandler {
                                    enabled: headerProgress.item !== null
                                    onTapped: hubContent.downloadsView = 1
                                }

                                HoverHandler {
                                    enabled: headerProgress.item !== null
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }

                        Rectangle {
                            visible: hubContent.serviceSection
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: statsRow.implicitWidth + 24
                            radius: 10
                            color: Qt.alpha(Theme.foreground, 0.04)
                            border.width: 1
                            border.color: Qt.alpha(Theme.foreground, 0.08)

                            Row {
                                id: statsRow
                                readonly property int activeCount: hubContent.currentSection === "watchers" ? hubContent.activeWatchersCount : hubContent.activeBotsCount
                                readonly property int totalCount: hubContent.currentSection === "watchers" ? hubContent.watchersList.length : hubContent.botsList.length
                                anchors.centerIn: parent
                                spacing: 8

                                StatusDot {
                                    anchors.verticalCenter: parent.verticalCenter
                                    live: statsRow.activeCount > 0
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: statsRow.activeCount + "/" + statsRow.totalCount + (hubContent.currentSection === "watchers" ? " active" : " online")
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.foreground
                                }
                            }
                        }

                        HubButton {
                            visible: hubContent.serviceSection
                            icon: "󰑐"
                            spinning: hubContent.refreshing
                            onClicked: hubContent.refreshSection()
                        }
                    }

                    Rectangle {
                        id: tabBar
                        readonly property real tabWidth: (width - 8) / root.sections.length
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 13
                        color: Qt.alpha(Theme.foreground, 0.035)
                        border.width: 1
                        border.color: Qt.alpha(Theme.foreground, 0.07)

                        Rectangle {
                            y: 4
                            x: 4 + hubContent.sectionIndex * tabBar.tabWidth
                            width: tabBar.tabWidth
                            height: parent.height - 8
                            radius: 10
                            color: Qt.alpha(Theme.accent, 0.2)
                            border.width: 1
                            border.color: Qt.alpha(Theme.accent, 0.45)
                            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        }

                        Row {
                            x: 4
                            y: 4

                            Repeater {
                                model: root.sections

                                delegate: Item {
                                    id: tab
                                    readonly property bool selected: hubContent.currentSection === modelData.id
                                    width: tabBar.tabWidth
                                    height: tabBar.height - 8

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 7

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.icon
                                            font.family: Theme.iconFont
                                            font.pixelSize: 15
                                            color: tab.selected ? Theme.accent : tabMouse.containsMouse ? Theme.foreground : Theme.muted
                                            Behavior on color { ColorAnimation { duration: 140 } }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label
                                            font.pixelSize: 12
                                            font.weight: tab.selected ? Font.Bold : Font.Medium
                                            color: tab.selected ? Theme.foreground : tabMouse.containsMouse ? Theme.foreground : Theme.muted
                                            Behavior on color { ColorAnimation { duration: 140 } }
                                        }
                                    }

                                    Timer {
                                        interval: 180
                                        running: root.opened && tabMouse.containsMouse && !tab.selected
                                        onTriggered: hubContent.currentSection = modelData.id
                                    }

                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hubContent.currentSection = modelData.id
                                    }
                                }
                            }
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: hubContent.fitHeight
                        currentIndex: hubContent.sectionIndex

                        Item {
                            HubList {
                                id: watchersHubList
                                anchors.fill: parent
                                visible: hubContent.activeLogName === ""
                                model: hubContent.watchersList
                                emptyGlyph: "󰈺"
                                emptyTitle: watchersProc.running ? "Loading watchers…" : "No watchers found"
                                emptyHint: "Fish watcher functions will appear here"
                                rowDelegate: ServiceRow {
                                    item: modelData
                                    glyph: "󰈺"
                                    onLabel: "ACTIVE"
                                    offLabel: "STOPPED"
                                    detail: running && modelData.memory ? hubContent.formatMemory(modelData.memory) + " · fish daemon" : "Fish function"
                                    onLogsRequested: hubContent.viewLogs(modelData.name, "watchers")
                                    onToggleRequested: hubContent.toggleWatcher(modelData.name, modelData.running)
                                }
                            }

                            LogPane {
                                anchors.fill: parent
                                visible: hubContent.activeLogName !== ""
                                title: hubContent.activeLogName
                                entries: hubContent.activeLogEntries
                                fallbackLabel: "Log"
                                onBack: hubContent.activeLogName = ""
                            }
                        }

                        Item {
                            HubList {
                                id: botsHubList
                                anchors.fill: parent
                                visible: hubContent.activeLogName === ""
                                model: hubContent.botsList
                                emptyGlyph: "󰚩"
                                emptyTitle: botsProc.running ? "Loading bots…" : "No bots found"
                                emptyHint: "Bots in ~/0/bots will appear here"
                                rowDelegate: ServiceRow {
                                    item: modelData
                                    glyph: "󰚩"
                                    onLabel: "ONLINE"
                                    offLabel: "OFFLINE"
                                    detail: running && modelData.memory ? hubContent.formatMemory(modelData.memory) + " · systemd" : (modelData.entry || "main.py") + " · ~/0/bots"
                                    onLogsRequested: hubContent.viewLogs(modelData.name, "bots")
                                    onToggleRequested: hubContent.toggleBot(modelData.name, modelData.running)
                                }
                            }

                            LogPane {
                                anchors.fill: parent
                                visible: hubContent.activeLogName !== ""
                                title: hubContent.activeLogName
                                entries: hubContent.activeLogEntries
                                fallbackLabel: "Activity"
                                onBack: hubContent.activeLogName = ""
                            }
                        }

                        ColumnLayout {
                            id: downloadsColumn
                            spacing: 10

                            SearchField {
                                id: urlField
                                Layout.fillWidth: true
                                glyph: "󰌹"
                                placeholder: "Paste a YouTube, SoundCloud or media link…"
                                actionIcon: "󰇚"
                                actionLabel: "Download"
                                text: hubContent.downloadUrl
                                onTextChanged: hubContent.downloadUrl = text
                                onSubmitted: {
                                    hubContent.triggerDownload(urlField.text, (hubContent.urlIsPlaylist && hubContent.downloadPlaylist ? "playlist-" : "") + hubContent.downloadFormat);
                                    urlField.text = "";
                                }

                                HubButton {
                                    visible: hubContent.urlIsPlaylist
                                    icon: "󰲸"
                                    label: "Playlist"
                                    active: hubContent.downloadPlaylist
                                    onClicked: hubContent.downloadPlaylist = !hubContent.downloadPlaylist
                                }

                                HubButton {
                                    icon: "󰎆"
                                    label: "MP3"
                                    active: hubContent.downloadFormat === "audio"
                                    onClicked: hubContent.downloadFormat = hubContent.downloadFormat === "audio" ? "video" : "audio"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                HubButton {
                                    icon: "󰗃"
                                    label: "YouTube"
                                    active: hubContent.downloadsView === 0
                                    onClicked: hubContent.downloadsView = 0
                                }

                                HubButton {
                                    icon: hubContent.activeDownloadsCount > 0 ? "󰑓" : "󰇚"
                                    spinning: hubContent.activeDownloadsCount > 0
                                    label: hubContent.activeDownloadsCount > 0 ? "Activity · " + hubContent.activeDownloadsCount : "Activity"
                                    active: hubContent.downloadsView === 1
                                    onClicked: {
                                        hubContent.downloadsView = 1;
                                        hubContent.pollDownloads();
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                HubButton {
                                    visible: hubContent.downloadsView === 1 && downloadsModel.count > hubContent.activeDownloadsCount
                                    icon: "󰃢"
                                    label: "Clear finished"
                                    onClicked: hubContent.clearDownloads()
                                }
                            }

                            HubList {
                                id: downloadsHubList
                                visible: hubContent.downloadsView === 1
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: fitHeight
                                model: downloadsModel
                                emptyGlyph: "󰇚"
                                emptyTitle: "No downloads yet"
                                emptyHint: "Progress and logs will show up here"
                                rowDelegate: DownloadRow {
                                    title: model.title
                                    url: model.url
                                    mode: model.mode
                                    status: model.status
                                    percent: model.percent
                                    speed: model.speed
                                    eta: model.eta
                                    folder: model.folder
                                    linesText: model.linesText
                                    playlist: model.playlist
                                    phase: model.phase
                                    playlistTitle: model.playlistTitle
                                    item: model.item
                                    total: model.total
                                    failedItems: model.failedItems
                                    checked: model.checked
                                    checkTotal: model.checkTotal
                                    skipped: model.skipped
                                    alreadyDownloaded: model.alreadyDownloaded
                                    expanded: !!hubContent.expandedDownloads[model.downloadId]
                                    onToggleLog: hubContent.toggleDownloadLog(model.downloadId)
                                }
                            }

                            SearchField {
                                visible: hubContent.downloadsView === 0
                                Layout.fillWidth: true
                                glyph: "󰗃"
                                placeholder: hubContent.ytKind === "playlists" ? "Search playlists…" : "Search videos…"
                                busy: hubContent.ytSearching
                                text: hubContent.ytQuery
                                onTextChanged: hubContent.ytQuery = text
                                onSubmitted: hubContent.searchYoutube()

                                HubButton {
                                    icon: "󰲸"
                                    label: "Playlists"
                                    active: hubContent.ytKind === "playlists"
                                    onClicked: hubContent.setYoutubeKind(hubContent.ytKind === "playlists" ? "videos" : "playlists")
                                }
                            }

                            RowLayout {
                                visible: hubContent.downloadsView === 0 && hubContent.ytPlaylist !== null
                                Layout.fillWidth: true
                                spacing: 8

                                HubButton {
                                    icon: "󰁍"
                                    label: "Back"
                                    onClicked: hubContent.closePlaylist()
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "󰲸  " + (hubContent.ytPlaylist ? hubContent.ytPlaylist.title : "")
                                    font.family: Theme.iconFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Theme.foreground
                                    elide: Text.ElideRight
                                }

                                HubButton {
                                    icon: "󰎆"
                                    label: "All MP3"
                                    tint: Theme.success
                                    onClicked: hubContent.triggerDownload(hubContent.ytPlaylist.url, "playlist-audio")
                                }

                                HubButton {
                                    icon: "󰕧"
                                    label: "All MP4"
                                    onClicked: hubContent.triggerDownload(hubContent.ytPlaylist.url, "playlist-video")
                                }
                            }

                            HubList {
                                id: ytHubList
                                visible: hubContent.downloadsView === 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: fitHeight
                                model: ytModel
                                busy: hubContent.ytSearching
                                hasMore: hubContent.ytHasMore
                                loadingMore: hubContent.ytLoadingMore
                                onEndReached: hubContent.loadMoreYoutube()
                                emptyGlyph: "󰗃"
                                emptyTitle: "Nothing here yet"
                                emptyHint: "Drag right for MP3, left for MP4"
                                rowDelegate: VideoRow {
                                    videoTitle: model.title
                                    channel: model.channel
                                    thumbnail: model.thumbnail
                                    duration: model.duration
                                    playlist: model.isPlaylist
                                    onOpened: hubContent.openPlaylist(model.url, model.title)
                                    onAudioRequested: hubContent.triggerDownload(model.url, model.isPlaylist ? "playlist-audio" : "audio")
                                    onVideoRequested: hubContent.triggerDownload(model.url, model.isPlaylist ? "playlist-video" : "video")
                                }
                            }
                        }

                        ColumnLayout {
                            id: nyaaColumn
                            spacing: 10

                            SearchField {
                                Layout.fillWidth: true
                                glyph: "󰊓"
                                placeholder: "Search Nyaa releases & anime torrents…"
                                busy: hubContent.nyaaSearching
                                text: hubContent.nyaaQuery
                                onTextChanged: hubContent.nyaaQuery = text
                                onSubmitted: hubContent.searchNyaa()
                            }

                            HubList {
                                id: nyaaHubList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: fitHeight
                                model: hubContent.nyaaResults
                                busy: hubContent.nyaaSearching
                                emptyGlyph: "󰊓"
                                emptyTitle: "No releases yet"
                                emptyHint: "Drag a result left to download it"
                                rowDelegate: SwipeRow {
                                    height: 66
                                    allowRight: false
                                    leftIcon: "󰇚"
                                    leftLabel: "Download"
                                    leftTint: Theme.accent
                                    onSwipedLeft: hubContent.downloadTorrent(modelData.magnet)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.title || ""
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                color: Theme.foreground
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                spacing: 10

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: sizeText.implicitWidth + 12
                                                    height: 18
                                                    radius: 6
                                                    color: Qt.alpha(Theme.accent, 0.15)
                                                    Text {
                                                        id: sizeText
                                                        anchors.centerIn: parent
                                                        text: modelData.size || "?"
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        color: Theme.accent
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "󰁝 " + (modelData.seeders || "0")
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: Number(modelData.seeders || 0) > 0 ? Theme.success : Theme.dim
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !!modelData.date
                                                    text: modelData.date || ""
                                                    font.pixelSize: 11
                                                    color: Theme.dim
                                                }
                                            }
                                        }

                                        HubButton {
                                            icon: "󰇚"
                                            label: "Get"
                                            onClicked: hubContent.downloadTorrent(modelData.magnet)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
