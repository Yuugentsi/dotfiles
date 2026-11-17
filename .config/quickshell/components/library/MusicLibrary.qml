import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.Effects
import "../../controls/PanelTheme.js" as Theme
import "../hub"

Item {
    id: library

    property var player: null
    property bool active: false
    property var tracks: []
    property bool loading: false
    property bool loaded: false
    property string query: ""
    property string view: "songs"
    property string drillKind: ""
    property string drillName: ""
    property bool shuffle: false
    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/player.py"
    readonly property string currentPath: player && player.state ? (player.state.path || "") : ""
    readonly property bool currentPlaying: !!player && player.isPlaying
    readonly property var views: [
        { id: "songs", label: "Songs", icon: "󰎈" },
        { id: "artists", label: "Artists", icon: "󰠃" },
        { id: "albums", label: "Albums", icon: "󰀥" }
    ]
    signal closeRequested

    function matches(track) {
        var q = query.trim().toLowerCase();
        if (q === "")
            return true;
        return (track.title + " " + track.artist + " " + track.album).toLowerCase().indexOf(q) >= 0;
    }

    function albumOf(track) {
        if (track.album)
            return track.album;
        var parts = track.path.split("/");
        var folder = parts.length > 1 ? parts[parts.length - 2] : "";
        return folder === "" || folder === "yt" || folder === "music" ? "Singles" : folder;
    }

    function normalize(track) {
        var title = String(track.title || "").replace(/\s*\[[A-Za-z0-9_-]{11}\]\s*$/, "").trim();
        var artist = String(track.artist || "").replace(/ - Topic$/, "").trim();
        if (artist === "") {
            var match = /^(.+?)\s+[-–—]\s+(.+)$/.exec(title);
            if (match) {
                artist = match[1].trim();
                title = match[2].trim();
            }
        }
        return {
            path: track.path,
            title: title !== "" ? title : track.path.split("/").pop(),
            artist: artist,
            album: track.album || "",
            track: track.track || 0,
            cover: track.cover || ""
        };
    }

    readonly property var filteredTracks: tracks.filter(matches)

    readonly property var artistGroups: {
        var groups = {};
        for (var i = 0; i < filteredTracks.length; i++) {
            var t = filteredTracks[i];
            var name = t.artist || "Unknown artist";
            if (!groups[name])
                groups[name] = { name: name, count: 0, cover: "" };
            groups[name].count++;
            if (!groups[name].cover && t.cover)
                groups[name].cover = t.cover;
        }
        return Object.keys(groups).map(k => groups[k]).sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
    }

    readonly property var albumGroups: {
        var groups = {};
        for (var i = 0; i < filteredTracks.length; i++) {
            var t = filteredTracks[i];
            var name = albumOf(t);
            if (!groups[name])
                groups[name] = { name: name, artist: t.artist || "", count: 0, cover: "" };
            groups[name].count++;
            if (!groups[name].cover && t.cover)
                groups[name].cover = t.cover;
            if (groups[name].artist !== (t.artist || ""))
                groups[name].mixed = true;
        }
        return Object.keys(groups).map(k => {
            var g = groups[k];
            if (g.mixed)
                g.artist = "Various artists";
            return g;
        }).sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
    }

    readonly property string drillCover: {
        for (var i = 0; i < drillTracks.length; i++)
            if (drillTracks[i].cover)
                return drillTracks[i].cover;
        return "";
    }
    readonly property string drillSubtitle: {
        if (drillKind === "album") {
            var artists = {};
            drillTracks.forEach(t => artists[t.artist || ""] = true);
            var names = Object.keys(artists).filter(n => n !== "");
            return names.length === 1 ? names[0] : names.length > 1 ? "Various artists" : "";
        }
        if (drillKind === "artist") {
            var albums = {};
            drillTracks.forEach(t => albums[albumOf(t)] = true);
            var count = Object.keys(albums).length;
            return count + (count === 1 ? " album" : " albums");
        }
        return "";
    }

    readonly property var drillTracks: {
        if (drillKind === "artist")
            return filteredTracks.filter(t => (t.artist || "Unknown artist") === drillName);
        if (drillKind === "album")
            return filteredTracks.filter(t => albumOf(t) === drillName).sort((a, b) => (a.track || 999) - (b.track || 999));
        return [];
    }

    function reload() {
        if (!libraryProc.running) {
            loading = true;
            libraryProc.running = true;
        }
    }

    function run(args) {
        actionProc.command = ["python3", "-B", script].concat(args);
        actionProc.running = false;
        actionProc.running = true;
    }

    function playFrom(track, list) {
        if (track.path === currentPath && player) {
            player.togglePlaying();
            return;
        }
        run(["play-queue", track.path, JSON.stringify(list.map(t => t.path))]);
    }

    function playList(list) {
        if (list.length === 0)
            return;
        var start = shuffle ? list[Math.floor(Math.random() * list.length)] : list[0];
        run(["play-queue", start.path, JSON.stringify(list.map(t => t.path))]);
    }

    function toggleShuffle() {
        shuffle = !shuffle;
        run(["shuffle"]);
    }

    function albumCountFor(list) {
        var albums = {};
        list.forEach(t => albums[albumOf(t)] = true);
        return Object.keys(albums).length;
    }

    function openDrill(kind, name) {
        drillKind = kind;
        drillName = name;
    }

    function back() {
        if (drillKind !== "") {
            drillKind = "";
            drillName = "";
        } else {
            closeRequested();
        }
    }

    function focusSearch() {
        searchField.input.forceActiveFocus();
    }

    onActiveChanged: {
        if (active) {
            reload();
            stateProc.running = true;
            Qt.callLater(focusSearch);
        }
    }
    onViewChanged: {
        drillKind = "";
        drillName = "";
    }

    Keys.onEscapePressed: back()

    Process {
        id: libraryProc
        command: ["python3", "-B", library.script, "library"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text || "[]");
                    library.tracks = Array.isArray(data) ? data.map(library.normalize) : [];
                } catch (e) {}
                library.loading = false;
                var missing = library.tracks.some(t => !t.cover);
                if (missing && !library.loaded)
                    coversProc.running = true;
                library.loaded = true;
            }
        }
    }

    Process {
        id: coversProc
        command: ["python3", "-B", library.script, "covers"]
        onExited: library.reload()
    }

    Process {
        id: stateProc
        command: ["python3", "-B", library.script, "state-fast"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    library.shuffle = !!JSON.parse(text || "{}").shuffle;
                } catch (e) {}
            }
        }
    }

    Process {
        id: actionProc
        onExited: if (library.player) library.player.refresh()
    }

    component Cover: ClippingRectangle {
        id: coverBox
        property string source: ""
        property string fallback: "󰎈"
        property int size: 42
        width: size
        height: size
        radius: Math.round(size * 0.24)
        color: Qt.alpha(Theme.foreground, 0.06)

        Text {
            anchors.centerIn: parent
            visible: coverImage.status !== Image.Ready
            text: coverBox.fallback
            font.family: Theme.iconFont
            font.pixelSize: Math.round(coverBox.size * 0.42)
            color: Theme.dim
        }

        Image {
            id: coverImage
            anchors.fill: parent
            source: coverBox.source
            sourceSize.width: coverBox.size * 2
            sourceSize.height: coverBox.size * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }
    }

    component Equalizer: Row {
        id: eq
        property bool playing: false
        property color tint: Theme.accent
        spacing: 2
        height: 14
        Repeater {
            model: 3
            Rectangle {
                id: bar
                required property int index
                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                height: 5
                color: eq.tint
                SequentialAnimation on height {
                    running: eq.playing
                    loops: Animation.Infinite
                    NumberAnimation { to: 14; duration: 260 + bar.index * 90; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 4; duration: 300 + bar.index * 70; easing.type: Easing.InOutSine }
                    onStopped: bar.height = 5
                }
            }
        }
    }

    component TrackRow: Rectangle {
        id: trackRow
        property var track: ({})
        property bool showCover: true
        property bool current: false
        property bool playing: false
        property string subtitle: ""
        signal activated
        width: ListView.view ? ListView.view.width : 0
        height: 56
        radius: 12
        color: current ? Qt.alpha(Theme.accent, 0.12) : rowMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.06) : "transparent"
        border.width: current ? 1 : 0
        border.color: Qt.alpha(Theme.accent, 0.3)
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 12

            Item {
                Layout.preferredWidth: trackRow.showCover ? 42 : 24
                Layout.preferredHeight: 42

                Cover {
                    visible: trackRow.showCover
                    anchors.centerIn: parent
                    source: trackRow.track.cover || ""
                }

                Text {
                    visible: !trackRow.showCover && !trackRow.current
                    anchors.centerIn: parent
                    text: trackRow.track.track ? trackRow.track.track : "·"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    color: Theme.dim
                }

                Rectangle {
                    visible: trackRow.current && trackRow.showCover
                    anchors.fill: parent
                    radius: 10
                    color: "#99221c21"
                }

                Equalizer {
                    visible: trackRow.current
                    anchors.centerIn: parent
                    playing: trackRow.playing
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: trackRow.track.title || ""
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: trackRow.current ? Theme.accent : Theme.foreground
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: trackRow.subtitle
                    font.pixelSize: 11
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }

            Text {
                visible: rowMouse.containsMouse || trackRow.current
                text: trackRow.current && trackRow.playing ? "󰏤" : "󰐊"
                font.family: Theme.iconFont
                font.pixelSize: 18
                color: trackRow.current ? Theme.accent : Theme.foreground
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trackRow.activated()
        }
    }

    ClippingRectangle {
        id: ambient
        anchors.fill: parent
        radius: 20
        color: "transparent"
        readonly property string source: library.drillKind !== "" && library.drillCover !== "" ? library.drillCover : library.player ? library.player.trackArtUrl : ""

        Image {
            id: ambientImage
            anchors.fill: parent
            source: ambient.source
            sourceSize.width: 160
            sourceSize.height: 160
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: ambientImage
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.25
            opacity: ambientImage.status === Image.Ready ? 0.32 : 0
            Behavior on opacity { NumberAnimation { duration: 500 } }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#66221c21" }
                GradientStop { position: 0.45; color: "#e0221c21" }
                GradientStop { position: 1; color: "#f8221c21" }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: miniPlayer.visible ? miniPlayer.height + 26 : 16
        spacing: 12

        Item {
            id: hero
            visible: library.drillKind !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: 148

            ClippingRectangle {
                anchors.fill: parent
                radius: 18
                color: Qt.alpha(Theme.foreground, 0.04)
                border.width: 1
                border.color: Qt.alpha(Theme.foreground, 0.08)

                Image {
                    id: heroBackdrop
                    anchors.fill: parent
                    source: library.drillCover
                    sourceSize.width: 200
                    sourceSize.height: 200
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: heroBackdrop
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                    brightness: -0.25
                    opacity: heroBackdrop.status === Image.Ready ? 0.85 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#40221c21" }
                        GradientStop { position: 1; color: "#d0221c21" }
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 16

                Item {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 120

                    Rectangle {
                        anchors.fill: heroCover
                        anchors.topMargin: 6
                        anchors.bottomMargin: -6
                        radius: heroCover.radius
                        color: "#70000000"
                    }

                    Cover {
                        id: heroCover
                        anchors.fill: parent
                        size: 120
                        radius: library.drillKind === "artist" ? 60 : 14
                        source: library.drillCover
                        fallback: library.drillKind === "artist" ? "󰠃" : "󰀥"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        text: library.drillKind === "artist" ? "󰠃" : "󰀥"
                        font.family: Theme.iconFont
                        font.pixelSize: 15
                        color: Theme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: library.drillName
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        font.letterSpacing: -0.3
                        color: "#e6d7dc"
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            visible: library.drillKind === "album" && library.drillSubtitle !== ""
                            Layout.maximumWidth: 140
                            text: library.drillSubtitle
                            font.pixelSize: 11
                            color: "#e6d7dc"
                            elide: Text.ElideRight
                        }

                        Repeater {
                            model: library.drillKind === "artist" ? [
                                { icon: "󰀥", value: library.albumCountFor(library.drillTracks) },
                                { icon: "󰎈", value: library.drillTracks.length }
                            ] : [
                                { icon: "󰎈", value: library.drillTracks.length }
                            ]
                            Row {
                                spacing: 4
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: Theme.accent
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.value
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: "#e6d7dc"
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Row {
                        Layout.topMargin: 8
                        spacing: 6

                        HubButton {
                            primary: true
                            implicitHeight: 36
                            icon: "󰐊"
                            onClicked: library.playList(library.drillTracks)
                        }

                        HubButton {
                            implicitHeight: 36
                            icon: "󰒝"
                            active: library.shuffle
                            onClicked: library.toggleShuffle()
                        }
                    }
                }
            }

            HubButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 10
                implicitHeight: 28
                icon: "󰁍"
                onClicked: library.back()
            }

        }

        RowLayout {
            visible: library.drillKind === ""
            Layout.fillWidth: true
            spacing: 8

            HubButton {
                implicitHeight: 40
                icon: "󰁍"
                onClicked: library.back()
            }

        SearchField {
            id: searchField
            Layout.fillWidth: true
            implicitHeight: 40
            glyph: "󰍉"
            placeholder: ""
            showAction: false
            text: library.query
            onTextChanged: library.query = text
            onSubmitted: {
                if (library.view === "songs" && library.filteredTracks.length > 0)
                    library.playFrom(library.filteredTracks[0], library.filteredTracks);
            }
        }

            HubButton {
                implicitHeight: 40
                icon: "󰒝"
                active: library.shuffle
                onClicked: library.toggleShuffle()
            }
        }

        RowLayout {
            visible: library.drillKind === ""
            Layout.fillWidth: true
            spacing: 8

        Rectangle {
            id: segments
            readonly property real segmentWidth: (width - 8) / library.views.length
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 11
            color: Qt.alpha(Theme.foreground, 0.035)
            border.width: 1
            border.color: Qt.alpha(Theme.foreground, 0.07)

            Rectangle {
                y: 4
                x: 4 + Math.max(0, library.views.map(v => v.id).indexOf(library.view)) * segments.segmentWidth
                width: segments.segmentWidth
                height: parent.height - 8
                radius: 8
                color: Qt.alpha(Theme.accent, 0.2)
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.45)
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            Row {
                x: 4
                y: 4
                Repeater {
                    model: library.views
                    delegate: Item {
                        id: segment
                        readonly property bool selected: library.view === modelData.id
                        width: segments.segmentWidth
                        height: segments.height - 8
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                font.family: Theme.iconFont
                                font.pixelSize: 14
                                color: segment.selected ? Theme.accent : Theme.muted
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.id === "songs" ? library.filteredTracks.length : modelData.id === "artists" ? library.artistGroups.length : library.albumGroups.length
                                font.pixelSize: 11
                                font.weight: segment.selected ? Font.Bold : Font.Medium
                                color: segment.selected ? Theme.foreground : Theme.muted
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: library.view = modelData.id
                        }
                    }
                }
            }
        }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            HubList {
                anchors.fill: parent
                visible: library.drillKind !== ""
                rowSpacing: 2
                model: library.drillTracks
                emptyGlyph: "󰎈"
                emptyTitle: ""
                rowDelegate: TrackRow {
                    track: modelData
                    showCover: library.drillKind !== "album"
                    current: modelData.path === library.currentPath
                    playing: library.currentPlaying
                    subtitle: library.drillKind === "album" ? (modelData.artist || "") : [modelData.artist, library.albumOf(modelData)].filter(s => !!s).join("  ·  ")
                    onActivated: library.playFrom(modelData, library.drillTracks)
                }
            }

            HubList {
                anchors.fill: parent
                visible: library.drillKind === "" && library.view === "songs"
                rowSpacing: 2
                model: library.filteredTracks
                busy: library.loading && !library.loaded
                emptyGlyph: "󰎈"
                emptyTitle: ""
                emptyHint: ""
                rowDelegate: TrackRow {
                    track: modelData
                    current: modelData.path === library.currentPath
                    playing: library.currentPlaying
                    subtitle: [modelData.artist, library.albumOf(modelData)].filter(s => !!s).join("  ·  ")
                    onActivated: library.playFrom(modelData, library.filteredTracks)
                }
            }

            HubList {
                anchors.fill: parent
                visible: library.drillKind === "" && library.view === "artists"
                rowSpacing: 2
                model: library.artistGroups
                emptyGlyph: "󰠃"
                emptyTitle: ""
                rowDelegate: Rectangle {
                    id: artistRow
                    width: ListView.view ? ListView.view.width : 0
                    height: 56
                    radius: 12
                    color: artistMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        spacing: 12

                        Cover {
                            size: 42
                            radius: 21
                            source: modelData.cover
                            fallback: "󰠃"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.foreground
                                elide: Text.ElideRight
                            }
                            Row {
                                spacing: 4
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰎈"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 11
                                    color: Theme.dim
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.count
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }
                            }
                        }

                        Text {
                            text: "󰅂"
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: artistMouse.containsMouse ? Theme.accent : Theme.dim
                        }
                    }

                    MouseArea {
                        id: artistMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: library.openDrill("artist", modelData.name)
                    }
                }
            }

            GridView {
                id: albumGrid
                anchors.fill: parent
                visible: library.drillKind === "" && library.view === "albums"
                clip: true
                model: library.albumGroups
                cellWidth: Math.floor(width / 2)
                cellHeight: cellWidth + 46
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: HubScrollBar {}

                delegate: Item {
                    id: albumCell
                    width: albumGrid.cellWidth
                    height: albumGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 14
                        color: albumMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.06) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 6

                            Item {
                                width: parent.width
                                height: width

                                Cover {
                                    anchors.fill: parent
                                    size: parent.width
                                    radius: 12
                                    source: modelData.cover
                                    fallback: "󰀥"
                                    scale: albumMouse.containsMouse ? 1.03 : 1
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 8
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: Theme.accent
                                    opacity: albumMouse.containsMouse ? 1 : 0
                                    scale: albumMouse.containsMouse ? 1 : 0.8
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Text {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: 1
                                        text: "󰐊"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 18
                                        color: "#221c21"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: library.playList(library.filteredTracks.filter(t => library.albumOf(t) === modelData.name).sort((a, b) => (a.track || 999) - (b.track || 999)))
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.name
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.foreground
                                elide: Text.ElideRight
                            }

                            Row {
                                width: parent.width
                                spacing: 4
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰎈"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 10
                                    color: Theme.dim
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.count
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.muted
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: modelData.artist !== "" && modelData.artist !== "Various artists"
                                    width: Math.min(implicitWidth, parent.width - 40)
                                    text: "  " + modelData.artist
                                    font.pixelSize: 10
                                    color: Theme.muted
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: albumMouse
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: library.openDrill("album", modelData.name)
                    }
                }
            }
        }
    }

    Item {
        id: miniPlayer
        readonly property bool live: !!library.player && library.player.available
        readonly property real progress: live && library.player.length > 0 ? Math.min(1, library.player.position / library.player.length) : 0
        visible: live
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        height: 60

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.bottomMargin: -8
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            radius: 18
            color: "#60000000"
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: 16
            color: "#ee221c21"
            border.width: 1
            border.color: Qt.alpha(Theme.foreground, 0.1)

            Image {
                id: miniBackdrop
                anchors.fill: parent
                source: miniPlayer.live ? library.player.trackArtUrl : ""
                sourceSize.width: 160
                sourceSize.height: 160
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: miniBackdrop
                blurEnabled: true
                blur: 1
                blurMax: 64
                brightness: -0.35
                saturation: 0.3
                opacity: miniBackdrop.status === Image.Ready ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }

            Rectangle {
                anchors.fill: parent
                color: miniMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.04) : "transparent"
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 5
                height: 2
                radius: 1
                color: Qt.alpha(Theme.foreground, 0.12)

                Rectangle {
                    width: parent.width * miniPlayer.progress
                    height: parent.height
                    radius: 1
                    color: Theme.foreground
                    Behavior on width { NumberAnimation { duration: 450 } }
                }
            }
        }

        MouseArea {
            id: miniMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: library.closeRequested()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 18
            anchors.bottomMargin: 4
            spacing: 12

            Cover {
                size: 42
                radius: 9
                source: miniPlayer.live ? library.player.trackArtUrl : ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: miniPlayer.live ? library.player.trackTitle : ""
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: "#e6d7dc"
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: miniPlayer.live ? library.player.trackArtist : ""
                    font.pixelSize: 11
                    color: "#d69aac"
                    elide: Text.ElideRight
                }
            }

            GlyphButton {
                text: library.currentPlaying ? "󰏤" : "󰐊"
                font.pixelSize: 26
                onClicked: library.player.togglePlaying()
            }

            GlyphButton {
                text: "󰒭"
                font.pixelSize: 22
                onClicked: library.player.next()
            }
        }
    }
}
