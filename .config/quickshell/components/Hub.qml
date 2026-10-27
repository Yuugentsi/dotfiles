import "../controls"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root
    signal backRequested
    signal panelRequested(string panel)
    function space(value) {
        return value;
    }
    IpcHandler {
        target: "hub"
        function toggle(): void {
            root.toggle();
        }
        function open(section: string): void {
            root.open(JSON.stringify({
                section: section
            }));
        }
        function close(): void {
            root.dismiss();
        }
    }
    property var shell: null
    property var manifest: null
    property bool opened: false
    property var bots: []
    property string section: "fish"
    function backendFor(sectionName) {
        return Quickshell.env("HOME") + "/.config/quickshell/scripts/" + (sectionName === "fish" ? "fish.py" : "bots.py");
    }
    function refresh() {
        if (section === "ytdlp" || section === "nyaa")
            return;
        if (query.running)
            return;
        query.requestedSection = section;
        query.running = true;
    }
    function selectSection(name) {
        if (section === name)
            return;
        section = name;
        bots = [];
        botSignature = "";
        logView = "";
        contentScroll.contentY = 0;
        refresh();
        if (section === "nyaa")
            Qt.callLater(function () {
                nyaaView.focusSearch();
            });
        if (section === "ytdlp")
            Qt.callLater(function () {
                downloadsView.focusUrl();
            });
    }
    property string logView: ""
    property string logFilter: "all"
    property var logData: ({
            entries: [],
            counts: {}
        })
    property string logSignature: ""
    readonly property var visibleLogs: logData.entries.filter(function (entry) {
        return (root.logFilter === "all" || entry.kind === root.logFilter) && (!logSearch.text || (entry.title + " " + entry.detail + " " + entry.label).toLowerCase().indexOf(logSearch.text.toLowerCase()) >= 0);
    })
    function showLogs(name) {
        logView = name;
        logFilter = "all";
        logData = {
            entries: [],
            counts: {}
        };
        logSignature = "";
        logList.positionViewAtBeginning();
        logSearch.text = "";
        if (!logQuery.running)
            logQuery.running = true;
    }
    function logColor(kind) {
        return kind === "error" ? "#bf616a" : kind === "downloaded" ? "#a3be8c" : kind === "skipped" ? "#aaa6b5" : kind === "warning" ? "#ebcb8b" : "#aaa6b5";
    }
    readonly property string script: backendFor(section)
    function open(payloadJson) {
        try {
            var payload = JSON.parse(payloadJson || "{}");
            if (payload.section === "bots" || payload.section === "fish" || payload.section === "ytdlp" || payload.section === "nyaa")
                selectSection(payload.section);
        } catch (e) {}
        opened = true;
        root.refresh();
        if (logView && !logQuery.running)
            logQuery.running = true;
        Qt.callLater(function () {
            if (root.section === "ytdlp")
                downloadsView.focusUrl();
            else if (root.section === "nyaa")
                nyaaView.focusSearch();
            else
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
    Process {
        id: action
        onExited: {
            root.refresh();
        }
    }
    Process {
        id: logQuery
        command: ["python3", root.script, root.section === "bots" ? "activity" : "logs", root.logView]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    if (data.name === root.logView && text !== root.logSignature) {
                        root.logSignature = text;
                        root.logData = data;
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: query
        property string requestedSection: "fish"
        command: ["python3", root.backendFor(requestedSection), "list"]
        onExited: if (requestedSection !== root.section)
            Qt.callLater(function () {
                root.refresh();
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (query.requestedSection === root.section && text !== root.botSignature) {
                        root.botSignature = text;
                        root.bots = JSON.parse(text);
                    }
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 1000
        running: root.opened && root.section !== "ytdlp" && root.section !== "nyaa"
        repeat: true
        onTriggered: {
            root.refresh();
            if (root.logView && !logQuery.running && !clearAction.running)
                logQuery.running = true;
        }
    }

    property string botSignature: ""
    readonly property color ink: "#eef3f8"
    readonly property color muted: "#aaa6b5"
    readonly property color mint: "#c3b7ff"
    readonly property int activeCount: bots.filter(function (bot) {
        return bot.running;
    }).length
    readonly property int transferCount: bots.reduce(function (total, bot) {
        return total + (bot.downloads || []).length;
    }, 0)
    readonly property int queueCount: bots.reduce(function (total, bot) {
        return total + (bot.queued || 0);
    }, 0)
    function activate(bot) {
        if (action.running)
            return;
        action.command = ["python3", script, bot.running ? "stop" : "start", bot.name];
        action.running = true;
    }
    Process {
        id: clearAction
        command: ["python3", root.script, "clear-logs", root.logView]
        onExited: function (code) {
            if (code === 0) {
                root.logSignature = "";
                root.logData = {
                    entries: [],
                    counts: {}
                };
                if (!logQuery.running)
                    logQuery.running = true;
            }
        }
    }
    PanelWindow {
        id: panel
        Shortcut {
            sequence: "B"
            context: Qt.WindowShortcut
            enabled: root.opened && root.section !== "nyaa" && root.section !== "ytdlp"
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
            onSelected: function (panel) {
                root.panelRequested(panel);
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
            color: "#ac080e16"
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.max(0, Math.min(root.section === "ytdlp" ? 660 : root.section === "nyaa" ? 560 : 440, panel.width - 32))
            height: Math.max(0, Math.min(panel.height - 112, root.logView ? 490 : 148 + (root.section === "ytdlp" ? downloadsView.implicitHeight : root.section === "nyaa" ? Math.min(520, nyaaView.implicitHeight) : homeContent.implicitHeight)))
            radius: root.section === "nyaa" || root.section === "ytdlp" ? 20 : 14
            color: "#14111b"
            gradient: root.section === "nyaa" || root.section === "ytdlp" ? musicGradient : null
            Gradient {
                id: musicGradient
                GradientStop {
                    position: 0
                    color: "#211728"
                }
                GradientStop {
                    position: 1
                    color: "#100d18"
                }
            }
            border.width: 1
            border.color: root.section === "nyaa" ? "#67477c" : "#66517c"
            Rectangle {
                visible: root.section !== "nyaa" && root.section !== "ytdlp"
                anchors.fill: parent
                anchors.margins: -3
                radius: 17
                color: "transparent"
                border.width: 1
                border.color: "#20c3b7ff"
            }
            Item {
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                Repeater {
                    model: root.section === "nyaa" || root.section === "ytdlp" ? 0 : Math.max(0, Math.floor(card.height / 28))
                    Rectangle {
                        required property int index
                        y: index * 28
                        width: parent.width
                        height: 1
                        color: "#04c3b7ff"
                    }
                }
            }
            NeonCorner {
                visible: root.section !== "nyaa" && root.section !== "ytdlp"
                x: 8
                y: 8
            }
            NeonCorner {
                visible: root.section !== "nyaa" && root.section !== "ytdlp"
                x: parent.width - width - 8
                y: 8
                rotation: 90
            }
            NeonCorner {
                visible: root.section !== "nyaa" && root.section !== "ytdlp"
                x: parent.width - width - 8
                y: parent.height - height - 8
                rotation: 180
            }
            NeonCorner {
                visible: root.section !== "nyaa" && root.section !== "ytdlp"
                x: 8
                y: parent.height - height - 8
                rotation: 270
            }
            focus: true
            Keys.onEscapePressed: {
                if (root.logView)
                    root.logView = "";
                else
                    root.dismiss();
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            Item {
                id: header
                x: 20
                y: 18
                width: parent.width - 40
                height: 44
                Rectangle {
                    width: 40
                    height: 40
                    radius: 9
                    color: "#292038"
                    border.width: 1
                    border.color: "#a28bdb"
                    Caption {
                        contextRoot: root
                        anchors.centerIn: parent
                        text: root.logView ? "\uf03a" : "\uf1b3"
                        color: root.mint
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 18
                    }
                }
                Caption {
                    contextRoot: root
                    x: 52
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - headerActions.width - 12
                    text: root.logView || (root.section === "nyaa" ? "Nyaa" : "HUB")
                    color: root.ink
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    font.family: root.section === "nyaa" ? "sans-serif" : "monospace"
                    font.letterSpacing: root.section === "nyaa" ? -0.6 : 1.5
                    elide: Text.ElideRight
                }
                Row {
                    id: headerActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    IconAction {
                        contextRoot: root
                        visible: !!root.logView
                        glyph: "\uf104"
                        onClicked: root.logView = ""
                    }
                    IconAction {
                        contextRoot: root
                        visible: !!root.logView && root.section !== "bots"
                        glyph: "\uf1f8"
                        tint: "#f38b92"
                        enabled: !clearAction.running && !logQuery.running && root.logData.entries.length > 0
                        onClicked: clearAction.running = true
                    }
                    IconAction {
                        contextRoot: root
                        glyph: "\uf00d"
                        onClicked: root.dismiss()
                    }
                }
            }
            Rectangle {
                id: sections
                x: 20
                y: 78
                width: parent.width - 40
                height: 36
                radius: 8
                color: "#0e0c13"
                border.width: 1
                border.color: "#30243e"
                Rectangle {
                    x: 3 + (root.section === "bots" ? 1 : root.section === "ytdlp" ? 2 : root.section === "nyaa" ? 3 : 0) * (sections.width - 3) / 4
                    y: 3
                    width: (sections.width - 15) / 4
                    height: 30
                    radius: 6
                    color: "#332440"
                    border.width: 1
                    border.color: "#9b80ca"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.35
                        height: 2
                        color: "#c3b7ff"
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: 170
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3
                    Repeater {
                        model: [
                            {
                                key: "fish",
                                label: "Watchers"
                            },
                            {
                                key: "bots",
                                label: "Bots"
                            },
                            {
                                key: "ytdlp",
                                label: "Downloads"
                            },
                            {
                                key: "nyaa",
                                label: "Nyaa"
                            }
                        ]
                        Rectangle {
                            id: sectionButton
                            required property var modelData
                            readonly property bool selected: root.section === modelData.key
                            objectName: "hub-section-" + modelData.key
                            width: (sections.width - 15) / 4
                            height: 30
                            radius: 6
                            color: !selected && sectionHit.containsMouse ? "#29252f" : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            activeFocusOnTab: true
                            function choose() {
                                root.logView = "";
                                root.selectSection(modelData.key);
                            }
                            Keys.onReturnPressed: choose()
                            Keys.onSpacePressed: choose()
                            Caption {
                                contextRoot: root
                                anchors.centerIn: parent
                                text: sectionButton.modelData.label
                                color: sectionButton.selected ? "#d8caff" : "#aaa6b5"
                                font.pixelSize: 11
                                font.weight: sectionButton.selected ? Font.DemiBold : Font.Normal
                            }
                            Timer {
                                interval: 180
                                running: root.opened && sectionHit.containsMouse && (!sectionButton.selected || !!root.logView)
                                onTriggered: sectionButton.choose()
                            }
                            MouseArea {
                                id: sectionHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sectionButton.choose()
                            }
                        }
                    }
                }
            }
            Item {
                anchors.top: sections.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 14
                anchors.bottomMargin: 20
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                Flickable {
                    id: contentScroll
                    anchors.fill: parent
                    visible: !root.logView && root.section !== "ytdlp" && root.section !== "nyaa"
                    contentHeight: homeContent.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    Column {
                        id: homeContent
                        width: parent.width
                        spacing: root.space(14)
                        Column {
                            width: parent.width
                            spacing: root.space(10)
                            Repeater {
                                model: root.bots
                                ServiceCard {
                                    contextAction: action
                                    contextRoot: root
                                    required property var modelData
                                    bot: modelData
                                    width: homeContent.width
                                }
                            }
                        }
                        Caption {
                            contextRoot: root
                            visible: !root.bots.length
                            text: query.running ? "Loading…" : root.section === "fish" ? "No watchers available" : "No bots found"
                        }
                    }
                }
                Flickable {
                    anchors.fill: parent
                    visible: root.section === "ytdlp" && !root.logView
                    contentHeight: downloadsView.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    YtdlpView {
                        id: downloadsView
                        width: parent.width
                    }
                }
                Flickable {
                    anchors.fill: parent
                    visible: root.section === "nyaa" && !root.logView
                    contentHeight: nyaaView.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    NyaaView {
                        id: nyaaView
                        width: parent.width
                    }
                }
                Column {
                    id: activityContent
                    anchors.fill: parent
                    visible: !!root.logView
                    spacing: root.space(12)
                    Rectangle {
                        width: parent.width
                        height: root.space(36)
                        radius: root.space(4)
                        color: "#18181d"
                        border.width: 1
                        border.color: logSearch.activeFocus ? "#c3b7ff" : "#37343f"
                        Caption {
                            contextRoot: root
                            x: root.space(14)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf002"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: root.space(12)
                        }
                        TextInput {
                            id: logSearch
                            x: root.space(38)
                            width: parent.width - x - root.space(14)
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.ink
                            selectionColor: "#383044"
                            selectedTextColor: root.ink
                            font.family: "sans-serif"
                            font.pixelSize: root.space(11)
                            clip: true
                            selectByMouse: true
                            onTextChanged: logList.positionViewAtBeginning()
                            Caption {
                                contextRoot: root
                                visible: !logSearch.text && !logSearch.activeFocus
                                text: "Search"
                                font.pixelSize: root.space(11)
                            }
                        }
                    }
                    Flow {
                        id: filters
                        width: parent.width
                        spacing: root.space(6)
                        Repeater {
                            model: root.section === "bots" ? [
                                {
                                    key: "all",
                                    label: "All"
                                },
                                {
                                    key: "info",
                                    label: "Info"
                                },
                                {
                                    key: "warning",
                                    label: "Warnings"
                                },
                                {
                                    key: "error",
                                    label: "Errors"
                                }
                            ] : [
                                {
                                    key: "all",
                                    label: "All events"
                                },
                                {
                                    key: "downloaded",
                                    label: "Downloaded"
                                },
                                {
                                    key: "skipped",
                                    label: "Already downloaded"
                                },
                                {
                                    key: "error",
                                    label: "Failed"
                                }
                            ]
                            Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool selected: root.logFilter === modelData.key
                                readonly property color tint: modelData.key === "all" ? root.mint : root.logColor(modelData.key)
                                width: filterLabel.implicitWidth + root.space(22)
                                height: root.space(28)
                                radius: root.space(4)
                                color: selected ? Qt.rgba(tint.r, tint.g, tint.b, 0.13) : "transparent"
                                border.width: 1
                                border.color: selected ? Qt.rgba(tint.r, tint.g, tint.b, 0.32) : "#37343f"
                                activeFocusOnTab: true
                                function choose() {
                                    root.logFilter = modelData.key;
                                    logList.positionViewAtBeginning();
                                }
                                Keys.onReturnPressed: choose()
                                Caption {
                                    id: filterLabel
                                    contextRoot: root
                                    anchors.centerIn: parent
                                    text: chip.modelData.label
                                    color: chip.selected ? chip.tint : root.muted
                                    font.pixelSize: root.space(9)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: chip.choose()
                                }
                            }
                        }
                    }
                    ListView {
                        id: logList
                        width: parent.width
                        height: Math.max(0, activityContent.height - y)
                        clip: true
                        spacing: root.space(7)
                        model: root.visibleLogs
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                        delegate: Rectangle {
                            id: eventRow
                            required property var modelData
                            readonly property color tint: root.logColor(modelData.kind)
                            width: logList.width
                            height: Math.max(root.space(70), eventText.implicitHeight + root.space(28))
                            radius: root.space(5)
                            color: "#222128"
                            border.width: 1
                            border.color: "#37343f"
                            Rectangle {
                                x: 0
                                y: root.space(18)
                                width: root.space(2)
                                height: parent.height - y * 2
                                radius: 1
                                color: eventRow.tint
                                opacity: 0.7
                            }
                            Rectangle {
                                x: root.space(14)
                                y: root.space(17)
                                width: root.space(28)
                                height: width
                                radius: width / 2
                                color: Qt.rgba(eventRow.tint.r, eventRow.tint.g, eventRow.tint.b, 0.09)
                                Caption {
                                    contextRoot: root
                                    anchors.centerIn: parent
                                    color: eventRow.tint
                                    text: eventRow.modelData.kind === "error" ? "!" : eventRow.modelData.kind === "downloaded" ? "✓" : eventRow.modelData.kind === "skipped" ? "↻" : "·"
                                    font.pixelSize: root.space(14)
                                }
                            }
                            Column {
                                id: eventText
                                x: root.space(54)
                                y: root.space(14)
                                width: parent.width - x - root.space(16)
                                spacing: root.space(5)
                                Caption {
                                    contextRoot: root
                                    text: eventRow.modelData.label
                                    color: eventRow.tint
                                    font.pixelSize: root.space(8)
                                    font.letterSpacing: 0.6
                                    font.weight: Font.Bold
                                }
                                Caption {
                                    contextRoot: root
                                    width: parent.width
                                    text: eventRow.modelData.title
                                    color: root.ink
                                    font.pixelSize: root.space(11)
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                }
                                Caption {
                                    contextRoot: root
                                    width: parent.width
                                    visible: !!eventRow.modelData.detail
                                    text: eventRow.modelData.detail
                                    font.pixelSize: root.space(10)
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                        Column {
                            visible: logList.count === 0
                            anchors.centerIn: parent
                            spacing: root.space(12)
                            Caption {
                                contextRoot: root
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "≋"
                                color: root.mint
                                font.pixelSize: root.space(38)
                            }
                            Caption {
                                contextRoot: root
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: logQuery.running ? "Loading…" : logSearch.text ? "No matching events" : "No activity"
                                color: root.ink
                                font.pixelSize: root.space(15)
                            }
                        }
                    }
                }
            }
        }
    }

    component NeonCorner: Item {

        width: 10
        height: 10
        Rectangle {
            width: 10
            height: 1
            color: "#c3b7ff"
        }
        Rectangle {
            width: 1
            height: 10
            color: "#c3b7ff"
        }
    }

    component Caption: Text {
        id: captionOwnerContext

        required property var contextRoot
        color: contextRoot.muted
        font.family: "sans-serif"
        font.pixelSize: contextRoot.space(11)
        textFormat: Text.PlainText
    }

    component IconAction: Rectangle {
        id: iconActionIconButton
        required property var contextRoot
        property string glyph: ""
        property color tint: contextRoot.muted
        property bool quiet: false
        signal clicked
        width: contextRoot.space(34)
        height: width
        radius: width / 2
        activeFocusOnTab: true
        color: iconActionIconHit.containsMouse || activeFocus ? Qt.rgba(tint.r, tint.g, tint.b, 0.12) : quiet ? "transparent" : "#342b3e"
        opacity: enabled ? 1 : 0.3
        scale: iconActionIconHit.pressed ? 0.92 : 1
        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Caption {
            contextRoot: iconActionIconButton.contextRoot
            anchors.centerIn: parent
            text: iconActionIconButton.glyph
            color: iconActionIconButton.tint
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: contextRoot.space(13)
        }
        MouseArea {
            id: iconActionIconHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconActionIconButton.clicked()
        }
    }

    component ServiceCard: Rectangle {
        id: serviceCardService
        required property var contextAction
        required property var contextRoot
        required property var bot
        objectName: "hub-service-" + bot.name
        readonly property var downloads: bot.downloads || []
        readonly property bool hasTransfers: bot.running && (downloads.length > 0 || (bot.queued || 0) > 0)
        width: parent.width
        height: 72 + (serviceCardBotPreview.visible ? serviceCardBotPreview.height + 12 : 0) + (hasTransfers ? serviceCardTransferDetails.implicitHeight + 12 : 0)
        radius: 10
        color: bot.running ? "#21182d" : "#1a1521"
        border.width: 1
        border.color: bot.running ? "#70518b" : "#35283f"
        Rectangle {
            x: 0
            y: 19
            width: 2
            height: 32
            radius: 1
            color: contextRoot.mint
            visible: !!serviceCardService.bot.running
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 0
            width: 25
            height: 1
            color: "#c3b7ff"
            visible: !!serviceCardService.bot.running
        }
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Rectangle {
            x: 12
            y: 16
            width: 38
            height: 38
            radius: 8
            color: serviceCardService.bot.running ? "#382547" : "#27202f"
            border.width: 1
            border.color: serviceCardService.bot.running ? "#765497" : "#3b2e49"
            Caption {
                contextRoot: serviceCardService.contextRoot
                anchors.centerIn: parent
                text: contextRoot.section === "bots" ? "\uf121" : serviceCardService.bot.name === "MP3" ? "\uf001" : "\uf16a"
                color: serviceCardService.bot.running ? contextRoot.mint : "#a297ac"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 17
            }
        }
        Caption {
            contextRoot: serviceCardService.contextRoot
            x: 62
            y: serviceCardService.bot.running ? 17 : 27
            width: parent.width - x - 94
            text: serviceCardService.bot.name
            elide: Text.ElideRight
            color: contextRoot.ink
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Rectangle {
            x: 62
            y: 43
            width: 4
            height: 4
            radius: 2
            visible: !!serviceCardService.bot.running
            color: serviceCardService.bot.running ? contextRoot.mint : "#716777"
        }
        Caption {
            contextRoot: serviceCardService.contextRoot
            x: 72
            y: 39
            width: parent.width - x - 94
            visible: !!serviceCardService.bot.running
            text: serviceCardService.downloads.length ? "Downloading" : contextRoot.section === "bots" ? "Running" : "Listening"
            color: serviceCardService.bot.running ? contextRoot.mint : "#928b96"
            font.pixelSize: 10
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 19
            spacing: 7
            IconAction {
                contextRoot: serviceCardService.contextRoot
                quiet: true
                objectName: "hub-logs-" + serviceCardService.bot.name
                glyph: "\uf03a"
                onClicked: contextRoot.showLogs(serviceCardService.bot.name)
            }
            ToggleSwitch {
                objectName: "hub-toggle-" + serviceCardService.bot.name
                anchors.verticalCenter: parent.verticalCenter
                checked: !!serviceCardService.bot.running
                enabled: !contextAction.running
                opacity: enabled ? 1 : 0.4
                activeFocusOnTab: true
                Accessible.role: Accessible.CheckBox
                Accessible.name: serviceCardService.bot.name
                Accessible.checked: checked
                Keys.onReturnPressed: contextRoot.activate(serviceCardService.bot)
                Keys.onSpacePressed: contextRoot.activate(serviceCardService.bot)
                onToggled: contextRoot.activate(serviceCardService.bot)
            }
        }
        Caption {
            contextRoot: serviceCardService.contextRoot
            objectName: "hub-memory-" + serviceCardService.bot.name
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 56
            visible: !!serviceCardService.bot.running && !!serviceCardService.bot.memory
            text: serviceCardService.bot.memory || ""
            color: "#b9a2d4"
            font.family: "monospace"
            font.pixelSize: 9
        }
        Rectangle {
            id: serviceCardBotPreview
            objectName: "hub-preview-" + serviceCardService.bot.name
            x: 12
            y: 72
            width: parent.width - 24
            height: serviceCardLatestMessage.implicitHeight + 20
            visible: contextRoot.section === "bots" && !!serviceCardService.bot.last_log
            radius: 6
            color: "#100c17"
            border.width: 1
            border.color: "#3c294e"
            Rectangle {
                x: 0
                y: 8
                width: 2
                height: parent.height - 16
                color: "#8f70bf"
            }
            Caption {
                id: serviceCardLatestMessage
                contextRoot: serviceCardService.contextRoot
                x: 10
                y: 10
                width: parent.width - 20
                text: serviceCardService.bot.last_log || ""
                font.family: "monospace"
                font.pixelSize: 10
                color: "#bcb1ca"
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: contextRoot.showLogs(serviceCardService.bot.name)
            }
        }
        Column {
            id: serviceCardTransferDetails
            x: 12
            y: serviceCardBotPreview.visible ? serviceCardBotPreview.y + serviceCardBotPreview.height + 12 : 72
            width: parent.width - 24
            visible: serviceCardService.hasTransfers
            spacing: 8
            Repeater {
                model: serviceCardService.downloads
                Column {
                    id: serviceCardTransfer
                    required property var modelData
                    width: serviceCardTransferDetails.width
                    spacing: 8
                    Row {
                        width: parent.width
                        spacing: 8
                        Caption {
                            contextRoot: serviceCardService.contextRoot
                            width: parent.width - serviceCardProgressValue.width - 8
                            text: serviceCardTransfer.modelData.title
                            color: contextRoot.ink
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Caption {
                            id: serviceCardProgressValue
                            contextRoot: serviceCardService.contextRoot
                            text: serviceCardTransfer.modelData.percent === null ? "…" : Math.round(serviceCardTransfer.modelData.percent) + "%"
                            color: contextRoot.mint
                            font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 3
                        radius: 2
                        color: "#44384f"
                        clip: true
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, serviceCardTransfer.modelData.percent === null ? 15 : serviceCardTransfer.modelData.percent)) / 100
                            height: parent.height
                            radius: 2
                            color: contextRoot.mint
                            Behavior on width {
                                NumberAnimation {
                                    duration: 350
                                }
                            }
                        }
                    }
                    Caption {
                        contextRoot: serviceCardService.contextRoot
                        width: parent.width
                        text: serviceCardTransfer.modelData.phase + (serviceCardTransfer.modelData.details ? " · " + serviceCardTransfer.modelData.details : "")
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }
            }
            Caption {
                contextRoot: serviceCardService.contextRoot
                visible: (serviceCardService.bot.queued || 0) > 0
                text: serviceCardService.bot.queued + " queued"
                font.pixelSize: 9
            }
        }
    }

    component NyaaActionButton: Rectangle {
        id: nyaaActionButtonButton
        property string label: ""
        signal clicked
        width: nyaaActionButtonButtonText.implicitWidth + 24
        height: 36
        radius: 11
        color: nyaaActionButtonHit.containsMouse || activeFocus ? "#5b3e70" : "#45304f"
        border.width: 1
        border.color: "#80608e"
        scale: nyaaActionButtonHit.pressed ? 0.94 : 1
        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
        Accessible.role: Accessible.Button
        Accessible.name: label
        opacity: enabled ? 1 : 0.4
        activeFocusOnTab: true
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            id: nyaaActionButtonButtonText
            anchors.centerIn: parent
            text: nyaaActionButtonButton.label
            color: "#f0dfff"
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: nyaaActionButtonHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nyaaActionButtonButton.clicked()
        }
    }

    component NyaaView: Column {
        id: nyaaViewRoot
        spacing: 14
        property var results: []
        property string selectedRelease: ""
        function releaseKey(item) {
            return JSON.stringify([item.series, item.group]);
        }
        readonly property var releaseGroups: {
            var groups = [];
            var seen = {};
            results.forEach(function (item) {
                var key = nyaaViewRoot.releaseKey(item);
                if (seen[key] === undefined) {
                    seen[key] = groups.length;
                    groups.push({
                        key: key,
                        series: item.series,
                        group: item.group,
                        count: 0,
                        episodes: {},
                        episodeCount: 0
                    });
                }
                groups[seen[key]].count++;
                if (item.episode) {
                    var episode = String(Number(item.episode));
                    if (!groups[seen[key]].episodes[episode]) {
                        groups[seen[key]].episodes[episode] = true;
                        groups[seen[key]].episodeCount++;
                    }
                }
            });
            return groups.sort(function (a, b) {
                return b.episodeCount - a.episodeCount || b.count - a.count || a.series.localeCompare(b.series) || a.group.localeCompare(b.group);
            });
        }
        readonly property var visibleResults: selectedRelease ? results.filter(function (item) {
            return nyaaViewRoot.releaseKey(item) === nyaaViewRoot.selectedRelease;
        }) : []
        property string message: ""
        property string transferTitle: ""
        property string activeMagnet: ""
        property var downloadQueue: []
        function isQueued(item) {
            return downloadQueue.some(function (entry) {
                return entry.magnet === item.magnet;
            });
        }
        property string transferStatus: ""
        property string logPath: ""
        property string logText: ""
        property real progress: 0
        property bool logsVisible: false
        property bool failed: false
        readonly property string backend: Quickshell.env("HOME") + "/.config/quickshell/scripts/nyaa.py"
        function focusSearch() {
            nyaaViewSearchInput.forceActiveFocus();
        }
        function search() {
            if (nyaaViewLookup.running || !nyaaViewSearchInput.text.trim())
                return;
            results = [];
            selectedRelease = "";
            failed = false;
            message = "Searching Nyaa.si…";
            nyaaViewLookup.command = ["python3", nyaaViewRoot.backend, nyaaViewSearchInput.text.trim()];
            nyaaViewLookup.running = true;
        }
        function startTransfer(item) {
            if (activeMagnet === item.magnet || isQueued(item))
                return;
            downloadQueue = downloadQueue.concat([item]);
            startNextTransfer();
        }
        function startNextTransfer() {
            if (nyaaViewDownload.running || activeMagnet || !downloadQueue.length)
                return;
            var item = downloadQueue[0];
            downloadQueue = downloadQueue.slice(1);
            activeMagnet = item.magnet;
            transferTitle = item.title;
            transferStatus = "Connecting to peers · waiting for metadata";
            logText = "";
            logPath = "";
            progress = 0;
            nyaaViewDownload.command = ["python3", "-u", nyaaViewRoot.backend, "--download", item.magnet];
            nyaaViewDownload.running = true;
        }
        Process {
            id: nyaaViewLookup
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var response = JSON.parse(text);
                        nyaaViewRoot.results = response.results || [];
                        nyaaViewRoot.selectedRelease = "";
                        if (response.limited)
                            nyaaViewRoot.message = "Showing the first 10 pages. Narrow your search for more results.";
                        nyaaViewRoot.failed = !!response.error;
                        nyaaViewRoot.message = response.error || (nyaaViewRoot.results.length ? nyaaViewRoot.results.length + " releases · grouped by title · episode order" + (response.limited ? " · first 10 pages" : "") : "No matching releases. Try another title.");
                    } catch (error) {
                        nyaaViewRoot.failed = true;
                        nyaaViewRoot.message = "Unable to read search response";
                    }
                }
            }
        }
        Process {
            id: nyaaViewDownload
            stdout: SplitParser {
                onRead: function (data) {
                    try {
                        var entry = JSON.parse(data);
                        if (entry.log)
                            nyaaViewRoot.logPath = entry.log;
                        var line = entry.line || entry.error || "";
                        if (!line)
                            return;
                        nyaaViewRoot.logText = (nyaaViewRoot.logText + line + "\n").slice(-24000);
                        nyaaViewRoot.transferStatus = line;
                        var match = line.match(/\((\d+)%\)/);
                        if (match)
                            nyaaViewRoot.progress = Number(match[1]) / 100;
                    } catch (error) {}
                }
            }
            onExited: function (code) {
                nyaaViewRoot.transferStatus = code === 0 ? "Download complete" : "Download failed · exit code " + code + " · see logs";
                if (code === 0)
                    nyaaViewRoot.progress = 1;
                nyaaViewRoot.activeMagnet = "";
                Qt.callLater(function () {
                    nyaaViewRoot.startNextTransfer();
                });
            }
        }
        Item {
            width: parent.width
            height: 46
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                Text {
                    text: String(nyaaViewRoot.releaseGroups.length).padStart(2, "0")
                    color: "#f3eaff"
                    font.pixelSize: 32
                    font.weight: Font.Light
                    font.letterSpacing: -1
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        text: "TITLES"
                        color: "#aa91bd"
                        font.pixelSize: 9
                        font.letterSpacing: 2
                    }
                    Rectangle {
                        width: 24
                        height: 2
                        radius: 1
                        color: "#ff9c66"
                    }
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: nyaaViewRoot.results.length + " releases"
                color: "#aa91bd"
                font.pixelSize: 11
            }
        }
        Row {
            width: parent.width
            spacing: 8
            Rectangle {
                width: parent.width - nyaaViewSearchButton.width - 8
                height: 44
                radius: 9
                color: "#251b30"
                border.color: nyaaViewSearchInput.activeFocus ? "#80608e" : "#3b2b49"
                TextInput {
                    id: nyaaViewSearchInput
                    anchors.fill: parent
                    anchors.margins: 13
                    color: "#f3eaff"
                    font.pixelSize: 12
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    clip: true
                    onAccepted: nyaaViewRoot.search()
                    Text {
                        visible: !nyaaViewSearchInput.text
                        text: "[Erai-raws] Yani Neko"
                        color: "#9e83b0"
                        font: nyaaViewSearchInput.font
                    }
                }
            }
            NyaaActionButton {
                id: nyaaViewSearchButton
                label: nyaaViewLookup.running ? "Searching…" : "Search"
                enabled: !nyaaViewLookup.running && !!nyaaViewSearchInput.text.trim()
                onClicked: nyaaViewRoot.search()
            }
        }
        Text {
            visible: !!nyaaViewRoot.message && (nyaaViewRoot.failed || nyaaViewLookup.running || !nyaaViewRoot.results.length)
            width: parent.width
            text: nyaaViewRoot.message
            color: nyaaViewRoot.failed ? "#f38b92" : "#bba6ca"
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            font.pixelSize: 11
        }
        Rectangle {
            visible: !!nyaaViewRoot.transferTitle
            width: parent.width
            height: nyaaViewTransferContent.implicitHeight + 32
            radius: 18
            color: "#1f1729"
            border.color: "#3b2b49"
            Column {
                id: nyaaViewTransferContent
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 12
                Text {
                    text: nyaaViewDownload.running ? "ACTIVE TRANSFER" : "TRANSFER"
                    color: "#c3a0ff"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: nyaaViewRoot.transferTitle
                    color: "#f3eaff"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: "#393044"
                    Rectangle {
                        width: parent.width * nyaaViewRoot.progress
                        height: 4
                        radius: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: "#ff9c66"
                            }
                            GradientStop {
                                position: 0.5
                                color: "#cf8dbc"
                            }
                            GradientStop {
                                position: 1
                                color: "#c3a0ff"
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: nyaaViewRoot.transferStatus
                    color: "#b6a0c5"
                    font.family: "monospace"
                    font.pixelSize: 10
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
                Row {
                    spacing: 8
                    NyaaActionButton {
                        label: nyaaViewRoot.logsVisible ? "Hide logs" : "Show logs"
                        onClicked: nyaaViewRoot.logsVisible = !nyaaViewRoot.logsVisible
                    }
                    NyaaActionButton {
                        label: "Open log"
                        enabled: !!nyaaViewRoot.logPath
                        onClicked: Quickshell.execDetached(["xdg-open", nyaaViewRoot.logPath])
                    }
                }
                Rectangle {
                    visible: nyaaViewRoot.logsVisible
                    width: parent.width
                    height: 170
                    radius: 6
                    color: "#100d18"
                    Flickable {
                        id: nyaaViewLogScroll
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: width
                        contentHeight: nyaaViewLogOutput.height
                        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                        ScrollBar.vertical: ScrollBar {}
                        TextEdit {
                            id: nyaaViewLogOutput
                            width: nyaaViewLogScroll.width
                            height: implicitHeight
                            text: nyaaViewRoot.logText || "Waiting for aria2 output…"
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            color: "#b6a0c5"
                            font.family: "monospace"
                            font.pixelSize: 10
                            textFormat: TextEdit.PlainText
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            visible: nyaaViewRoot.downloadQueue.length > 0
            spacing: 8
            Text {
                text: "UP NEXT · " + nyaaViewRoot.downloadQueue.length + " queued"
                color: "#c3a0ff"
                font.pixelSize: 10
                font.bold: true
            }
            Repeater {
                model: nyaaViewRoot.downloadQueue
                Text {
                    required property var modelData
                    required property int index
                    width: nyaaViewRoot.width
                    text: (index + 1) + ". " + modelData.title
                    color: "#bba6ca"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
            }
        }
        Row {
            visible: !!nyaaViewRoot.selectedRelease
            spacing: 10
            NyaaActionButton {
                label: "‹ All titles"
                onClicked: nyaaViewRoot.selectedRelease = ""
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: nyaaViewRoot.visibleResults.length + " releases · episode order"
                color: "#bba6ca"
                font.pixelSize: 10
            }
        }
        Repeater {
            model: nyaaViewRoot.selectedRelease ? [] : nyaaViewRoot.releaseGroups
            Rectangle {
                id: nyaaViewGroupButton
                required property var modelData
                width: nyaaViewRoot.width
                height: Math.max(104, nyaaViewGroupContent.implicitHeight + 40)
                radius: 18
                color: nyaaViewGroupHit.containsMouse || activeFocus ? "#302338" : "#211a29"
                border.width: 1
                border.color: nyaaViewGroupHit.containsMouse || activeFocus ? "#9775ac" : "#3b2b49"
                Behavior on color {
                    ColorAnimation {
                        duration: 110
                    }
                }
                scale: nyaaViewGroupHit.pressed ? 0.985 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }
                activeFocusOnTab: true
                function choose() {
                    nyaaViewRoot.selectedRelease = modelData.key;
                }
                Keys.onReturnPressed: choose()
                Keys.onSpacePressed: choose()
                Rectangle {
                    x: 0
                    y: 22
                    width: 3
                    height: parent.height - 44
                    radius: 2
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#ff9c66"
                        }
                        GradientStop {
                            position: 1
                            color: "#c3a0ff"
                        }
                    }
                }
                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        anchors.right: parent.right
                        text: String(nyaaViewGroupButton.modelData.episodeCount).padStart(2, "0")
                        color: nyaaViewGroupHit.containsMouse ? "#ffb98f" : "#d9c2ed"
                        font.pixelSize: 38
                        font.weight: Font.Light
                        font.letterSpacing: -2
                    }
                    Text {
                        anchors.right: parent.right
                        text: "EPISODES"
                        color: "#aa91bd"
                        font.pixelSize: 8
                        font.letterSpacing: 1.2
                    }
                }
                Column {
                    id: nyaaViewGroupContent
                    x: 22
                    y: 20
                    width: parent.width - 132
                    spacing: 9
                    Text {
                        width: parent.width
                        text: nyaaViewGroupButton.modelData.series
                        color: "#f3eaff"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        font.letterSpacing: -0.4
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                    Text {
                        width: parent.width
                        text: nyaaViewGroupButton.modelData.group + " · " + nyaaViewGroupButton.modelData.count + " releases"
                        color: "#c3a0ff"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }
                MouseArea {
                    id: nyaaViewGroupHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nyaaViewGroupButton.choose()
                }
            }
        }
        Repeater {
            model: nyaaViewRoot.visibleResults
            SwipeDelegate {
                id: nyaaViewResultRow
                required property var modelData
                required property int index
                readonly property bool current: nyaaViewRoot.activeMagnet === modelData.magnet
                readonly property bool queued: nyaaViewRoot.isQueued(modelData)
                width: nyaaViewRoot.width
                height: nyaaViewDetails.implicitHeight + 28
                padding: 0
                hoverEnabled: true
                activeFocusOnTab: true
                Accessible.name: modelData.title
                Accessible.description: "Swipe left or press Enter to download or add to queue"
                function enqueue() {
                    if (!current && !queued)
                        nyaaViewRoot.startTransfer(modelData);
                }
                Keys.onReturnPressed: enqueue()
                Keys.onSpacePressed: enqueue()
                swipe.enabled: !current && !queued
                swipe.transition: Transition {
                    SmoothedAnimation {
                        velocity: 4
                        easing.type: Easing.OutCubic
                    }
                }
                swipe.onCompleted: {
                    enqueue();
                    Qt.callLater(function () {
                        nyaaViewResultRow.swipe.close();
                    });
                }
                swipe.right: Rectangle {
                    width: nyaaViewResultRow.width * 0.6
                    height: nyaaViewResultRow.height
                    anchors.right: parent.right
                    radius: 17
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "#493053"
                        }
                        GradientStop {
                            position: 1
                            color: "#80515b"
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf019"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 24
                            color: "#ffb98e"
                        }
                    }
                }
                background: Rectangle {
                    radius: 17
                    color: Math.abs(nyaaViewResultRow.swipe.position) > 0 ? "#45304f" : nyaaViewResultRow.current ? "#45304f" : nyaaViewResultRow.hovered || nyaaViewResultRow.activeFocus ? "#302039" : "#251b30"
                    border.width: 1
                    border.color: "#80608e"
                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }
                    }
                }
                contentItem: Item {
                    Column {
                        id: nyaaViewDetails
                        x: 14
                        y: 14
                        width: parent.width - 28
                        spacing: 12
                        Text {
                            visible: nyaaViewResultRow.index === 0
                            width: parent.width
                            text: nyaaViewResultRow.modelData.series + " / " + nyaaViewResultRow.modelData.group
                            color: "#c3a0ff"
                            font.pixelSize: 11
                            font.bold: true
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                        Text {
                            visible: !!nyaaViewResultRow.modelData.episode
                            text: "EPISODE " + nyaaViewResultRow.modelData.episode
                            color: "#bba6ca"
                            font.pixelSize: 9
                            font.letterSpacing: 1
                        }
                        Text {
                            width: parent.width
                            text: nyaaViewResultRow.modelData.title
                            textFormat: Text.PlainText
                            color: nyaaViewResultRow.current ? "#c3a0ff" : "#f3eaff"
                            wrapMode: Text.Wrap
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        Row {
                            width: parent.width
                            spacing: 10
                            Text {
                                width: parent.width - nyaaViewTransferLabel.implicitWidth - 10
                                text: "↑ " + nyaaViewResultRow.modelData.seeds + " seeds   ·   " + nyaaViewResultRow.modelData.size
                                color: nyaaViewResultRow.modelData.seeds > 0 ? "#a3be8c" : "#bba6ca"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                            Text {
                                id: nyaaViewTransferLabel
                                visible: nyaaViewResultRow.current || nyaaViewResultRow.queued
                                text: nyaaViewResultRow.current ? "Downloading…" : "Queued"
                                color: nyaaViewResultRow.current || nyaaViewResultRow.queued ? "#c3a0ff" : "#aa91bd"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }

    component YoutubeResult: SwipeDelegate {
        id: youtubeResultRoot
        required property var entry
        property bool playlist: false
        property bool available: true
        signal opened
        signal downloadRequested(string format)
        padding: 0
        height: youtubeResultPoster.height + 84
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.name: entry.title
        Accessible.description: playlist ? "Open playlist. Drag left for MP4, right for MP3." : "Drag left for 720p, right for MP3."
        onClicked: if (playlist && !entry.wholePlaylist)
            opened()
        Keys.onReturnPressed: if (playlist && !entry.wholePlaylist)
            opened()
        Keys.onPressed: function (event) {
            if (!available)
                return;
            if (event.key === Qt.Key_M) {
                downloadRequested("audio");
                event.accepted = true;
            }
            if (event.key === Qt.Key_V) {
                downloadRequested("video");
                event.accepted = true;
            }
        }
        swipe.enabled: available
        swipe.transition: Transition {
            SmoothedAnimation {
                velocity: 4
                easing.type: Easing.OutCubic
            }
        }
        swipe.onCompleted: {
            downloadRequested(swipe.position > 0 ? "audio" : "video");
            Qt.callLater(function () {
                youtubeResultRoot.swipe.close();
            });
        }
        swipe.left: Rectangle {
            width: youtubeResultRoot.width * 0.65
            height: youtubeResultRoot.height
            radius: 16
            color: "#634449"
            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf001"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 24
                    color: "#ffc9a3"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: youtubeResultRoot.playlist ? "All · MP3" : "MP3"
                    color: "#fff1e6"
                    font.pixelSize: 12
                }
            }
        }
        swipe.right: Rectangle {
            anchors.right: parent.right
            width: youtubeResultRoot.width * 0.65
            height: youtubeResultRoot.height
            radius: 16
            color: "#4d3c66"
            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf008"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 24
                    color: "#d8c2ff"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: youtubeResultRoot.playlist ? "All · MP4" : "720p"
                    color: "#f3eaff"
                    font.pixelSize: 12
                }
            }
        }
        background: Rectangle {
            radius: 16
            color: youtubeResultRoot.hovered || youtubeResultRoot.activeFocus ? "#2a2632" : "#201d27"
            border.color: youtubeResultRoot.activeFocus ? "#b4a0d5" : youtubeResultRoot.hovered ? "#54465f" : "#302a39"
            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }
        contentItem: Item {
            ClippingRectangle {
                id: youtubeResultPoster
                x: 7
                y: 7
                width: parent.width - 14
                height: width * 9 / 16
                radius: 11
                color: "#302837"
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#44334d"
                        }
                        GradientStop {
                            position: 1
                            color: "#241e30"
                        }
                    }
                }
                Text {
                    visible: youtubeResultArtwork.status !== Image.Ready
                    anchors.centerIn: parent
                    text: youtubeResultRoot.playlist ? "\uf03a" : "\uf16a"
                    color: "#ba9cd2"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 32
                }
                Image {
                    id: youtubeResultArtwork
                    anchors.fill: parent
                    source: youtubeResultRoot.entry.thumbnail || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 640
                    sourceSize.height: 360
                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0.5
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: "#990d0b12"
                        }
                    }
                }
                Rectangle {
                    visible: youtubeResultRoot.playlist || !!youtubeResultRoot.entry.duration
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 9
                    width: youtubeResultBadge.implicitWidth + 14
                    height: 23
                    radius: 7
                    color: "#d91a1422"
                    Text {
                        id: youtubeResultBadge
                        anchors.centerIn: parent
                        text: youtubeResultRoot.entry.wholePlaylist ? "Entire playlist" : youtubeResultRoot.playlist ? (youtubeResultRoot.entry.duration ? youtubeResultRoot.entry.duration + " tracks" : "Playlist") : youtubeResultRoot.entry.duration || ""
                        color: "#eee4f7"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }
            }
            Column {
                x: 13
                y: youtubeResultPoster.height + 18
                width: parent.width - 26
                spacing: 7
                Text {
                    width: parent.width
                    height: 34
                    text: youtubeResultRoot.entry.title
                    color: "#f0edf4"
                    textFormat: Text.PlainText
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: youtubeResultRoot.entry.channel || ""
                    color: "#9d91a8"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
        }
    }

    component YtdlpView: Column {
        id: ytdlpViewRoot
        function space(value) {
            return value;
        }
        property string mode: "video"
        property string message: ""
        property bool failed: false
        property bool youtubeMode: true
        property bool playlistMode: false
        property var selectedPlaylist: null
        property int playlistSearchPage: 1
        property int searchPage: 1
        property bool hasMore: false
        property string searchQuery: ""
        property var videos: []
        spacing: 16

        function focusUrl() {
            ytdlpViewUrlInput.forceActiveFocus();
        }
        function startDownload(downloadMode) {
            if (ytdlpViewCooldown.running)
                return;
            mode = downloadMode;
            var url = ytdlpViewUrlInput.text.trim();
            if (!/^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/i.test(url)) {
                failed = true;
                message = "Enter a valid HTTP or HTTPS URL";
                focusUrl();
                return;
            }
            Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/download.py", mode, url]);
            failed = false;
            message = "";
            ytdlpViewUrlInput.text = "";
            ytdlpViewCooldown.restart();
        }
        function searchYoutube(page) {
            if (ytdlpViewYoutubeSearch.running || (!selectedPlaylist && !ytdlpViewUrlInput.text.trim()))
                return;
            var requestedPage = page || 1;
            if (requestedPage === 1 && !selectedPlaylist)
                searchQuery = ytdlpViewUrlInput.text.trim();
            videos = [];
            failed = false;
            message = "Searching…";
            ytdlpViewYoutubeSearch.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/youtube.py", selectedPlaylist ? selectedPlaylist.url : searchQuery, String(requestedPage), selectedPlaylist ? "tracks" : playlistMode ? "playlists" : "videos"];
            ytdlpViewYoutubeSearch.running = true;
        }
        function openPlaylist(item) {
            if (ytdlpViewYoutubeSearch.running)
                return;
            playlistSearchPage = searchPage;
            selectedPlaylist = item;
            searchYoutube(1);
        }
        function backToPlaylists() {
            if (ytdlpViewYoutubeSearch.running)
                return;
            selectedPlaylist = null;
            searchYoutube(playlistSearchPage);
        }
        function setSearchKind(playlists) {
            if (ytdlpViewYoutubeSearch.running)
                return;
            playlistMode = playlists;
            selectedPlaylist = null;
            videos = [];
            searchPage = 1;
            hasMore = false;
            if (ytdlpViewUrlInput.text.trim())
                searchYoutube(1);
        }
        function downloadVideo(video, downloadMode) {
            if (ytdlpViewCooldown.running)
                return;
            Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/download.py", downloadMode, video.url]);
            failed = false;
            message = "Started: " + video.title + " · " + (downloadMode.indexOf("audio") >= 0 ? "MP3" : "MP4 · 720p");
            ytdlpViewCooldown.restart();
        }
        Process {
            id: ytdlpViewYoutubeSearch
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var response = JSON.parse(text);
                        ytdlpViewRoot.videos = response.results || [];
                        if (!response.error)
                            ytdlpViewRoot.searchPage = response.page || 1;
                        ytdlpViewRoot.hasMore = !!response.hasMore;
                        ytdlpViewRoot.failed = !!response.error;
                        ytdlpViewRoot.message = response.error || (ytdlpViewRoot.videos.length ? "" : "No videos found");
                    } catch (error) {
                        ytdlpViewRoot.failed = true;
                        ytdlpViewRoot.message = "Unable to read search results";
                    }
                }
            }
        }

        Timer {
            id: ytdlpViewCooldown
            interval: 1500
        }

        readonly property bool linkMode: /^https?:\/\//i.test(ytdlpViewUrlInput.text.trim())
        readonly property int gridColumns: width >= 500 ? 2 : 1
        readonly property var resultEntries: linkMode && !selectedPlaylist ? [
            {
                title: ytdlpViewUrlInput.text.trim(),
                channel: "",
                url: ytdlpViewUrlInput.text.trim(),
                thumbnail: "",
                duration: "",
                directLink: true
            }
        ] : selectedPlaylist ? [Object.assign({}, selectedPlaylist, {
                wholePlaylist: true,
                channel: selectedPlaylist.channel || ""
            })].concat(videos) : videos

        Rectangle {
            width: parent.width
            height: 52
            radius: 16
            color: "#18151e"
            border.color: ytdlpViewUrlInput.activeFocus ? "#8d75a7" : "#3b3145"
            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }
            Text {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf16a"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 19
                color: "#d8b8ca"
            }
            TextInput {
                id: ytdlpViewUrlInput
                objectName: "downloadUrl"
                x: 49
                width: parent.width - x - 49
                anchors.verticalCenter: parent.verticalCenter
                color: "#f0edf4"
                font.family: "sans-serif"
                font.pixelSize: 13
                selectionColor: "#53415f"
                selectByMouse: true
                clip: true
                Accessible.name: "Search YouTube or paste a link"
                onAccepted: if (!ytdlpViewRoot.linkMode) {
                    ytdlpViewRoot.selectedPlaylist = null;
                    ytdlpViewRoot.searchYoutube();
                }
                onTextEdited: {
                    ytdlpViewRoot.message = "";
                    if (ytdlpViewRoot.linkMode)
                        ytdlpViewRoot.selectedPlaylist = null;
                }
                Text {
                    visible: !ytdlpViewUrlInput.text
                    text: "Search or paste a link"
                    color: "#8d8198"
                    font: ytdlpViewUrlInput.font
                }
            }
            ToolButton {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                enabled: !ytdlpViewYoutubeSearch.running && !!ytdlpViewUrlInput.text.trim() && !ytdlpViewRoot.linkMode
                Accessible.name: "Search"
                onClicked: {
                    ytdlpViewRoot.selectedPlaylist = null;
                    ytdlpViewRoot.searchYoutube();
                }
                contentItem: Text {
                    text: ytdlpViewYoutubeSearch.running ? "···" : "\uf002"
                    font.family: "Symbols Nerd Font Mono"
                    color: "#ddd0ee"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 11
                    color: parent.hovered ? "#483453" : "#302638"
                    opacity: parent.enabled ? 1 : 0.4
                }
            }
        }

        Item {
            width: parent.width
            height: 30
            Rectangle {
                visible: !ytdlpViewRoot.selectedPlaylist && !ytdlpViewRoot.linkMode
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 82
                height: 30
                radius: 11
                color: "#18151e"
                Rectangle {
                    x: ytdlpViewRoot.playlistMode ? 42 : 3
                    y: 3
                    width: 37
                    height: 24
                    radius: 8
                    color: "#483653"
                    Behavior on x {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Row {
                    x: 3
                    y: 3
                    spacing: 2
                    Repeater {
                        model: [
                            {
                                playlist: false,
                                icon: "\uf008",
                                label: "Videos"
                            },
                            {
                                playlist: true,
                                icon: "\uf03a",
                                label: "Playlists"
                            }
                        ]
                        Item {
                            id: ytdlpViewKindButton
                            required property var modelData
                            width: 37
                            height: 24
                            enabled: !ytdlpViewYoutubeSearch.running
                            activeFocusOnTab: true
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.label
                            Accessible.checked: ytdlpViewRoot.playlistMode === modelData.playlist
                            function choose() {
                                if (ytdlpViewRoot.playlistMode !== modelData.playlist)
                                    ytdlpViewRoot.setSearchKind(modelData.playlist);
                            }
                            Keys.onReturnPressed: choose()
                            Keys.onSpacePressed: choose()
                            Text {
                                anchors.centerIn: parent
                                text: ytdlpViewKindButton.modelData.icon
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 12
                                color: ytdlpViewRoot.playlistMode === ytdlpViewKindButton.modelData.playlist ? "#ead5ff" : "#8d8198"
                            }
                            PanelToolTip {
                                visible: ytdlpViewKindHit.containsMouse
                                text: ytdlpViewKindButton.modelData.label
                            }
                            Timer {
                                interval: 220
                                running: ytdlpViewKindHit.containsMouse && ytdlpViewKindButton.enabled && ytdlpViewRoot.playlistMode !== ytdlpViewKindButton.modelData.playlist
                                onTriggered: ytdlpViewKindButton.choose()
                            }
                            MouseArea {
                                id: ytdlpViewKindHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ytdlpViewKindButton.choose()
                            }
                        }
                    }
                }
            }
            ToolButton {
                visible: !!ytdlpViewRoot.selectedPlaylist
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 30
                enabled: !ytdlpViewYoutubeSearch.running
                Accessible.name: "Back to playlists"
                onClicked: ytdlpViewRoot.backToPlaylists()
                contentItem: Text {
                    text: "\uf104"
                    font.family: "Symbols Nerd Font Mono"
                    color: "#cbb7df"
                    font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 10
                    color: parent.hovered ? "#35283e" : "transparent"
                }
            }
            Text {
                visible: !!ytdlpViewRoot.selectedPlaylist
                x: 40
                width: parent.width - 150
                anchors.verticalCenter: parent.verticalCenter
                text: ytdlpViewRoot.selectedPlaylist ? ytdlpViewRoot.selectedPlaylist.title : ""
                color: "#e8dfef"
                font.pixelSize: 12
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Row {
                visible: !ytdlpViewRoot.linkMode && (ytdlpViewRoot.videos.length > 0 || ytdlpViewRoot.searchPage > 1)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                ToolButton {
                    width: 28
                    height: 28
                    enabled: ytdlpViewRoot.searchPage > 1 && !ytdlpViewYoutubeSearch.running
                    Accessible.name: "Previous page"
                    onClicked: ytdlpViewRoot.searchYoutube(ytdlpViewRoot.searchPage - 1)
                    contentItem: Text {
                        text: "‹"
                        font.pixelSize: 22
                        color: parent.enabled ? "#ddd0ee" : "#51465c"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 9
                        color: parent.hovered ? "#35283e" : "transparent"
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(ytdlpViewRoot.searchPage).padStart(2, "0")
                    color: "#b7a5c6"
                    font.pixelSize: 11
                }
                ToolButton {
                    width: 28
                    height: 28
                    enabled: ytdlpViewRoot.hasMore && !ytdlpViewYoutubeSearch.running
                    Accessible.name: "Next page"
                    onClicked: ytdlpViewRoot.searchYoutube(ytdlpViewRoot.searchPage + 1)
                    contentItem: Text {
                        text: "›"
                        font.pixelSize: 22
                        color: parent.enabled ? "#ddd0ee" : "#51465c"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 9
                        color: parent.hovered ? "#35283e" : "transparent"
                    }
                }
            }
        }

        Text {
            visible: !!ytdlpViewRoot.message
            width: parent.width
            text: ytdlpViewRoot.message
            color: ytdlpViewRoot.failed ? "#f0a1ac" : "#b7a5c6"
            font.pixelSize: 11
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
        Grid {
            width: parent.width
            columns: ytdlpViewRoot.gridColumns
            spacing: 12
            Repeater {
                model: ytdlpViewRoot.resultEntries
                YoutubeResult {
                    required property var modelData
                    width: (ytdlpViewRoot.width - (ytdlpViewRoot.gridColumns - 1) * 12) / ytdlpViewRoot.gridColumns
                    entry: modelData
                    playlist: !!modelData.wholePlaylist || (!modelData.directLink && ytdlpViewRoot.playlistMode && !ytdlpViewRoot.selectedPlaylist)
                    available: !ytdlpViewCooldown.running
                    onOpened: ytdlpViewRoot.openPlaylist(modelData)
                    onDownloadRequested: function (format) {
                        if (modelData.directLink)
                            ytdlpViewRoot.startDownload(format);
                        else
                            ytdlpViewRoot.downloadVideo(modelData, (playlist ? "playlist-" : "") + format);
                    }
                }
            }
        }
    }
}
