import "../controls"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "../scripts/ClipboardHistory.js" as ClipboardHistory
import "../scripts/ClipboardUtil.js" as Util

Item {
    id: root
    signal backRequested
    signal panelRequested(string panel)
    function space(value) {
        return value;
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            root.toggle();
        }
        function close(): void {
            root.close();
        }
    }

    property string actionScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_action.py"
    property bool opened: false
    property string filterText: ""
    property string entryFilter: "all"
    property int selectedIndex: 0
    property bool cursorActive: false
    property bool clearConfirmOpen: false
    property var history: []

    property string historyPath: Quickshell.env("HOME") + "/.local/state/quickshell/clipboard/clipboard-history.json"
    property string captureScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard_capture.sh"
    property color background: "#18181d"
    property color foreground: "#eef3f8"
    property color border: "#37343f"
    property color scrim: "#ac080e16"
    property color selectedBackground: "#383044"
    property color selectedText: "#eef3f8"
    readonly property int cornerRadius: root.space(18)
    property string fontFamily: "sans-serif"
    property int contentMargin: root.space(16)
    property int headerHeight: root.space(48)
    property int contentSpacing: root.space(12)
    property int cardWidth: Math.max(0, Math.min(root.space(820), panel.width - root.space(32)))
    property int cardHeight: Math.max(0, Math.min(root.space(520), panel.height - root.space(96)))
    property int rowHeight: root.space(48)
    property int historyLimit: 300
    readonly property var activeRow: displayModel.count > 0 && selectedIndex >= 0 && selectedIndex < displayModel.count ? displayModel.get(selectedIndex) : null

    function open(payloadJson) {
        root.opened = true;
        root.filterText = "";
        root.entryFilter = "all";
        root.selectedIndex = 0;
        root.cursorActive = true;
        root.disarmPointer();
        root.rebuildDisplay();
        Qt.callLater(function () {
            keyCatcher.forceActiveFocus();
        });
    }

    function close() {
        root.cancelClearHistory();
        root.opened = false;
    }

    function toggle() {
        if (root.opened)
            root.close();
        else
            root.open("{}");
    }

    function normalizeEntry(value) {
        return ClipboardHistory.normalizeEntry(value);
    }

    function entryKey(entry) {
        return ClipboardHistory.entryKey(entry);
    }

    function loadHistory(raw) {
        root.history = ClipboardHistory.parseHistory(raw);
        if (root.opened)
            root.rebuildDisplay();
    }

    function saveHistory() {
        historyFile.setText(JSON.stringify(root.history.slice(0, root.historyLimit), null, 2) + "\n");
    }

    function addClipboardEntry(entry) {
        var normalized = ClipboardHistory.normalizeEntry(entry);
        if (!normalized)
            return;
        root.history = ClipboardHistory.addEntry(root.history, normalized, root.historyLimit);
        root.saveHistory();
        if (root.opened)
            root.rebuildDisplay();
    }

    function addClipboardJson(line) {
        root.addClipboardEntry(ClipboardHistory.parseEntryJson(line));
    }

    function requestClearHistory() {
        if (root.history.length === 0)
            return;
        clearConfirm.selectedIndex = 1;
        root.clearConfirmOpen = true;
        Qt.callLater(function () {
            keyCatcher.forceActiveFocus();
        });
    }

    function cancelClearHistory() {
        root.clearConfirmOpen = false;
        root.disarmPointer();
        Qt.callLater(function () {
            keyCatcher.forceActiveFocus();
        });
    }

    function confirmClearHistory() {
        root.history = ClipboardHistory.clearHistory();
        root.saveHistory();
        root.selectedIndex = 0;
        root.cursorActive = false;
        root.disarmPointer();
        root.clearConfirmOpen = false;
        root.rebuildDisplay();
        Qt.callLater(function () {
            keyCatcher.forceActiveFocus();
        });
    }

    function removeDisplayIndex(index) {
        if (index < 0 || index >= displayModel.count)
            return;
        var row = displayModel.get(index);
        root.history = ClipboardHistory.removeEntryAt(root.history, row.historyIndex);
        root.saveHistory();

        if (displayModel.count <= 1) {
            root.selectedIndex = 0;
            root.cursorActive = false;
        } else if (root.selectedIndex >= displayModel.count - 1) {
            root.selectedIndex = displayModel.count - 2;
        }

        root.disarmPointer();
        root.rebuildDisplay();
    }

    function rebuildDisplay() {
        var rows = ClipboardHistory.displayRows(root.history, root.filterText, root.historyLimit, root.entryFilter);

        displayModel.clear();
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
            displayModel.append({
                entryType: row.entryType,
                fullText: row.fullText,
                previewText: row.previewText,
                previewImage: row.previewImage ? Util.fileUrl(row.previewImage) : "",
                path: row.path,
                mime: row.mime,
                historyIndex: row.index
            });
        }

        if (displayModel.count === 0)
            selectedIndex = 0;
        else if (selectedIndex >= displayModel.count)
            selectedIndex = displayModel.count - 1;
        else if (selectedIndex < 0)
            selectedIndex = 0;

        Qt.callLater(function () {
            if (displayModel.count > 0)
                resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        });
    }

    function select(delta) {
        if (displayModel.count === 0)
            return;
        root.disarmPointer();
        if (!cursorActive) {
            cursorActive = true;
            selectedIndex = delta < 0 ? displayModel.count - 1 : 0;
        } else {
            selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count;
        }
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function selectAbsolute(index) {
        if (displayModel.count === 0)
            return;
        root.disarmPointer();
        root.cursorActive = true;
        root.selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1));
        resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function setFilter(nextFilter) {
        root.filterText = nextFilter;
        root.selectedIndex = 0;
        root.cursorActive = true;
        root.disarmPointer();
        root.rebuildDisplay();
    }

    function setEntryFilter(kind) {
        root.entryFilter = kind;
        root.selectedIndex = 0;
        root.cursorActive = true;
        root.disarmPointer();
        root.rebuildDisplay();
        keyCatcher.forceActiveFocus();
    }

    function stepEntryFilter(direction) {
        var filters = ["all", "text", "image"];
        var index = filters.indexOf(root.entryFilter);
        gestureCooldown.restart();
        root.setEntryFilter(filters[Math.max(0, Math.min(filters.length - 1, index + direction))]);
    }

    Timer {
        id: gestureCooldown
        interval: 600
    }

    function disarmPointer() {
        pointerGate.reset();
    }

    function selectFromPointer(index, item, mouse) {
        if (!pointerGate.moved(item, mouse))
            return;
        root.cursorActive = true;
        root.selectedIndex = index;
    }

    function activateIndex(index) {
        if (index < 0 || index >= displayModel.count)
            return;
        var row = displayModel.get(index);
        root.applySelected(row);
    }

    function copyIndex(index) {
        if (index < 0 || index >= displayModel.count)
            return;
        var row = displayModel.get(index);
        root.copySelected(row);
    }

    function openIndex(index) {
        if (index < 0 || index >= displayModel.count)
            return;
        var row = displayModel.get(index);
        root.openSelected(row);
    }

    function dispatchRow(row, mode) {
        if (!row)
            return;
        root.close();
        Quickshell.execDetached(["python3", "-B", root.actionScript, mode, String(row.historyIndex)]);
    }
    function applySelected(row) {
        dispatchRow(row, "paste");
    }
    function copySelected(row) {
        dispatchRow(row, "copy");
    }
    function openSelected(row) {
        dispatchRow(row, "open");
    }

    Component.onCompleted: initProc.running = true

    ListModel {
        id: displayModel
    }

    QtObject {
        id: pointerGate
        property var previous: null
        function reset() {
            previous = null;
        }
        function moved(item, mouse) {
            var point = item.mapToItem(card, mouse.x, mouse.y);
            var result = previous !== null && (Math.abs(point.x - previous.x) + Math.abs(point.y - previous.y) > 2);
            previous = point;
            return result;
        }
    }

    FileView {
        id: historyFile
        path: root.historyPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadHistory(text())
        onLoadFailed: root.loadHistory("[]")
        onFileChanged: reload()
    }

    Process {
        id: initProc
        command: ["python3", "-B", root.actionScript, "init"]
        onExited: {
            currentProc.running = true;
            textWatchProc.running = true;
            imageWatchProc.running = true;
        }
    }

    Process {
        id: currentProc
        command: [root.captureScript]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.addClipboardJson(text)
        }
    }

    Process {
        id: textWatchProc
        command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch", root.captureScript, "text"]
        onExited: watchRestartTimer.restart()
        stdout: SplitParser {
            onRead: function (data) {
                root.addClipboardJson(data);
            }
        }
    }

    Process {
        id: imageWatchProc
        command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image/png", "--watch", root.captureScript, "image/png"]
        onExited: watchRestartTimer.restart()
        stdout: SplitParser {
            onRead: function (data) {
                root.addClipboardJson(data);
            }
        }
    }

    Timer {
        id: watchRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!textWatchProc.running)
                textWatchProc.running = true;
            if (!imageWatchProc.running)
                imageWatchProc.running = true;
        }
    }

    PanelWindow {
        id: panel
        Shortcut {
            sequence: "Alt+Left"
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
            currentPanel: "clipboard"
            onSelected: function (panel) {
                root.panelRequested(panel);
            }
        }
        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            enabled: root.opened
            onActivated: {
                if (root.clearConfirmOpen)
                    root.cancelClearHistory();
                else if (root.filterText)
                    root.setFilter("");
                else
                    root.close();
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
        WlrLayershell.namespace: "y-clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: root.scrim
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card
            width: root.cardWidth
            height: root.cardHeight
            radius: root.cornerRadius
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 0
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#25202e"
                }
                GradientStop {
                    position: 1
                    color: root.background
                }
            }
            border.width: 1
            border.color: Qt.rgba(0.65, 0.82, 1, 0.10)

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            FilterSwipe {
                enabled: root.opened && !root.clearConfirmOpen
                onStepped: function (direction) {
                    root.stepEntryFilter(direction);
                }
            }

            Item {
                id: keyCatcher
                anchors.fill: parent
                z: root.clearConfirmOpen ? 20 : 0
                focus: true

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function (event) {
                    if (root.clearConfirmOpen) {
                        if (clearConfirm.handleKey(event))
                            event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Escape) {
                        if (root.filterText)
                            root.setFilter("");
                        else
                            root.close();
                        event.accepted = true;
                    } else if (Util.editsFilter(event, root.filterText)) {
                        root.setFilter(Util.editedFilter(event, root.filterText));
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Delete) {
                        if (event.modifiers & Qt.ShiftModifier)
                            root.requestClearHistory();
                        else
                            root.removeDisplayIndex(root.selectedIndex);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.select(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        root.select(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        root.select(-6);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        root.select(6);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home) {
                        root.selectAbsolute(0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_End) {
                        root.selectAbsolute(displayModel.count - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.cursorActive && (event.modifiers & Qt.AltModifier))
                            root.openIndex(root.selectedIndex);
                        else if (root.cursorActive && (event.modifiers & Qt.ShiftModifier))
                            root.copyIndex(root.selectedIndex);
                        else if (root.cursorActive)
                            root.activateIndex(root.selectedIndex);
                        else if (displayModel.count > 0)
                            root.cursorActive = true;
                        event.accepted = true;
                    } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
                        root.setFilter(root.filterText + event.text);
                        event.accepted = true;
                    }
                }

                ConfirmDialog {
                    id: clearConfirm

                    anchors.fill: parent
                    opened: root.clearConfirmOpen
                    z: 10
                    message: "Clear the entire clipboard history?"
                    confirmText: "Delete"
                    background: root.background
                    foreground: root.foreground
                    scrim: root.scrim
                    selectedBackground: root.selectedBackground
                    selectedText: root.selectedText
                    fontFamily: root.fontFamily
                    cornerRadius: root.cornerRadius
                    onCanceled: root.cancelClearHistory()
                    onConfirmed: root.confirmClearHistory()
                }
            }

            Column {
                id: content
                anchors.fill: parent
                anchors.margins: root.contentMargin
                spacing: root.space(10)

                Rectangle {
                    width: parent.width
                    height: root.space(42)
                    radius: 13
                    color: "#17141e"
                    border.width: 1
                    border.color: searchInput.activeFocus ? "#625471" : "#37343f"
                    Text {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf002"
                        color: "#aaa6b5"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                    }
                    TextInput {
                        id: searchInput
                        anchors.left: parent.left
                        anchors.right: clearFilter.left
                        anchors.leftMargin: 44
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.filterText
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        selectionColor: "#493b5e"
                        selectByMouse: true
                        clip: true
                        Accessible.name: "Search clipboard"
                        onTextEdited: root.setFilter(text)
                        Keys.onDownPressed: {
                            root.select(1);
                            keyCatcher.forceActiveFocus();
                        }
                        Keys.onUpPressed: {
                            root.select(-1);
                            keyCatcher.forceActiveFocus();
                        }
                        Keys.onReturnPressed: {
                            if (event.modifiers & Qt.AltModifier)
                                root.openIndex(root.selectedIndex);
                            else if (event.modifiers & Qt.ShiftModifier)
                                root.copyIndex(root.selectedIndex);
                            else
                                root.activateIndex(root.selectedIndex);
                        }
                        Text {
                            visible: !searchInput.text
                            text: "Search…"
                            color: "#716c76"
                            font: searchInput.font
                        }
                    }
                    ClipAction {
                        id: clearHistoryButton
                        contextRoot: root
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "\uf12d"
                        actionName: "Clear history"
                        danger: true
                        enabled: root.history.length > 0
                        onClicked: root.requestClearHistory()
                    }
                    Item {
                        id: clearFilter
                        anchors.right: clearHistoryButton.left
                        width: root.filterText ? 32 : 0
                        height: parent.height
                        visible: !!root.filterText
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "#aaa6b5"
                            font.pixelSize: 18
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.setFilter("");
                                keyCatcher.forceActiveFocus();
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: [
                            {
                                key: "all",
                                icon: "\uf009",
                                label: "All"
                            },
                            {
                                key: "text",
                                icon: "\uf15c",
                                label: "Text"
                            },
                            {
                                key: "image",
                                icon: "\uf03e",
                                label: "Images"
                            }
                        ]
                        Rectangle {
                            id: filterButton
                            required property var modelData
                            readonly property bool selected: root.entryFilter === modelData.key
                            width: 34
                            height: 28
                            radius: 9
                            color: selected ? "#383044" : filterHit.containsMouse || activeFocus ? "#29252f" : "#151319"
                            border.width: selected ? 1 : 0
                            border.color: "#625471"
                            activeFocusOnTab: true
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.label
                            Accessible.checked: selected
                            Behavior on color {
                                ColorAnimation {
                                    duration: 130
                                }
                            }
                            Keys.onReturnPressed: root.setEntryFilter(modelData.key)
                            Keys.onSpacePressed: root.setEntryFilter(modelData.key)
                            Text {
                                anchors.centerIn: parent
                                text: filterButton.modelData.icon
                                color: filterButton.selected ? "#d8caff" : "#aaa6b5"
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 12
                            }
                            PanelToolTip {
                                visible: filterHit.containsMouse
                                text: filterButton.modelData.label
                                fontFamily: root.fontFamily
                            }
                            Timer {
                                interval: 180
                                running: root.opened && filterHit.containsMouse && !filterButton.selected && !root.clearConfirmOpen && !gestureCooldown.running
                                onTriggered: root.setEntryFilter(filterButton.modelData.key)
                            }
                            MouseArea {
                                id: filterHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setEntryFilter(filterButton.modelData.key)
                            }
                        }
                    }
                }

                Item {
                    id: results
                    width: parent.width
                    height: Math.max(0, content.height - y - 36)
                    ListView {
                        id: resultList
                        width: Math.floor(parent.width * 0.38)
                        height: parent.height
                        model: displayModel
                        clip: true
                        spacing: 5
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                        delegate: Rectangle {
                            id: row
                            required property int index
                            required property string entryType
                            required property string previewText
                            required property string fullText
                            required property string previewImage
                            readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
                            width: ListView.view.width
                            height: root.rowHeight
                            radius: 10
                            color: hasCursor ? "#383044" : rowHit.containsMouse ? "#292430" : "#151219"
                            border.width: hasCursor ? 1 : 0
                            border.color: "#655271"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 110
                                }
                            }
                            Timer {
                                interval: 180
                                running: root.opened && rowHit.containsMouse && !row.hasCursor && !root.clearConfirmOpen
                                onTriggered: {
                                    root.cursorActive = true;
                                    root.selectedIndex = row.index;
                                }
                            }
                            MouseArea {
                                id: rowHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.cursorActive = true;
                                    root.selectedIndex = row.index;
                                    keyCatcher.forceActiveFocus();
                                }
                                onDoubleClicked: root.activateIndex(row.index)
                            }
                            Rectangle {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 28
                                radius: 8
                                color: row.hasCursor ? "#493b5e" : "#2b2833"
                                Text {
                                    visible: !row.previewImage
                                    anchors.centerIn: parent
                                    text: row.entryType === "image" ? "\uf03e" : row.entryType === "file" ? "\uf15b" : "\uf15c"
                                    color: "#c3b7ff"
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 17
                                }
                                Image {
                                    visible: !!row.previewImage
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: row.previewImage
                                    sourceSize.width: 100
                                    sourceSize.height: 100
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                            }
                            Column {
                                x: 48
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - 30
                                spacing: 4
                                Text {
                                    width: parent.width
                                    text: row.previewText
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.weight: row.hasCursor ? Font.Medium : Font.Normal
                                }
                            }
                            ClipAction {
                                contextRoot: root
                                visible: row.hasCursor || rowHit.containsMouse
                                anchors.right: parent.right
                                anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                glyph: "\uf00d"
                                actionName: "Remove entry"
                                danger: true
                                onClicked: root.removeDisplayIndex(row.index)
                            }
                        }
                    }
                    Rectangle {
                        id: preview
                        anchors.left: resultList.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        height: parent.height
                        radius: 15
                        color: "#17141d"
                        border.width: 1
                        border.color: "#302d37"
                        visible: displayModel.count > 0
                        Item {
                            id: previewHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 12
                            height: 24
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                color: "#aaa6b5"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            Row {
                                anchors.right: parent.right
                                spacing: 4
                                ClipAction {
                                    contextRoot: root
                                    width: 26
                                    height: 26
                                    glyph: "\uf0c5"
                                    actionName: "Copy · Shift+Enter"
                                    onClicked: root.copyIndex(root.selectedIndex)
                                }
                                ClipAction {
                                    contextRoot: root
                                    width: 26
                                    height: 26
                                    glyph: "\uf08e"
                                    actionName: "Open · Alt+Enter"
                                    onClicked: root.openIndex(root.selectedIndex)
                                }
                            }
                        }
                        Rectangle {
                            visible: false
                            anchors.top: previewHeader.bottom
                            anchors.topMargin: 12
                            x: 16
                            width: parent.width - 32
                            height: 1
                            color: "#29262f"
                        }
                        ScrollView {
                            id: previewScroll
                            anchors.top: previewHeader.bottom
                            anchors.topMargin: 10
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            anchors.bottomMargin: 18
                            clip: true
                            visible: root.activeRow && !root.activeRow.previewImage
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            TextArea {
                                width: previewScroll.availableWidth
                                text: root.activeRow ? root.activeRow.fullText : ""
                                textFormat: TextEdit.PlainText
                                readOnly: true
                                selectByMouse: true
                                persistentSelection: true
                                wrapMode: TextEdit.WrapAnywhere
                                background: null
                                padding: 0
                                color: "#e9e5ee"
                                selectionColor: "#493b5e"
                                font.family: root.fontFamily
                                font.pixelSize: 12
                            }
                        }
                        Image {
                            anchors.top: previewHeader.bottom
                            anchors.topMargin: 4
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.bottomMargin: 10
                            visible: root.activeRow && !!root.activeRow.previewImage
                            source: root.activeRow ? root.activeRow.previewImage : ""
                            sourceSize.width: 900
                            sourceSize.height: 900
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 14
                        visible: displayModel.count === 0
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf0ea"
                            color: "#625471"
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 34
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.history.length === 0 ? "Clipboard empty" : "No matches"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 28
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: displayModel.count
                        color: "#82758f"
                        font.family: root.fontFamily
                        font.pixelSize: 10
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 76
                        height: 28
                        radius: 14
                        enabled: displayModel.count > 0
                        opacity: enabled ? 1 : 0.35
                        color: pasteHit.containsMouse || activeFocus ? "#ded4ff" : "#c3b7ff"
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Paste selected item"
                        Keys.onReturnPressed: root.activateIndex(root.selectedIndex)
                        Keys.onSpacePressed: root.activateIndex(root.selectedIndex)
                        Text {
                            anchors.centerIn: parent
                            text: "Paste ↵"
                            color: "#19171c"
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: pasteHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activateIndex(root.selectedIndex)
                        }
                    }
                }
            }
        }
    }

    component ClipAction: Rectangle {
        id: clipActionButton
        required property var contextRoot
        property string glyph: ""
        property string actionName: ""
        property bool danger: false
        signal clicked
        width: contextRoot.space(30)
        height: width
        radius: contextRoot.space(7)
        color: clipActionHit.containsMouse || activeFocus ? "#383044" : "transparent"
        opacity: enabled ? 1 : 0.3
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: actionName
        PanelToolTip {
            visible: clipActionHit.containsMouse
            text: clipActionButton.actionName
            fontFamily: contextRoot.fontFamily
        }
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            anchors.centerIn: parent
            text: clipActionButton.glyph
            color: clipActionButton.danger ? "#e28b9b" : "#c3b7ff"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: contextRoot.space(12)
        }
        MouseArea {
            id: clipActionHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: clipActionButton.clicked()
        }
    }

    component ConfirmDialog: Rectangle {
        id: confirmDialogRoot
        property bool opened: false
        property int selectedIndex: 1
        property string message: ""
        property string confirmText: "Delete"
        property color background: "#18181d"
        property color foreground: "#eef3f8"
        property color scrim: "#b3000000"
        property color selectedBackground: "#383044"
        property color selectedText: "#eef3f8"
        property string fontFamily: "sans-serif"
        property int cornerRadius: 8
        signal canceled
        signal confirmed
        visible: opened
        color: scrim
        function handleKey(event) {
            if (event.key === Qt.Key_Escape)
                canceled();
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                selectedIndex = 1 - selectedIndex;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (selectedIndex === 0)
                    confirmed();
                else
                    canceled();
            } else
                return false;
            return true;
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(350, parent.width - 32)
            height: 130
            radius: confirmDialogRoot.cornerRadius
            color: confirmDialogRoot.background
            border.color: "#37343f"
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                text: confirmDialogRoot.message
                color: confirmDialogRoot.foreground
                font.family: confirmDialogRoot.fontFamily
                font.pixelSize: 13
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 70
                spacing: 10
                Repeater {
                    model: [confirmDialogRoot.confirmText, "Cancel"]
                    Rectangle {
                        required property int index
                        required property string modelData
                        width: 100
                        height: 32
                        radius: 4
                        color: confirmDialogRoot.selectedIndex === index ? confirmDialogRoot.selectedBackground : "transparent"
                        border.width: 1
                        border.color: confirmDialogRoot.selectedIndex === index ? "#c3b7ff" : "#37343f"
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: index === 0 ? "#bf616a" : confirmDialogRoot.selectedText
                            font.family: confirmDialogRoot.fontFamily
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse)
                                confirmDialogRoot.selectedIndex = parent.index
                            onClicked: if (parent.index === 0)
                                confirmDialogRoot.confirmed()
                            else
                                confirmDialogRoot.canceled()
                        }
                    }
                }
            }
        }
    }

    component FilterSwipe: DragHandler {
        id: filterSwipeGesture
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        dragThreshold: 12
        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
        property bool triggered: false
        signal stepped(int direction)
        onActiveTranslationChanged: {
            if (active && !triggered && Math.abs(activeTranslation.x) >= 40) {
                triggered = true;
                stepped(activeTranslation.x < 0 ? 1 : -1);
            }
        }
        onActiveChanged: if (active)
            triggered = false
    }
}
