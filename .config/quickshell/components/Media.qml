import "../controls/PanelTheme.js" as Theme
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtMultimedia
import "../controls"
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Item {
    id: root
    signal backRequested
    signal panelRequested(string panel)
    function space(value) {
        return value;
    }
    property QtObject bar: null
    property string moduleName: "y.media"
    property var settings: ({})
    property var shell: null
    property var manifest: null
    property bool opened: false
    property string section: "images"

    function syncViews() {
        if (imagesView.item)
            imagesView.item.close();
        if (videosView.item)
            videosView.item.close();
        if (wallpapersView.item)
            wallpapersView.item.close();
        if (wallhavenView.item)
            wallhavenView.item.close();
        var view = section === "images" ? imagesView.item : section === "videos" ? videosView.item : section === "wallpapers" ? wallpapersView.item : section === "wallhaven" ? wallhavenView.item : null;
        if (opened && view)
            view.open("{}");
    }
    function selectSection(name) {
        if (section === name)
            return;
        section = name;
        syncViews();
    }
    function open(payloadJson) {
        try {
            var payload = JSON.parse(payloadJson || "{}");
            if (payload.section === "images" || payload.section === "videos" || payload.section === "wallpapers" || payload.section === "wallhaven")
                section = payload.section;
        } catch (e) {}
        opened = true;
        syncViews();
        Qt.callLater(function () {
            frame.forceActiveFocus();
        });
    }
    function close() {
        opened = false;
        syncViews();
    }
    function dismiss() {
        close();
        if (shell)
            shell.hide("y.media");
    }
    function toggle() {
        if (opened)
            dismiss();
        else
            open("{}");
    }

    IpcHandler {
        target: "media"
        function toggle(): void {
            root.toggle();
        }
        function close(): void {
            root.dismiss();
        }
        function open(section: string): void {
            root.open(JSON.stringify({
                section: section
            }));
        }
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
            currentPanel: "media"
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
        WlrLayershell.namespace: "y-media"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }
        Rectangle {
            id: frame
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 20
            width: Math.min(root.space(940), panel.width - root.space(32))
            height: Math.min(root.space(root.section === "wallpapers" ? 600 : 676), panel.height - root.space(96))
            radius: Theme.panelRadius
            gradient: PanelGradient {}
            border.width: 1
            border.color: Theme.border
            PanelAura { radius: parent.radius }
            focus: true
            Keys.onEscapePressed: root.dismiss()
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            Row {
                x: root.space(20)
                y: root.space(12)
                spacing: root.space(8)
                Repeater {
                    model: [
                        {
                            key: "images",
                            label: "Images"
                        },
                        {
                            key: "videos",
                            label: "Videos"
                        },
                        {
                            key: "wallpapers",
                            label: "Wallpapers"
                        },
                        {
                            key: "wallhaven",
                            label: "Wallhaven"
                        }
                    ]
                    Rectangle {
                        id: tab
                        required property var modelData
                        readonly property bool selected: root.section === modelData.key
                        width: root.space(90)
                        height: root.space(32)
                        radius: root.space(10)
                        color: selected ? Theme.hover : tabHit.containsMouse ? Theme.surface : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }
                        border.width: selected ? 1 : 0
                        border.color: "#45393f"
                        activeFocusOnTab: true
                        Keys.onReturnPressed: root.selectSection(modelData.key)
                        Keys.onSpacePressed: root.selectSection(modelData.key)
                        Text {
                            anchors.centerIn: parent
                            text: tab.modelData.label
                            color: tab.selected ? Theme.foreground : Theme.muted
                            font.family: "sans-serif"
                            font.pixelSize: root.space(12)
                            font.weight: tab.selected ? Font.DemiBold : Font.Normal
                        }
                        Timer {
                            interval: 180
                            running: root.opened && tabHit.containsMouse && !tab.selected
                            onTriggered: root.selectSection(tab.modelData.key)
                        }
                        MouseArea {
                            id: tabHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectSection(tab.modelData.key)
                        }
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: root.space(20)
                y: root.space(12)
                width: root.space(32)
                height: width
                radius: root.space(10)
                color: closeHit.containsMouse ? Theme.hover : Theme.surface
                activeFocusOnTab: true
                Keys.onReturnPressed: root.dismiss()
                Keys.onSpacePressed: root.dismiss()
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Theme.muted
                    font.pixelSize: root.space(18)
                }
                MouseArea {
                    id: closeHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismiss()
                }
            }
            Loader {
                id: imagesView
                x: root.space(20)
                y: root.space(56)
                width: parent.width - x * 2
                height: parent.height - y - root.space(20)
                visible: root.section === "images"
                sourceComponent: ImagesView {}
                onLoaded: {
                    item.bar = root.bar;
                    if (root.opened && visible)
                        item.open("{}");
                }
            }
            Loader {
                id: videosView
                anchors.fill: imagesView
                visible: root.section === "videos"
                sourceComponent: VideosView {}
                onLoaded: {
                    item.bar = root.bar;
                    if (root.opened && visible)
                        item.open("{}");
                }
            }
            Loader {
                id: wallpapersView
                anchors.fill: imagesView
                visible: root.section === "wallpapers"
                sourceComponent: WallpapersView {}
                onLoaded: {
                    item.bar = root.bar;
                    if (root.opened && visible)
                        item.open("{}");
                }
            }
            Loader {
                id: wallhavenView
                anchors.fill: imagesView
                visible: root.section === "wallhaven"
                sourceComponent: WallhavenView {}
                onLoaded: {
                    item.bar = root.bar;
                    if (root.opened && visible)
                        item.open("{}");
                }
            }
            Connections {
                target: imagesView.item
                function onDismissed() {
                    root.dismiss();
                }
            }
            Connections {
                target: videosView.item
                function onDismissed() {
                    root.dismiss();
                }
            }
            Connections {
                target: wallpapersView.item
                function onDismissed() {
                    root.dismiss();
                }
            }
            Connections {
                target: wallhavenView.item
                function onDismissed() {
                    root.dismiss();
                }
            }
        }
    }

    component DeleteSwipeDelegate: SwipeDelegate {
        id: deleteSwipeDelegateRow
        property bool canSwipe: true
        property real scaleFactor: 1
        signal removeRequested
        padding: 0
        hoverEnabled: true
        swipe.enabled: canSwipe
        swipe.transition: Transition {
            SmoothedAnimation {
                velocity: 4
                easing.type: Easing.OutCubic
            }
        }
        swipe.onCompleted: removeRequested()
        swipe.right: Rectangle {
            width: deleteSwipeDelegateRow.width * 0.6
            height: deleteSwipeDelegateRow.height
            anchors.right: parent.right
            radius: 12 * deleteSwipeDelegateRow.scaleFactor
            color: "#d9737f"
            Text {
                anchors.centerIn: parent
                text: "×"
                color: Theme.foreground
                font.pixelSize: 26 * deleteSwipeDelegateRow.scaleFactor
            }
        }
    }

    component ImagesViewImageButton: Rectangle {
        id: imagesViewImageButtonControl
        required property var contextRoot
        property string text: ""
        property string hint: ""
        property bool primary: false
        property bool danger: false
        signal clicked
        width: contextRoot.space(34)
        height: width
        radius: contextRoot.space(11)
        color: danger ? (imagesViewImageButtonMouse.containsMouse ? "#d9737f" : "#2c252b") : primary ? (imagesViewImageButtonMouse.containsMouse ? Theme.accent : Theme.accent) : imagesViewImageButtonMouse.containsMouse ? Theme.hover : Theme.surface
        scale: imagesViewImageButtonMouse.pressed ? 0.94 : 1
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 90
            }
        }
        opacity: enabled ? 1 : 0.4
        Text {
            anchors.centerIn: parent
            text: imagesViewImageButtonControl.text
            color: imagesViewImageButtonControl.danger ? "#d9737f" : imagesViewImageButtonControl.primary ? Theme.surface : contextRoot.accent
            font.family: "sans-serif"
            font.pixelSize: contextRoot.space(15)
        }
        MouseArea {
            id: imagesViewImageButtonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: imagesViewImageButtonControl.clicked()
        }
    }

    component ImagesView: Item {
        id: imagesViewRoot
        function space(value) {
            return value;
        }
        property QtObject bar: null
        property string moduleName: "y.images"
        property var settings: ({})
        property var shell: null
        property var manifest: null
        signal dismissed
        property bool opened: false
        property var images: []
        property string selected: ""
        property string hoveredImage: ""
        property string selectedFolder: ""
        readonly property var visibleImages: images.filter(function (image) {
            return !imagesViewRoot.selectedFolder || image.folder === imagesViewRoot.selectedFolder;
        })
        readonly property var galleryEntries: {
            if (selectedFolder)
                return visibleImages;
            var folders = {};
            var entries = [];
            images.forEach(function (image) {
                if (!folders[image.folder]) {
                    folders[image.folder] = {
                        path: image.folder,
                        name: image.folder.split("/").pop(),
                        folder: image.folder,
                        url: image.url,
                        count: 0,
                        isFolder: true
                    };
                    entries.push(folders[image.folder]);
                }
                folders[image.folder].count++;
            });
            return entries.sort(function (a, b) {
                return a.name.localeCompare(b.name) || a.path.localeCompare(b.path);
            });
        }
        property string error: ""
        property string copyStatus: ""
        readonly property int selectedIndex: visibleImages.findIndex(function (image) {
            return image.path === imagesViewRoot.selected;
        })
        readonly property var current: selectedIndex >= 0 ? visibleImages[selectedIndex] : null
        readonly property color accent: Theme.accent
        readonly property int columns: Math.max(1, Math.min(4, Math.floor((imagesViewRoot.width - imagesViewRoot.space(48)) / imagesViewRoot.space(210))))
        readonly property int rows: Math.max(1, Math.ceil(galleryEntries.length / columns))
        property string copyingPath: ""
        property string trashPath: ""

        function openFolder(folder) {
            hoveredImage = "";
            selectedFolder = folder;
            Qt.callLater(function () {
                imagesViewGallery.positionViewAtBeginning();
            });
        }
        function refresh() {
            if (!imagesViewQuery.running)
                imagesViewQuery.running = true;
        }
        function open(payload) {
            opened = true;
            refresh();
            Qt.callLater(function () {
                imagesViewCard.forceActiveFocus();
            });
        }
        function close() {
            opened = false;
            hoveredImage = "";
            selected = "";
            selectedFolder = "";
        }
        function dismiss() {
            close();
            dismissed();
        }
        function toggle() {
            if (opened)
                dismiss();
            else
                open("{}");
        }
        function back() {
            if (selected)
                selected = "";
            else if (selectedFolder)
                selectedFolder = "";
            else
                dismiss();
        }
        function step(direction) {
            copyStatus = "";
            if (visibleImages.length)
                selected = visibleImages[(selectedIndex + direction + visibleImages.length) % visibleImages.length].path;
        }
        function openInSwayimg() {
            var path = current ? current.path : hoveredImage;
            if (!opened || !path || !visibleImages.some(function (image) {
                return image.path === path;
            }))
                return;
            Quickshell.execDetached(["swayimg", "--", path]);
            dismiss();
        }
        Shortcut {
            sequence: "I"
            context: Qt.WindowShortcut
            enabled: imagesViewRoot.opened && (!!imagesViewRoot.current || !!imagesViewRoot.hoveredImage)
            autoRepeat: false
            onActivated: imagesViewRoot.openInSwayimg()
        }
        function copyImage() {
            if (!current || imagesViewCopyAction.running)
                return;
            copyStatus = "Copying…";
            copyingPath = current.path;
            imagesViewCopyAction.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/images.py", "copy", current.path];
            imagesViewCopyAction.running = true;
        }
        function trashImage() {
            if (!current || imagesViewTrashAction.running)
                return;
            trashPath = current.path;
            copyStatus = "Moving to Trash…";
            imagesViewTrashAction.command = ["gio", "trash", "--", trashPath];
            imagesViewTrashAction.running = true;
        }
        onSelectedChanged: {
            copyStatus = "";
            if (opened)
                Qt.callLater(function () {
                    imagesViewCard.forceActiveFocus();
                });
            if (current && !imagesViewPrepareAction.running) {
                imagesViewPrepareAction.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/images.py", "prepare", current.path];
                imagesViewPrepareAction.running = true;
            }
        }

        Process {
            id: imagesViewQuery
            command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/images.py"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(text);
                        if (JSON.stringify(imagesViewRoot.images) !== JSON.stringify(data.images))
                            imagesViewRoot.images = data.images;
                        imagesViewRoot.error = data.error || "";
                        if (imagesViewRoot.selected && imagesViewRoot.selectedIndex < 0)
                            imagesViewRoot.selected = "";
                    } catch (e) {
                        imagesViewRoot.error = "Could not load images.";
                    }
                }
            }
        }
        Timer {
            interval: 5000
            running: imagesViewRoot.opened
            repeat: true
            onTriggered: imagesViewRoot.refresh()
        }
        Process {
            id: imagesViewPrepareAction
            onExited: {
                if (imagesViewRoot.current && command[command.length - 1] !== imagesViewRoot.current.path) {
                    command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/images.py", "prepare", imagesViewRoot.current.path];
                    running = true;
                }
            }
        }
        Process {
            id: imagesViewTrashAction
            stderr: StdioCollector {
                onStreamFinished: if (text.trim())
                    console.warn("y.images trash:", text.trim())
            }
            onExited: function (code) {
                if (code !== 0) {
                    imagesViewRoot.copyStatus = "Could not move image to Trash";
                    return;
                }
                var index = imagesViewRoot.visibleImages.findIndex(function (image) {
                    return image.path === imagesViewRoot.trashPath;
                });
                var wasSelected = imagesViewRoot.selected === imagesViewRoot.trashPath;
                imagesViewRoot.images = imagesViewRoot.images.filter(function (image) {
                    return image.path !== imagesViewRoot.trashPath;
                });
                if (wasSelected)
                    imagesViewRoot.selected = imagesViewRoot.visibleImages.length ? imagesViewRoot.visibleImages[Math.min(Math.max(0, index), imagesViewRoot.visibleImages.length - 1)].path : "";
                imagesViewRoot.copyStatus = "Moved to Trash";
                imagesViewRoot.refresh();
            }
        }
        Process {
            id: imagesViewCopyAction
            stderr: StdioCollector {
                onStreamFinished: if (text.trim())
                    console.warn("y.images copy:", text.trim())
            }
            onExited: function (code) {
                if (imagesViewRoot.selected === imagesViewRoot.copyingPath)
                    imagesViewRoot.copyStatus = code === 0 ? "Image copied" : "Could not copy image";
            }
        }

        Rectangle {
            id: imagesViewCard
            focus: true
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_C && imagesViewRoot.current && !(event.modifiers & (Qt.AltModifier | Qt.MetaModifier))) {
                    imagesViewRoot.copyImage();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    imagesViewRoot.back();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left && imagesViewRoot.current) {
                    imagesViewRoot.step(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right && imagesViewRoot.current) {
                    imagesViewRoot.step(1);
                    event.accepted = true;
                }
            }
            anchors.fill: parent
            radius: imagesViewRoot.space(24)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.surface
                }
                GradientStop {
                    position: 1
                    color: Theme.surface
                }
            }
            border.color: Theme.border
            Behavior on width {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            Item {
                id: imagesViewHeader
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: imagesViewRoot.space(24)
                }
                height: imagesViewRoot.space(52)
                Row {
                    id: imagesViewTitleRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: imagesViewRoot.space(12)
                    ImagesViewImageButton {
                        contextRoot: imagesViewRoot
                        visible: !!imagesViewRoot.current || !!imagesViewRoot.selectedFolder
                        text: "‹"
                        onClicked: imagesViewRoot.back()
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: imagesViewRoot.space(5)
                        Text {
                            text: imagesViewRoot.selectedFolder ? imagesViewRoot.selectedFolder.split("/").pop() : "Images"
                            color: Theme.foreground
                            font.family: "sans-serif"
                            font.pixelSize: imagesViewRoot.space(23)
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.7
                        }
                        Text {
                            text: imagesViewRoot.current ? (imagesViewRoot.selectedIndex + 1) + " / " + imagesViewRoot.visibleImages.length + "  ·  Preview" : imagesViewRoot.selectedFolder ? imagesViewRoot.visibleImages.length + " images" : imagesViewRoot.galleryEntries.length + " folders"
                            color: Theme.muted
                            font.pixelSize: imagesViewRoot.space(10)
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: imagesViewRoot.space(8)
                    ImagesViewImageButton {
                        contextRoot: imagesViewRoot
                        visible: !!imagesViewRoot.current
                        text: "\uf0c5"
                        primary: true
                        hint: "Copy image · C"
                        enabled: !imagesViewCopyAction.running
                        onClicked: imagesViewRoot.copyImage()
                    }
                    ImagesViewImageButton {
                        contextRoot: imagesViewRoot
                        visible: !!imagesViewRoot.current
                        text: "\uf1f8"
                        danger: true
                        hint: "Move to Trash"
                        enabled: !imagesViewTrashAction.running && !imagesViewCopyAction.running
                        onClicked: imagesViewRoot.trashImage()
                    }
                    ImagesViewImageButton {
                        contextRoot: imagesViewRoot
                        text: "\uf07b"
                        hint: "Open folder"
                        onClicked: Quickshell.execDetached(["xdg-open", imagesViewRoot.current ? imagesViewRoot.current.folder : imagesViewRoot.selectedFolder || Quickshell.env("HOME") + "/0/pictures"])
                    }
                    ImagesViewImageButton {
                        contextRoot: imagesViewRoot
                        text: "↻"
                        hint: "Refresh"
                        enabled: !imagesViewQuery.running
                        onClicked: imagesViewRoot.refresh()
                    }
                }
            }
            GridView {
                id: imagesViewGallery
                visible: !imagesViewRoot.current
                anchors {
                    top: imagesViewHeader.bottom
                    bottom: imagesViewFooter.top
                    left: parent.left
                    right: parent.right
                    margins: imagesViewRoot.space(16)
                }
                cellWidth: width / imagesViewRoot.columns
                cellHeight: imagesViewRoot.space(178)
                clip: true
                model: imagesViewRoot.galleryEntries
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Item {
                    id: imagesViewEntry
                    required property var modelData
                    readonly property bool hot: imagesViewHit.containsMouse
                    objectName: "images-entry-" + modelData.path
                    width: imagesViewGallery.cellWidth
                    height: imagesViewGallery.cellHeight
                    Repeater {
                        model: imagesViewEntry.modelData.isFolder ? 2 : 0
                        Rectangle {
                            required property int index
                            anchors.fill: parent
                            anchors.margins: imagesViewRoot.space(8)
                            anchors.topMargin: imagesViewRoot.space(8) - (index + 1) * 4
                            anchors.bottomMargin: imagesViewRoot.space(8) + (index + 1) * 4
                            radius: imagesViewRoot.space(16)
                            color: index === 0 ? "#362d34" : "#2c252b"
                            border.width: 1
                            border.color: Qt.rgba(0.902, 0.843, 0.863, 0.06)
                            rotation: imagesViewEntry.hot ? (index === 0 ? -4 : 4) : (index === 0 ? -2 : 2)
                            z: -1 - index
                            Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                        }
                    }
                    Item {
                        anchors.fill: parent
                        anchors.margins: imagesViewRoot.space(6)
                        scale: imagesViewEntry.hot ? 1.025 : 1
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: imagesViewRoot.space(19)
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.alpha(Theme.accent, 0.55)
                            opacity: imagesViewEntry.hot ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: imagesViewRoot.space(16)
                            color: "#221c21"
                            Image {
                                id: imagesViewThumbnail
                                anchors.fill: parent
                                source: imagesViewEntry.modelData.url
                                sourceSize.width: 420
                                sourceSize.height: 300
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                scale: imagesViewEntry.hot ? 1.08 : 1
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 240 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: imagesViewThumbnail.status === Image.Error
                                text: "Image unavailable"
                                color: Theme.muted
                                font.pixelSize: imagesViewRoot.space(10)
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * 0.6
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 0.55; color: "#a6221c21" }
                                    GradientStop { position: 1; color: "#f2221c21" }
                                }
                            }
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: imagesViewRoot.space(8)
                                width: imagesViewBadge.implicitWidth + imagesViewRoot.space(14)
                                height: imagesViewRoot.space(20)
                                radius: height / 2
                                color: "#cc221c21"
                                border.width: 1
                                border.color: imagesViewEntry.modelData.isFolder ? Qt.alpha(Theme.accent, 0.5) : Qt.rgba(0.902, 0.843, 0.863, 0.12)
                                Text {
                                    id: imagesViewBadge
                                    anchors.centerIn: parent
                                    text: imagesViewEntry.modelData.isFolder ? "  " + imagesViewEntry.modelData.count : imagesViewEntry.modelData.name.split(".").pop().toUpperCase()
                                    color: imagesViewEntry.modelData.isFolder ? Theme.accent : Theme.foreground
                                    font.family: imagesViewEntry.modelData.isFolder ? "Symbols Nerd Font Mono" : "monospace"
                                    font.pixelSize: imagesViewRoot.space(9)
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.6
                                }
                            }
                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: imagesViewRoot.space(11)
                                anchors.bottomMargin: imagesViewEntry.hot ? imagesViewRoot.space(13) : imagesViewRoot.space(10)
                                spacing: imagesViewRoot.space(2)
                                Behavior on anchors.bottomMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Text {
                                    width: parent.width
                                    text: imagesViewEntry.modelData.name
                                    elide: Text.ElideMiddle
                                    textFormat: Text.PlainText
                                    color: "#e6d7dc"
                                    font.pixelSize: imagesViewRoot.space(imagesViewEntry.modelData.isFolder ? 12 : 10)
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    width: parent.width
                                    text: imagesViewEntry.modelData.isFolder ? imagesViewEntry.modelData.count + (imagesViewEntry.modelData.count === 1 ? " image" : " images") : (imagesViewEntry.modelData.size > 1048576 ? (imagesViewEntry.modelData.size / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(imagesViewEntry.modelData.size / 1024)) + " KB")
                                    color: Qt.alpha("#e6d7dc", 0.6)
                                    font.family: "monospace"
                                    font.pixelSize: imagesViewRoot.space(8)
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: imagesViewRoot.space(16)
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(0.902, 0.843, 0.863, imagesViewEntry.hot ? 0.18 : 0.08)
                            }
                        }
                    }
                    MouseArea {
                        id: imagesViewHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: imagesViewRoot.hoveredImage = imagesViewEntry.modelData.isFolder ? "" : imagesViewEntry.modelData.path
                        onExited: if (imagesViewRoot.hoveredImage === imagesViewEntry.modelData.path)
                            imagesViewRoot.hoveredImage = ""
                        Component.onDestruction: if (imagesViewRoot.hoveredImage === imagesViewEntry.modelData.path)
                            imagesViewRoot.hoveredImage = ""
                        onClicked: {
                            if (imagesViewEntry.modelData.isFolder) {
                                imagesViewRoot.openFolder(imagesViewEntry.modelData.path);
                            } else
                                imagesViewRoot.selected = imagesViewEntry.modelData.path;
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !imagesViewRoot.galleryEntries.length
                    text: imagesViewQuery.running ? "Loading…" : "Add images to ~/Pictures or ~/0/pictures"
                    color: Theme.muted
                    font.pixelSize: imagesViewRoot.space(13)
                }
            }
            Item {
                visible: !!imagesViewRoot.current
                anchors {
                    top: imagesViewHeader.bottom
                    bottom: imagesViewFooter.top
                    left: parent.left
                    right: parent.right
                    margins: imagesViewRoot.space(16)
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: imagesViewRoot.space(18)
                    color: "#221c21"
                    Image {
                        id: imagesViewAmbient
                        anchors.fill: parent
                        anchors.margins: -40
                        source: imagesViewRoot.current ? imagesViewRoot.current.url : ""
                        sourceSize.width: 96
                        sourceSize.height: 96
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: imagesViewAmbient
                        source: imagesViewAmbient
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 64
                        saturation: 0.2
                        brightness: -0.35
                        opacity: imagesViewAmbient.status === Image.Ready ? 0.9 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: imagesViewRoot.space(18)
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(0.902, 0.843, 0.863, 0.1)
                    }
                }
                Image {
                    id: imagesViewPreview
                    anchors.fill: parent
                    anchors.margins: imagesViewRoot.space(8)
                    source: imagesViewRoot.current ? imagesViewRoot.current.url : ""
                    sourceSize.width: Math.ceil(width * 2)
                    sourceSize.height: Math.ceil(height * 2)
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    cache: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: imagesViewPreview.status === Image.Error
                    text: "Could not preview this image."
                    color: Theme.muted
                }
                ImagesViewImageButton {
                    contextRoot: imagesViewRoot
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    onClicked: imagesViewRoot.step(-1)
                }
                ImagesViewImageButton {
                    contextRoot: imagesViewRoot
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    onClicked: imagesViewRoot.step(1)
                }
            }
            Item {
                id: imagesViewFooter
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: imagesViewRoot.space(20)
                }
                height: imagesViewRoot.space(30)
                Text {
                    anchors.left: parent.left
                    anchors.right: imagesViewExternal.left
                    anchors.rightMargin: imagesViewRoot.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: imagesViewRoot.current ? (imagesViewRoot.copyStatus || imagesViewRoot.current.name) : imagesViewRoot.error ? imagesViewRoot.error : imagesViewRoot.selectedFolder || "~/Pictures  ·  ~/0/pictures"
                    elide: Text.ElideMiddle
                    color: imagesViewRoot.copyStatus === "Image copied" ? "#d69aac" : imagesViewRoot.error && !imagesViewRoot.current ? "#d9737f" : Theme.muted
                    font.pixelSize: imagesViewRoot.space(11)
                }
                ImagesViewImageButton {
                    id: imagesViewExternal
                    contextRoot: imagesViewRoot
                    anchors.right: parent.right
                    visible: !!imagesViewRoot.current
                    text: "↗"
                    onClicked: {
                        if (imagesViewRoot.current) {
                            Quickshell.execDetached(["xdg-open", imagesViewRoot.current.path]);
                            imagesViewRoot.dismiss();
                        }
                    }
                }
            }
        }
    }

    component InlineVideoPlayerVideoButton: MediaButton {
        id: inlineVideoPlayerVideoButtonButton
        property bool primary: false
        property bool ghost: false
        implicitWidth: 36
        implicitHeight: 36
        opacity: enabled ? 1 : 0.35
        scale: pressed ? 0.9 : hovered && !primary ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        foreground: primary ? "#221c21" : hovered ? "#e6d7dc" : "#e6d7dc"
        background: Rectangle {
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: inlineVideoPlayerVideoButtonButton.primary ? "#d69aac" : inlineVideoPlayerVideoButtonButton.ghost && !inlineVideoPlayerVideoButtonButton.hovered ? "transparent" : inlineVideoPlayerVideoButtonButton.hovered ? "#3de6d7dc" : "#1fe6d7dc" }
                GradientStop { position: 1; color: inlineVideoPlayerVideoButtonButton.primary ? "#d69aac" : inlineVideoPlayerVideoButtonButton.ghost && !inlineVideoPlayerVideoButtonButton.hovered ? "transparent" : inlineVideoPlayerVideoButtonButton.hovered ? "#26e6d7dc" : "#0de6d7dc" }
            }
            border.width: inlineVideoPlayerVideoButtonButton.ghost && !inlineVideoPlayerVideoButtonButton.hovered ? 0 : 1
            border.color: inlineVideoPlayerVideoButtonButton.visualFocus ? "#d69aac" : inlineVideoPlayerVideoButtonButton.primary ? "#eee2e6" : "#33e6d7dc"
        }
    }

    component InlineVideoPlayerVideoSlider: Slider {
        id: inlineVideoPlayerVideoSliderSlider
        background: Rectangle {
            x: inlineVideoPlayerVideoSliderSlider.leftPadding
            y: inlineVideoPlayerVideoSliderSlider.topPadding + inlineVideoPlayerVideoSliderSlider.availableHeight / 2 - height / 2
            width: inlineVideoPlayerVideoSliderSlider.availableWidth
            height: inlineVideoPlayerVideoSliderSlider.hovered || inlineVideoPlayerVideoSliderSlider.pressed ? 6 : 4
            radius: height / 2
            color: "#26e6d7dc"
            Rectangle {
                width: inlineVideoPlayerVideoSliderSlider.visualPosition * parent.width
                height: parent.height
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#d4a5b5" }
                    GradientStop { position: 1; color: "#d69aac" }
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 100
                }
            }
        }
        handle: Rectangle {
            x: inlineVideoPlayerVideoSliderSlider.leftPadding + inlineVideoPlayerVideoSliderSlider.visualPosition * (inlineVideoPlayerVideoSliderSlider.availableWidth - width)
            y: inlineVideoPlayerVideoSliderSlider.topPadding + inlineVideoPlayerVideoSliderSlider.availableHeight / 2 - height / 2
            width: 14
            height: 14
            radius: 7
            color: "#e6d7dc"
            border.width: 3
            border.color: "#d69aac"
            opacity: inlineVideoPlayerVideoSliderSlider.hovered || inlineVideoPlayerVideoSliderSlider.pressed || inlineVideoPlayerVideoSliderSlider.visualFocus ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }

    component InlineVideoPlayer: Rectangle {
        id: inlineVideoPlayerRoot
        required property url sourceUrl
        property string title: ""
        property int queueIndex: -1
        property int queueCount: 0
        readonly property bool hasPrevious: queueIndex > 0
        readonly property bool hasNext: queueIndex >= 0 && queueIndex < queueCount - 1
        signal backRequested
        signal nextRequested
        signal previousRequested
        signal externalRequested
        signal playbackFinished
        property bool controlsVisible: true
        readonly property bool showControls: controlsVisible || inlineVideoPlayerPlayer.playbackState !== MediaPlayer.PlayingState || inlineVideoPlayerControlsHover.hovered || inlineVideoPlayerHeaderHover.hovered
        function revealControls() {
            controlsVisible = true;
            inlineVideoPlayerHideControls.restart();
        }
        Timer {
            id: inlineVideoPlayerHideControls
            interval: 900
            onTriggered: inlineVideoPlayerRoot.controlsVisible = false
        }
        color: "#221c21"
        radius: 12
        focus: true
        function togglePlayback() {
            if (inlineVideoPlayerPlayer.playbackState === MediaPlayer.PlayingState)
                inlineVideoPlayerPlayer.pause();
            else
                inlineVideoPlayerPlayer.play();
        }
        function seekBy(milliseconds) {
            if (!inlineVideoPlayerPlayer.seekable)
                return;
            inlineVideoPlayerPlayer.position = Math.max(0, Math.min(inlineVideoPlayerPlayer.duration, inlineVideoPlayerPlayer.position + milliseconds));
            inlineVideoPlayerRoot.revealControls();
        }
        function timestamp(milliseconds) {
            var seconds = Math.floor(Math.max(0, milliseconds) / 1000);
            return Math.floor(seconds / 60) + ":" + (seconds % 60 < 10 ? "0" : "") + seconds % 60;
        }
        Keys.onEscapePressed: inlineVideoPlayerRoot.backRequested()
        Keys.onSpacePressed: inlineVideoPlayerRoot.togglePlayback()
        Shortcut {
            sequence: "Left"
            context: Qt.WindowShortcut
            enabled: inlineVideoPlayerRoot.visible
            onActivated: inlineVideoPlayerRoot.seekBy(-5000)
        }
        Shortcut {
            sequence: "Right"
            context: Qt.WindowShortcut
            enabled: inlineVideoPlayerRoot.visible
            onActivated: inlineVideoPlayerRoot.seekBy(5000)
        }
        MediaPlayer {
            id: inlineVideoPlayerPlayer
            objectName: "inlineMediaPlayer"
            source: inlineVideoPlayerRoot.sourceUrl
            audioOutput: AudioOutput {
                id: inlineVideoPlayerAudio
                volume: 0.7
            }
            videoOutput: inlineVideoPlayerOutput
            onPlaybackStateChanged: {
                if (playbackState === MediaPlayer.PlayingState) {
                    inlineVideoPlayerRoot.controlsVisible = true;
                    inlineVideoPlayerHideControls.interval = 650;
                    inlineVideoPlayerHideControls.restart();
                } else {
                    inlineVideoPlayerRoot.controlsVisible = true;
                    inlineVideoPlayerHideControls.stop();
                }
            }
            onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia)
                inlineVideoPlayerRoot.playbackFinished()
            Component.onCompleted: play()
            Component.onDestruction: stop()
        }
        VideoOutput {
            id: inlineVideoPlayerOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: {
                inlineVideoPlayerHideControls.interval = 900;
                inlineVideoPlayerRoot.revealControls();
            }
            onClicked: {
                inlineVideoPlayerRoot.forceActiveFocus();
                inlineVideoPlayerRoot.togglePlayback();
                inlineVideoPlayerRoot.revealControls();
            }
        }
        Item {
            id: inlineVideoPlayerHeaderControls
            width: parent.width
            height: 72
            opacity: inlineVideoPlayerRoot.showControls ? 1 : 0
            visible: opacity > 0
            enabled: inlineVideoPlayerRoot.showControls
            Behavior on opacity { NumberAnimation { duration: 160 } }
            HoverHandler {
                id: inlineVideoPlayerHeaderHover
                onHoveredChanged: if (hovered)
                    inlineVideoPlayerRoot.revealControls()
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#e6221c21" }
                    GradientStop { position: 1; color: "#00221c21" }
                }
            }
            InlineVideoPlayerVideoButton {
                id: inlineVideoPlayerBackButton
                objectName: "videoBack"
                x: 16
                y: 14
                text: ""
                fontFamily: "Symbols Nerd Font Mono"
                fontSize: 13
                Accessible.name: "Back to videos"
                onClicked: inlineVideoPlayerRoot.backRequested()
            }
            Column {
                anchors.left: inlineVideoPlayerBackButton.right
                anchors.right: inlineVideoPlayerQueueBadge.left
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: inlineVideoPlayerBackButton.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    text: inlineVideoPlayerRoot.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: "#e6d7dc"
                    font.family: "sans-serif"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "Space play · ← → seek · P / N previous / next"
                    color: "#99e6d7dc"
                    font.family: "sans-serif"
                    font.pixelSize: 10
                }
            }
            Rectangle {
                id: inlineVideoPlayerQueueBadge
                visible: inlineVideoPlayerRoot.queueCount > 1
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: inlineVideoPlayerBackButton.verticalCenter
                width: visible ? inlineVideoPlayerQueueText.implicitWidth + 20 : 0
                height: 26
                radius: 13
                color: "#cc221c21"
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.5)
                Text {
                    id: inlineVideoPlayerQueueText
                    anchors.centerIn: parent
                    text: (inlineVideoPlayerRoot.queueIndex + 1) + " / " + inlineVideoPlayerRoot.queueCount
                    color: Theme.accent
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
        }
        Repeater {
            model: [-1, 1]
            Item {
                id: inlineVideoPlayerSideNav
                required property int modelData
                readonly property bool available: modelData < 0 ? inlineVideoPlayerRoot.hasPrevious : inlineVideoPlayerRoot.hasNext
                anchors.verticalCenter: parent.verticalCenter
                x: modelData < 0 ? 18 : parent.width - width - 18
                width: 52
                height: 52
                opacity: inlineVideoPlayerRoot.showControls && available ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: inlineVideoPlayerSideHit.containsMouse ? "#4d221c21" : "#99221c21"
                    border.width: 1
                    border.color: inlineVideoPlayerSideHit.containsMouse ? Qt.alpha(Theme.accent, 0.8) : "#33e6d7dc"
                    scale: inlineVideoPlayerSideHit.pressed ? 0.9 : inlineVideoPlayerSideHit.containsMouse ? 1.1 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: inlineVideoPlayerSideNav.modelData < 0 ? -1 : 1
                        text: inlineVideoPlayerSideNav.modelData < 0 ? "" : ""
                        color: inlineVideoPlayerSideHit.containsMouse ? Theme.accent : "#e6d7dc"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 18
                    }
                }
                MouseArea {
                    id: inlineVideoPlayerSideHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: inlineVideoPlayerRoot.revealControls()
                    onClicked: {
                        if (inlineVideoPlayerSideNav.modelData < 0)
                            inlineVideoPlayerRoot.previousRequested();
                        else
                            inlineVideoPlayerRoot.nextRequested();
                    }
                }
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 460)
            height: inlineVideoPlayerPlaybackError.implicitHeight + 28
            radius: 12
            color: "#e0221c21"
            visible: inlineVideoPlayerPlayer.error !== MediaPlayer.NoError
            Text {
                id: inlineVideoPlayerPlaybackError
                anchors.centerIn: parent
                width: parent.width - 28
                text: inlineVideoPlayerPlayer.errorString || "Could not play this video."
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: "#d9737f"
                font.pixelSize: 12
            }
        }
        BusyIndicator {
            anchors.centerIn: parent
            running: inlineVideoPlayerPlayer.position === 0 && (inlineVideoPlayerPlayer.mediaStatus === MediaPlayer.LoadingMedia || inlineVideoPlayerPlayer.mediaStatus === MediaPlayer.BufferingMedia)
            visible: running
        }
        Rectangle {
            id: inlineVideoPlayerControls
            objectName: "videoControls"
            opacity: inlineVideoPlayerRoot.showControls ? 1 : 0
            visible: opacity > 0
            enabled: inlineVideoPlayerRoot.showControls
            Behavior on opacity { NumberAnimation { duration: 160 } }
            HoverHandler {
                id: inlineVideoPlayerControlsHover
                onHoveredChanged: if (hovered)
                    inlineVideoPlayerRoot.revealControls()
            }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: inlineVideoPlayerRoot.showControls ? 18 : 6
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            width: Math.min(680, parent.width - 36)
            height: 92
            radius: 26
            gradient: Gradient {
                GradientStop { position: 0; color: "#e62c252b" }
                GradientStop { position: 1; color: "#f2221c21" }
            }
            border.width: 1
            border.color: "#26e6d7dc"
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.5
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(Theme.accent, 0.7) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            Text {
                id: inlineVideoPlayerElapsed
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: inlineVideoPlayerProgress.verticalCenter
                text: inlineVideoPlayerRoot.timestamp(inlineVideoPlayerPlayer.position)
                color: "#e6d7dc"
                font.family: "monospace"
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            Text {
                id: inlineVideoPlayerTotal
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: inlineVideoPlayerProgress.verticalCenter
                text: inlineVideoPlayerRoot.timestamp(inlineVideoPlayerPlayer.duration)
                color: "#99e6d7dc"
                font.family: "monospace"
                font.pixelSize: 11
            }
            InlineVideoPlayerVideoSlider {
                id: inlineVideoPlayerProgress
                objectName: "videoProgress"
                anchors.left: inlineVideoPlayerElapsed.right
                anchors.right: inlineVideoPlayerTotal.left
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                y: 8
                height: 26
                from: 0
                to: Math.max(1, inlineVideoPlayerPlayer.duration)
                value: inlineVideoPlayerPlayer.position
                enabled: inlineVideoPlayerPlayer.seekable
                onMoved: inlineVideoPlayerPlayer.position = value
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 40
                spacing: 8
                InlineVideoPlayerVideoButton {
                    objectName: "videoPrevious"
                    anchors.verticalCenter: parent.verticalCenter
                    ghost: true
                    text: ""
                    fontFamily: "Symbols Nerd Font Mono"
                    fontSize: 13
                    enabled: inlineVideoPlayerRoot.hasPrevious
                    Accessible.name: "Previous video (P)"
                    onClicked: inlineVideoPlayerRoot.previousRequested()
                }
                InlineVideoPlayerVideoButton {
                    id: inlineVideoPlayerRewindButton
                    objectName: "videoRewind"
                    anchors.verticalCenter: parent.verticalCenter
                    ghost: true
                    text: "󰝲"
                    fontFamily: "Symbols Nerd Font Mono"
                    fontSize: 16
                    enabled: inlineVideoPlayerPlayer.seekable
                    Accessible.name: "Rewind 5 seconds"
                    onClicked: inlineVideoPlayerRoot.seekBy(-5000)
                }
                InlineVideoPlayerVideoButton {
                    id: inlineVideoPlayerPlayButton
                    objectName: "videoPlayPause"
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 44
                    implicitHeight: 44
                    primary: true
                    text: inlineVideoPlayerPlayer.playbackState === MediaPlayer.PlayingState ? "" : ""
                    fontFamily: "Symbols Nerd Font Mono"
                    Accessible.name: inlineVideoPlayerPlayer.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play"
                    onClicked: inlineVideoPlayerRoot.togglePlayback()
                }
                InlineVideoPlayerVideoButton {
                    id: inlineVideoPlayerForwardButton
                    objectName: "videoForward"
                    anchors.verticalCenter: parent.verticalCenter
                    ghost: true
                    text: "󰝵"
                    fontFamily: "Symbols Nerd Font Mono"
                    fontSize: 16
                    enabled: inlineVideoPlayerPlayer.seekable
                    Accessible.name: "Forward 5 seconds"
                    onClicked: inlineVideoPlayerRoot.seekBy(5000)
                }
                InlineVideoPlayerVideoButton {
                    id: inlineVideoPlayerNextButton
                    objectName: "videoNext"
                    anchors.verticalCenter: parent.verticalCenter
                    ghost: true
                    text: ""
                    fontFamily: "Symbols Nerd Font Mono"
                    fontSize: 13
                    enabled: inlineVideoPlayerRoot.hasNext
                    Accessible.name: "Next video (N)"
                    onClicked: inlineVideoPlayerRoot.nextRequested()
                }
            }
            InlineVideoPlayerVideoButton {
                id: inlineVideoPlayerMuteButton
                objectName: "videoMute"
                anchors.left: parent.left
                anchors.leftMargin: 14
                y: 44
                ghost: true
                text: inlineVideoPlayerAudio.muted ? "" : ""
                fontFamily: "Symbols Nerd Font Mono"
                fontSize: 13
                Accessible.name: inlineVideoPlayerAudio.muted ? "Unmute" : "Mute"
                onClicked: inlineVideoPlayerAudio.muted = !inlineVideoPlayerAudio.muted
            }
            InlineVideoPlayerVideoSlider {
                id: inlineVideoPlayerVolume
                objectName: "videoVolume"
                anchors.left: inlineVideoPlayerMuteButton.right
                anchors.leftMargin: 4
                anchors.verticalCenter: inlineVideoPlayerMuteButton.verticalCenter
                width: Math.min(90, parent.width * 0.16)
                from: 0
                to: 1
                value: inlineVideoPlayerAudio.volume
                opacity: inlineVideoPlayerAudio.muted ? 0.4 : 1
                onMoved: inlineVideoPlayerAudio.volume = value
                Accessible.name: "Video volume"
            }
            InlineVideoPlayerVideoButton {
                objectName: "videoExternal"
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 44
                ghost: true
                text: ""
                fontFamily: "Symbols Nerd Font Mono"
                fontSize: 12
                Accessible.name: "Open in mpv (M)"
                onClicked: inlineVideoPlayerRoot.externalRequested()
            }
        }
    }

    component MediaButton: Button {
        id: mediaButtonButton
        property color foreground: Theme.foreground
        property color accent: Theme.accent
        property bool selected: false
        property string fontFamily: "sans-serif"
        property real fontSize: 12
        property bool focusable: true
        focusPolicy: focusable ? Qt.StrongFocus : Qt.NoFocus
        implicitWidth: Math.max(32, contentItem.implicitWidth + 20)
        implicitHeight: 32
        contentItem: Text {
            text: mediaButtonButton.text
            color: mediaButtonButton.foreground
            font.family: mediaButtonButton.fontFamily
            font.pixelSize: mediaButtonButton.fontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            color: mediaButtonButton.selected || mediaButtonButton.hovered ? Theme.hover : Theme.surface
            border.width: mediaButtonButton.selected ? 1 : 0
            border.color: mediaButtonButton.accent
        }
    }

    component PanelSlider: Item {
        id: panelSliderRoot
        property var bar: null
        property real minimum: 0
        property real maximum: 100
        property real value: 0
        property real trackHeight: 3
        property real knobSize: 10
        property color fillColor: Theme.accent
        property color knobColor: Theme.foreground
        property color trackColor: Theme.track
        readonly property bool dragging: panelSliderSlider.pressed
        readonly property real liveValue: panelSliderSlider.value
        signal released(real value)
        Slider {
            id: panelSliderSlider
            anchors.fill: parent
            from: panelSliderRoot.minimum
            to: panelSliderRoot.maximum
            value: panelSliderRoot.value
            onPressedChanged: if (!pressed)
                panelSliderRoot.released(value)
            background: Rectangle {
                x: panelSliderSlider.leftPadding
                y: panelSliderSlider.topPadding + panelSliderSlider.availableHeight / 2 - height / 2
                width: panelSliderSlider.availableWidth
                height: panelSliderRoot.trackHeight
                radius: height / 2
                color: panelSliderRoot.trackColor
                Rectangle {
                    width: panelSliderSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: panelSliderRoot.fillColor
                }
            }
            handle: Rectangle {
                x: panelSliderSlider.leftPadding + panelSliderSlider.visualPosition * (panelSliderSlider.availableWidth - width)
                y: panelSliderSlider.topPadding + panelSliderSlider.availableHeight / 2 - height / 2
                width: panelSliderRoot.knobSize
                height: width
                radius: width / 2
                color: panelSliderRoot.knobColor
            }
        }
    }

    component PlayerViewArtwork: ClippingRectangle {
        id: playerViewArtworkArtworkRoot
        property url source: ""
        property color tint: "#362d34"
        color: tint
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(playerViewArtworkArtworkRoot.tint, 1.35)
                }
                GradientStop {
                    position: 1
                    color: Qt.darker(playerViewArtworkArtworkRoot.tint, 1.8)
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: playerViewArtworkArtImage.status !== Image.Ready
            text: "♫"
            color: Theme.foreground
            opacity: 0.55
            font.pixelSize: parent.width * 0.32
        }
        Image {
            id: playerViewArtworkArtImage
            anchors.fill: parent
            source: playerViewArtworkArtworkRoot.source
            sourceSize.width: Math.ceil(width * 2)
            sourceSize.height: Math.ceil(height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    component PlayerViewIconButton: Rectangle {
        id: playerViewIconButtonControl
        required property var contextRoot
        property string text
        property bool primary: false
        property bool checkable: false
        property bool checked: false
        Accessible.role: checkable ? Accessible.CheckBox : Accessible.Button
        Accessible.checked: checked
        readonly property bool hovered: playerViewIconButtonHit.containsMouse
        property int size: 32
        signal clicked
        width: contextRoot.space(size)
        height: width
        radius: width / 2
        activeFocusOnTab: true
        color: checked ? "#45393f" : primary ? (playerViewIconButtonHit.containsMouse ? Theme.accent : contextRoot.accentColor) : Qt.rgba(0.902, 0.843, 0.863, playerViewIconButtonHit.containsMouse || activeFocus ? 0.09 : 0)
        scale: playerViewIconButtonHit.pressed ? 0.94 : 1
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
        Text {
            anchors.centerIn: parent
            text: playerViewIconButtonControl.text
            color: playerViewIconButtonControl.checked ? contextRoot.secondaryColor : playerViewIconButtonControl.primary ? Theme.background : "#e6d7dc"
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: contextRoot.space(playerViewIconButtonControl.primary ? 18 : 14)
        }
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        MouseArea {
            id: playerViewIconButtonHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: playerViewIconButtonControl.clicked()
        }
    }

    component PlayerView: Item {
        id: playerViewRoot
        function space(value) {
            return value;
        }
        property QtObject bar: null
        property string moduleName: "y.music"
        property var settings: ({})
        property var shell: null
        property var manifest: null
        readonly property color accentColor: Theme.accent
        readonly property color secondaryColor: Theme.accent
        readonly property color textColor: Theme.foreground
        signal dismissed
        property bool opened: false
        property bool autoPlay: true
        property string pendingArtist: ""
        property var libraryTracks: []
        property string librarySignature: ""
        property bool libraryReloadPending: false
        property string deletingPath: ""
        property string deletionError: ""
        property string playbackError: ""
        property string filterType: ""
        property string filterValue: ""
        property string filterFolder: ""
        property string artistContext: ""
        readonly property string artistQuery: playerViewArtistSearch.text.trim().toLowerCase()
        readonly property var artistEntries: {
            var groups = Object.create(null);
            libraryTracks.forEach(function (track) {
                var name = track.artist || "—";
                if (!groups[name])
                    groups[name] = {
                        artist: name,
                        cover: "",
                        count: 0
                    };
                groups[name].count += 1;
                if (!groups[name].cover && track.cover)
                    groups[name].cover = track.cover;
            });
            return Object.keys(groups).map(function (name) {
                return groups[name];
            }).sort(function (a, b) {
                return b.count - a.count || a.artist.localeCompare(b.artist);
            });
        }
        readonly property var filteredArtists: artistEntries.filter(function (playerViewEntry) {
            return !playerViewRoot.artistQuery || playerViewEntry.artist.toLowerCase().indexOf(playerViewRoot.artistQuery) >= 0;
        })
        readonly property var folderEntries: {
            var groups = Object.create(null);
            libraryTracks.forEach(function (track) {
                var folder = track.path.slice(0, track.path.lastIndexOf("/"));
                if (!groups[folder])
                    groups[folder] = {
                        folder: folder,
                        name: folder.split("/").pop(),
                        cover: "",
                        count: 0
                    };
                groups[folder].count++;
                if (!groups[folder].cover && track.cover)
                    groups[folder].cover = track.cover;
            });
            return Object.keys(groups).map(function (folder) {
                return groups[folder];
            }).filter(function (playerViewEntry) {
                return !playerViewRoot.artistQuery || playerViewEntry.name.toLowerCase().indexOf(playerViewRoot.artistQuery) >= 0;
            }).sort(function (a, b) {
                return a.name.localeCompare(b.name) || a.folder.localeCompare(b.folder);
            });
        }
        readonly property var trackRows: {
            if (playerViewRoot.filterType === "album" || playerViewRoot.filterType === "folder")
                return playerViewRoot.visibleTracks;
            var rows = [];
            var previous = null;
            playerViewRoot.visibleTracks.forEach(function (track) {
                var group = playerViewRoot.filterType === "all" ? (track.artist || "—") : (track.album || "Singles");
                if (group !== previous) {
                    rows.push({
                        header: true,
                        title: group
                    });
                    previous = group;
                }
                rows.push(track);
            });
            return rows;
        }
        readonly property var visibleTracks: libraryTracks.filter(function (track) {
            if (playerViewRoot.artistQuery && [track.artist, track.title, track.path.slice(0, track.path.lastIndexOf("/"))].join(" ").toLowerCase().indexOf(playerViewRoot.artistQuery) < 0)
                return false;
            if (playerViewRoot.filterType === "folder")
                return track.path.slice(0, track.path.lastIndexOf("/")) === playerViewRoot.filterFolder;
            if (playerViewRoot.filterType === "artist")
                return (track.artist || "—") === playerViewRoot.filterValue;
            if (playerViewRoot.filterType === "album")
                return track.album === playerViewRoot.filterValue && track.path.slice(0, track.path.lastIndexOf("/")) === playerViewRoot.filterFolder;
            return true;
        }).sort(function (a, b) {
            if (playerViewRoot.filterType === "folder")
                return (a.track || Infinity) - (b.track || Infinity) || a.title.localeCompare(b.title, undefined, {
                    numeric: true
                }) || a.path.localeCompare(b.path);
            var artist = (a.artist || "—").localeCompare(b.artist || "—");
            if (artist)
                return artist;
            var album = (a.album || "").localeCompare(b.album || "");
            if (album)
                return album;
            var first = a.track || 0;
            var second = b.track || 0;
            if (first !== second)
                return (first || Infinity) - (second || Infinity);
            return a.title.localeCompare(b.title) || a.path.localeCompare(b.path);
        })
        property var localState: ({
                tracks: [],
                title: "Music",
                artist: "",
                path: "",
                paused: true,
                position: 0,
                duration: 0,
                volume: 60,
                cover: ""
            })
        property string controlledExternalName: ""
        readonly property var externalPlayer: {
            var players = Mpris.players.values.filter(function (player) {
                var name = String(player.dbusName || "");
                return name.indexOf("y_music") < 0 && name.indexOf("playerctld") < 0 && (player.isPlaying || name === playerViewRoot.controlledExternalName);
            });
            var playing = players.filter(function (player) {
                return player.isPlaying;
            });
            var candidates = playing.length ? playing : players;
            return localState.path && !localState.paused ? null : candidates.length ? candidates[0] : null;
        }
        property real externalPosition: 0
        readonly property var state: externalPlayer ? {
            tracks: [],
            title: externalPlayer.trackTitle || externalPlayer.identity,
            artist: externalPlayer.trackArtist || externalPlayer.identity,
            path: "external:" + externalPlayer.dbusName,
            paused: !externalPlayer.isPlaying,
            position: externalPosition,
            duration: externalPlayer.lengthSupported ? externalPlayer.length : 0,
            volume: externalPlayer.volumeSupported ? externalPlayer.volume * 100 : 0,
            cover: externalPlayer.trackArtUrl || "",
            shuffle: false
        } : localState
        function updateExternalPosition() {
            externalPosition = externalPlayer && externalPlayer.positionSupported ? externalPlayer.position : 0;
        }
        onExternalPlayerChanged: updateExternalPosition()
        readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/player.py"
        function open(payload) {
            opened = true;
            if (!playerViewPreferencesQuery.running && !playerViewPreferencesSave.running)
                playerViewPreferencesQuery.running = true;
            refresh();
            refreshLibrary();
            if (autoPlay && !playerViewAction.running && !externalPlayer)
                run("random-if-idle");
            Qt.callLater(function () {
                playerViewCard.forceActiveFocus();
            });
        }
        function close() {
            opened = false;
        }
        function playArtist(name) {
            filter("artist", name);
            if (playerViewAction.running)
                pendingArtist = name;
            else
                run("play-artist", name);
        }
        function showAll() {
            playerViewArtistSearch.text = "";
            filter("all", "");
        }
        function toggleAutoPlay() {
            if (playerViewPreferencesSave.running)
                return;
            autoPlay = !autoPlay;
            playerViewPreferencesSave.command = ["python3", script, "autoplay", autoPlay ? "on" : "off"];
            playerViewPreferencesSave.running = true;
        }
        function dismiss() {
            opened = false;
            dismissed();
        }
        function deleteTrack(track) {
            if (playerViewDeleter.running || !track || !track.path)
                return false;
            deletionError = "";
            deletingPath = track.path;
            playerViewDeleter.running = true;
            return true;
        }
        function toggle() {
            if (opened)
                dismiss();
            else
                open("{}");
        }
        function refresh() {
            if (!playerViewQuery.running)
                playerViewQuery.running = true;
        }
        function refreshLibrary() {
            if (playerViewLibraryQuery.running)
                libraryReloadPending = true;
            else
                playerViewLibraryQuery.running = true;
        }
        function filter(type, value, folder) {
            if (type === "artist")
                artistContext = value;
            else if (!type || type === "all")
                artistContext = "";
            filterType = type;
            filterValue = value || "";
            filterFolder = folder || "";
            playerViewLibrary.positionViewAtBeginning();
        }
        function back() {
            if (filterType === "album" && filterFolder)
                filter("folder", filterFolder.split("/").pop(), filterFolder);
            else if (filterType === "album" && artistContext)
                filter("artist", artistContext);
            else
                filter("", "");
        }
        function changeArtist(direction, horizontal) {
            if (filterType === "folder") {
                var folderIndex = folderEntries.findIndex(function (playerViewEntry) {
                    return playerViewEntry.folder === playerViewRoot.filterFolder;
                });
                if (folderIndex < 0 || folderEntries.length < 2)
                    return false;
                var folder = folderEntries[(folderIndex + direction + folderEntries.length) % folderEntries.length];
                filter("folder", folder.name, folder.folder);
                return true;
            }
            var currentArtist = filterType === "artist" ? filterValue : filterType === "album" ? artistContext : "";
            if (!currentArtist)
                return false;
            var index = filteredArtists.findIndex(function (playerViewEntry) {
                return playerViewEntry.artist === currentArtist;
            });
            if (index < 0 || filteredArtists.length < 2)
                return false;
            var next = (index + direction + filteredArtists.length) % filteredArtists.length;
            filter("artist", filteredArtists[next].artist);
            Qt.callLater(function () {
                playerViewLibrary.forceLayout();
                if (direction < 0 && !horizontal)
                    playerViewLibrary.positionViewAtEnd();
                else
                    playerViewLibrary.positionViewAtBeginning();
            });
            return true;
        }
        function run(command, value) {
            if (externalPlayer) {
                if (command === "random-if-idle")
                    return;
                if (command === "toggle") {
                    controlledExternalName = externalPlayer.dbusName;
                    externalPlayer.togglePlaying();
                    return;
                }
                if (command === "next") {
                    if (externalPlayer.canGoNext)
                        externalPlayer.next();
                    return;
                }
                if (command === "previous") {
                    if (externalPlayer.canGoPrevious)
                        externalPlayer.previous();
                    return;
                }
                if (command === "seek") {
                    if (externalPlayer.canSeek && externalPlayer.positionSupported)
                        externalPlayer.position = Math.max(0, Number(value));
                    return;
                }
                if (command === "volume") {
                    if (externalPlayer.volumeSupported)
                        externalPlayer.volume = Math.max(0, Math.min(1, Number(value) / 100));
                    return;
                }
                if (command === "shuffle")
                    return;
            }
            if (playerViewAction.running)
                return;
            playbackError = "";
            var args = ["python3", script, command];
            if (value !== undefined)
                args.push(String(value));
            if (command === "play-artist")
                args.push(JSON.stringify(artistEntries.map(function (playerViewEntry) {
                    return playerViewEntry.artist;
                })));
            playerViewAction.command = args;
            playerViewAction.running = true;
        }
        function clock(seconds) {
            var value = Math.max(0, Math.floor(seconds || 0));
            var hours = Math.floor(value / 3600);
            var minutes = Math.floor(value / 60) % 60;
            var secs = value % 60;
            return (hours > 0 ? hours + ":" + (minutes < 10 ? "0" : "") : "") + minutes + ":" + (secs < 10 ? "0" : "") + secs;
        }

        Component.onCompleted: playerViewPreferencesQuery.running = true
        Process {
            id: playerViewPreferencesQuery
            command: ["python3", playerViewRoot.script, "preferences"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        if (!playerViewPreferencesSave.running)
                            playerViewRoot.autoPlay = JSON.parse(text).autoplay;
                    } catch (e) {}
                }
            }
        }
        Process {
            id: playerViewPreferencesSave
            onExited: if (!playerViewPreferencesQuery.running)
                playerViewPreferencesQuery.running = true
        }
        Process {
            id: playerViewQuery
            command: ["python3", playerViewRoot.script, "state-fast"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        playerViewRoot.localState = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
        Process {
            id: playerViewLibraryQuery
            command: ["python3", playerViewRoot.script, "library"]
            onExited: {
                if (playerViewRoot.libraryReloadPending) {
                    playerViewRoot.libraryReloadPending = false;
                    Qt.callLater(function () {
                        playerViewLibraryQuery.running = true;
                    });
                }
            }
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var tracks = JSON.parse(text);
                        var signature = JSON.stringify(tracks);
                        if (signature !== playerViewRoot.librarySignature) {
                            playerViewRoot.librarySignature = signature;
                            playerViewRoot.libraryTracks = tracks;
                        }
                    } catch (e) {}
                }
            }
        }
        Process {
            id: playerViewDeleter
            command: ["python3", playerViewRoot.script, "delete", playerViewRoot.deletingPath]
            stderr: StdioCollector {
                onStreamFinished: if (text.trim())
                    playerViewRoot.deletionError = text.trim()
            }
            onExited: function (exitCode) {
                if (exitCode === 0) {
                    playerViewRoot.libraryTracks = playerViewRoot.libraryTracks.filter(function (track) {
                        return track.path !== playerViewRoot.deletingPath;
                    });
                    playerViewRoot.librarySignature = "";
                    if (playerViewRoot.filterType && !playerViewRoot.visibleTracks.length)
                        playerViewRoot.filter("", "");
                    playerViewRoot.refreshLibrary();
                    playerViewRoot.refresh();
                } else {
                    if (!playerViewRoot.deletionError)
                        playerViewRoot.deletionError = "Could not delete file.";
                    playerViewDeletionNoticeTimer.restart();
                }
            }
        }
        Timer {
            id: playerViewDeletionNoticeTimer
            interval: 6000
            onTriggered: {
                playerViewRoot.deletionError = "";
                playerViewRoot.playbackError = "";
            }
        }
        Timer {
            interval: 8000
            running: playerViewRoot.opened
            repeat: true
            onTriggered: playerViewRoot.refreshLibrary()
        }
        Process {
            id: playerViewAction
            stderr: StdioCollector {
                onStreamFinished: if (text.trim())
                    playerViewRoot.playbackError = text.trim()
            }
            onExited: function (exitCode) {
                if (exitCode !== 0) {
                    if (!playerViewRoot.playbackError)
                        playerViewRoot.playbackError = "Could not start playback.";
                    playerViewDeletionNoticeTimer.restart();
                }
                playerViewRoot.refresh();
                if (playerViewRoot.pendingArtist) {
                    var name = playerViewRoot.pendingArtist;
                    playerViewRoot.pendingArtist = "";
                    Qt.callLater(function () {
                        playerViewRoot.run("play-artist", name);
                    });
                }
            }
        }
        Timer {
            interval: 1000
            running: playerViewRoot.opened
            repeat: true
            onTriggered: {
                playerViewRoot.refresh();
                playerViewRoot.updateExternalPosition();
            }
        }

        Rectangle {
            id: playerViewCard
            anchors.fill: parent
            radius: playerViewRoot.space(18)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.surface
                }
                GradientStop {
                    position: 1
                    color: Theme.background
                }
            }
            border.width: 1
            border.color: Qt.rgba(0.878, 0.667, 0.733, 0.10)
            focus: true
            Keys.onEscapePressed: playerViewRoot.dismiss()
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Item {
                id: playerViewHero
                x: playerViewRoot.space(28)
                y: playerViewRoot.space(28)
                width: Math.min(playerViewRoot.space(280), playerViewCard.width * 0.37, Math.max(140, playerViewCard.height - playerViewRoot.space(246)))
                height: Math.max(playerViewRoot.space(150), playerViewCard.height - playerViewRoot.space(168))
                Rectangle {
                    x: 5
                    y: 10
                    width: playerViewHero.width - 10
                    height: playerViewHero.width
                    radius: 16
                    color: "#60000000"
                }
                PlayerViewArtwork {
                    width: playerViewHero.width
                    height: width
                    source: playerViewRoot.state.cover || ""
                    radius: playerViewRoot.space(14)
                    tint: "#362d34"
                }
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: playerViewHero.width + playerViewRoot.space(22)
                    spacing: playerViewRoot.space(9)
                    Text {
                        width: parent.width
                        text: playerViewRoot.state.path ? playerViewRoot.state.title.replace(/\s*\[[A-Za-z0-9_-]{11}\]$/, "") : ""
                        color: "#e6d7dc"
                        font.family: "sans-serif"
                        font.pixelSize: playerViewRoot.space(22)
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.6
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: playerViewRoot.state.artist || ""
                        color: playerViewHeroArtistHit.containsMouse ? playerViewRoot.accentColor : Theme.muted
                        font.family: "sans-serif"
                        font.pixelSize: playerViewRoot.space(12)
                        elide: Text.ElideRight
                        MouseArea {
                            id: playerViewHeroArtistHit
                            anchors.fill: parent
                            enabled: !!playerViewRoot.state.artist
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerViewRoot.playArtist(playerViewRoot.state.artist)
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    property real wheelDistance: 0
                    property double lastWheelTime: 0
                    onWheel: function (wheel) {
                        var delta = wheel.pixelDelta.y ? wheel.pixelDelta.y * 3 : wheel.angleDelta.y;
                        if (!delta) {
                            wheel.accepted = false;
                            return;
                        }
                        wheel.accepted = true;
                        if (playerViewScrollCooldown.running || playerViewAction.running) {
                            wheelDistance = 0;
                            return;
                        }
                        var now = Date.now();
                        if (now - lastWheelTime > 300 || wheelDistance * delta < 0)
                            wheelDistance = 0;
                        lastWheelTime = now;
                        wheelDistance += delta;
                        if (Math.abs(wheelDistance) >= 120) {
                            playerViewRoot.run(wheelDistance > 0 ? "previous" : "next");
                            wheelDistance = 0;
                            playerViewScrollCooldown.restart();
                        }
                    }
                    Timer {
                        id: playerViewScrollCooldown
                        interval: 200
                    }
                }
            }

            Item {
                id: playerViewCollection
                x: playerViewHero.x + playerViewHero.width + playerViewRoot.space(32)
                y: playerViewHero.y
                width: parent.width - x - playerViewRoot.space(28)
                height: Math.max(150, playerViewCard.height - playerViewRoot.space(168))
                Item {
                    id: playerViewNavigation
                    width: parent.width
                    height: playerViewRoot.space(30)
                    PlayerViewIconButton {
                        id: playerViewBackButton
                        contextRoot: playerViewRoot
                        visible: !!playerViewRoot.filterType
                        size: 28
                        text: "\uf104"
                        onClicked: playerViewRoot.back()
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: playerViewRoot.filterType ? playerViewRoot.space(36) : 0
                        anchors.right: playerViewTrackCount.left
                        anchors.rightMargin: playerViewRoot.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: playerViewRoot.filterValue || "Folders"
                        color: "#e6d7dc"
                        font.family: "sans-serif"
                        font.pixelSize: playerViewRoot.space(18)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        id: playerViewTrackCount
                        anchors.right: playerViewAllButton.left
                        anchors.rightMargin: playerViewRoot.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: playerViewRoot.visibleTracks.length + (playerViewRoot.visibleTracks.length === 1 ? " track" : " tracks")
                        color: Theme.muted
                        font.family: "sans-serif"
                        font.pixelSize: playerViewRoot.space(10)
                    }
                    Rectangle {
                        id: playerViewAllButton
                        anchors.right: playerViewAutoPlayButton.left
                        anchors.rightMargin: playerViewRoot.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        width: playerViewRoot.space(62)
                        height: playerViewRoot.space(28)
                        radius: playerViewRoot.space(8)
                        color: playerViewRoot.filterType === "all" ? "#45393f" : playerViewAllHit.containsMouse || activeFocus ? "#2c252b" : "#2c252b"
                        activeFocusOnTab: true
                        Text {
                            anchors.centerIn: parent
                            text: "All"
                            color: playerViewRoot.textColor
                            font.family: "sans-serif"
                            font.pixelSize: playerViewRoot.space(11)
                            font.weight: Font.DemiBold
                        }
                        Keys.onReturnPressed: playerViewRoot.showAll()
                        Keys.onSpacePressed: playerViewRoot.showAll()
                        MouseArea {
                            id: playerViewAllHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerViewRoot.showAll()
                        }
                    }
                    Rectangle {
                        id: playerViewAutoPlayButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: playerViewRoot.space(28)
                        height: width
                        radius: playerViewRoot.space(8)
                        color: playerViewRoot.autoPlay ? Theme.hover : Theme.surface
                        border.width: playerViewRoot.autoPlay ? 1 : 0
                        border.color: Theme.accent
                        enabled: !playerViewPreferencesSave.running
                        opacity: enabled ? 1 : 0.5
                        activeFocusOnTab: true
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Autoplay on open"
                        Accessible.checked: playerViewRoot.autoPlay
                        Keys.onReturnPressed: playerViewRoot.toggleAutoPlay()
                        Keys.onSpacePressed: playerViewRoot.toggleAutoPlay()
                        Text {
                            anchors.centerIn: parent
                            text: playerViewRoot.autoPlay ? "\uf14a" : "\uf096"
                            color: playerViewRoot.autoPlay ? Theme.accent : Theme.muted
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: playerViewRoot.space(15)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerViewRoot.toggleAutoPlay()
                        }
                    }
                }
                Rectangle {
                    id: playerViewArtistSearchBox
                    anchors.top: playerViewNavigation.bottom
                    anchors.topMargin: playerViewRoot.space(8)
                    width: parent.width
                    height: playerViewRoot.space(38)
                    radius: playerViewRoot.space(12)
                    color: Theme.surface
                    border.width: 1
                    border.color: playerViewArtistSearch.activeFocus ? playerViewRoot.accentColor : Theme.border
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Text {
                        x: playerViewRoot.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf002"
                        color: Theme.muted
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: playerViewRoot.space(11)
                    }
                    TextInput {
                        id: playerViewArtistSearch
                        Accessible.name: "Search artists"
                        anchors.left: parent.left
                        anchors.leftMargin: playerViewRoot.space(30)
                        anchors.right: playerViewClearSearch.left
                        anchors.rightMargin: playerViewRoot.space(6)
                        anchors.verticalCenter: parent.verticalCenter
                        color: playerViewRoot.textColor
                        selectionColor: "#45393f"
                        font.family: "sans-serif"
                        font.pixelSize: playerViewRoot.space(11)
                        selectByMouse: true
                        clip: true
                        onTextChanged: {
                            if (playerViewRoot.filterType)
                                playerViewRoot.filter("", "");
                            playerViewLibrary.positionViewAtBeginning();
                        }
                    }
                    Item {
                        id: playerViewClearSearch
                        anchors.right: parent.right
                        width: playerViewRoot.space(26)
                        height: parent.height
                        Text {
                            visible: !!playerViewArtistSearch.text
                            anchors.centerIn: parent
                            text: "×"
                            color: Theme.muted
                            font.pixelSize: playerViewRoot.space(16)
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !!playerViewArtistSearch.text
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerViewArtistSearch.text = ""
                        }
                    }
                }
                ListView {
                    id: playerViewLibrary
                    anchors.top: playerViewArtistSearchBox.bottom
                    anchors.topMargin: playerViewRoot.space(10)
                    anchors.bottom: parent.bottom
                    width: parent.width
                    clip: true
                    reuseItems: true
                    cacheBuffer: 0
                    spacing: playerViewRoot.space(4)
                    model: playerViewRoot.filterType ? playerViewRoot.trackRows : playerViewRoot.folderEntries
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: playerViewLibrary.contentHeight > playerViewLibrary.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }
                    MouseArea {
                        id: playerViewArtistWheel
                        anchors.fill: parent
                        z: 5
                        acceptedButtons: Qt.NoButton
                        property real edgeDistance: 0
                        property int edgeDirection: 0
                        property double lastEdgeTime: 0
                        property real horizontalDistance: 0
                        property int horizontalDirection: 0
                        property double lastHorizontalTime: 0
                        onWheel: function (wheel) {
                            wheel.accepted = false;
                            var deltaX = wheel.pixelDelta.x ? wheel.pixelDelta.x * 3 : wheel.angleDelta.x;
                            var delta = wheel.pixelDelta.y ? wheel.pixelDelta.y * 3 : wheel.angleDelta.y;
                            var shiftScroll = !deltaX && delta && (wheel.modifiers & Qt.ShiftModifier);
                            if (Math.abs(deltaX) > Math.abs(delta) || shiftScroll) {
                                if (!playerViewRoot.filterType)
                                    return;
                                wheel.accepted = true;
                                edgeDistance = 0;
                                if (playerViewArtistWheelCooldown.running)
                                    return;
                                var horizontalDelta = shiftScroll ? delta : deltaX;
                                var horizontalStep = horizontalDelta < 0 ? 1 : -1;
                                var horizontalTime = Date.now();
                                if (horizontalDirection !== horizontalStep || horizontalTime - lastHorizontalTime > 450)
                                    horizontalDistance = 0;
                                horizontalDirection = horizontalStep;
                                lastHorizontalTime = horizontalTime;
                                horizontalDistance += Math.abs(horizontalDelta);
                                if (horizontalDistance >= 120) {
                                    horizontalDistance = 0;
                                    if (playerViewRoot.changeArtist(horizontalStep, true))
                                        playerViewArtistWheelCooldown.restart();
                                }
                                return;
                            }
                            horizontalDistance = 0;
                            var direction = delta < 0 ? 1 : -1;
                            var atEdge = delta && (direction > 0 ? playerViewLibrary.atYEnd : playerViewLibrary.atYBeginning);
                            if ((playerViewRoot.filterType !== "artist" && playerViewRoot.filterType !== "folder") || !atEdge) {
                                edgeDistance = 0;
                                edgeDirection = 0;
                                return;
                            }
                            wheel.accepted = true;
                            if (playerViewArtistWheelCooldown.running)
                                return;
                            var now = Date.now();
                            if (edgeDirection !== direction || now - lastEdgeTime > 450)
                                edgeDistance = 0;
                            edgeDirection = direction;
                            lastEdgeTime = now;
                            edgeDistance += Math.abs(delta);
                            if (edgeDistance >= 240) {
                                edgeDistance = 0;
                                if (playerViewRoot.changeArtist(direction))
                                    playerViewArtistWheelCooldown.restart();
                                else
                                    wheel.accepted = false;
                            }
                        }
                        Timer {
                            id: playerViewArtistWheelCooldown
                            interval: 650
                        }
                    }
                    delegate: DeleteSwipeDelegate {
                        id: playerViewEntry
                        required property var modelData
                        required property int index
                        readonly property bool artistRow: !playerViewRoot.filterType
                        readonly property bool groupHeader: !!modelData.header
                        readonly property bool current: artistRow ? modelData.folder === playerViewRoot.state.path.slice(0, playerViewRoot.state.path.lastIndexOf("/")) : modelData.path === playerViewRoot.state.path
                        readonly property bool deleting: playerViewDeleter.running && playerViewRoot.deletingPath === modelData.path
                        scaleFactor: playerViewRoot.space(1)
                        canSwipe: !artistRow && !groupHeader && !playerViewDeleter.running
                        opacity: deleting ? 0.35 : 1
                        onDeletingChanged: if (!deleting && swipe.complete)
                            swipe.close()
                        ListView.onReused: swipe.close()
                        onRemoveRequested: if (!playerViewRoot.deleteTrack(modelData))
                            swipe.close()
                        onClicked: {
                            if (groupHeader)
                                return;
                            if (artistRow)
                                playerViewRoot.filter("folder", modelData.name, modelData.folder);
                            else
                                playerViewRoot.run(current ? "toggle" : "play", current ? undefined : modelData.path);
                        }
                        width: playerViewLibrary.width
                        height: playerViewRoot.space(groupHeader ? 34 : artistRow ? 72 : 62)
                        background: Rectangle {
                            radius: playerViewRoot.space(12)
                            color: playerViewEntry.groupHeader ? "transparent" : Math.abs(playerViewEntry.swipe.position) > 0 ? Qt.tint("#221c21", Qt.rgba(0.851, 0.451, 0.498, Math.abs(playerViewEntry.swipe.position) * 0.7)) : playerViewEntry.current ? Theme.hover : playerViewEntry.hovered ? Theme.surface : Theme.surface
                            border.width: playerViewEntry.current && !playerViewEntry.groupHeader ? 1 : 0
                            border.color: "#45393f"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 110
                                }
                            }
                        }
                        contentItem: Item {
                            PlayerViewArtwork {
                                id: playerViewEntryArt
                                visible: !playerViewEntry.groupHeader
                                x: playerViewRoot.space(playerViewEntry.groupHeader ? 0 : 10)
                                anchors.verticalCenter: parent.verticalCenter
                                width: playerViewRoot.space(playerViewEntry.groupHeader ? 0 : playerViewEntry.artistRow ? 46 : 38)
                                height: width
                                radius: playerViewRoot.space(playerViewEntry.artistRow ? 12 : 8)
                                source: playerViewEntry.modelData.cover || ""
                                tint: "#362d34"
                            }
                            Column {
                                z: 1
                                anchors.left: playerViewEntryArt.right
                                anchors.leftMargin: playerViewRoot.space(playerViewEntry.groupHeader ? 8 : 13)
                                anchors.right: parent.right
                                anchors.rightMargin: playerViewRoot.space(playerViewEntry.artistRow ? 32 : 72)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: playerViewRoot.space(5)
                                Text {
                                    width: parent.width
                                    text: playerViewEntry.artistRow ? playerViewEntry.modelData.name : playerViewEntry.modelData.title.replace(/\s*\[[A-Za-z0-9_-]{11}\]$/, "")
                                    color: playerViewEntry.groupHeader ? "#d69aac" : playerViewEntry.current && !playerViewEntry.artistRow ? playerViewRoot.accentColor : "#e6d7dc"
                                    font.family: "sans-serif"
                                    font.pixelSize: playerViewRoot.space(playerViewEntry.groupHeader ? 10 : playerViewEntry.artistRow ? 14 : 12)
                                    font.weight: playerViewEntry.groupHeader || playerViewEntry.artistRow ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: !playerViewEntry.groupHeader && (playerViewEntry.artistRow || !!playerViewEntry.modelData.album || !!playerViewEntry.modelData.artist)
                                    width: parent.width
                                    text: playerViewEntry.artistRow ? playerViewEntry.modelData.count + (playerViewEntry.modelData.count === 1 ? " track" : " tracks") : playerViewEntry.modelData.album || playerViewEntry.modelData.artist || ""
                                    color: playerViewAlbumHit.containsMouse ? "#e6d7dc" : Theme.dim
                                    font.family: "sans-serif"
                                    font.pixelSize: playerViewRoot.space(10)
                                    elide: Text.ElideRight
                                    MouseArea {
                                        id: playerViewAlbumHit
                                        anchors.fill: parent
                                        enabled: !playerViewEntry.artistRow && !playerViewEntry.groupHeader && playerViewRoot.filterType !== "all" && !!playerViewEntry.modelData.album
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: playerViewRoot.filter("album", playerViewEntry.modelData.album, playerViewEntry.modelData.path.slice(0, playerViewEntry.modelData.path.lastIndexOf("/")))
                                    }
                                }
                            }
                            Text {
                                visible: !playerViewEntry.groupHeader
                                anchors.right: parent.right
                                anchors.rightMargin: playerViewRoot.space(playerViewEntry.artistRow ? 14 : 44)
                                anchors.verticalCenter: parent.verticalCenter
                                text: playerViewEntry.artistRow ? "\uf105" : playerViewEntry.current && !playerViewRoot.state.paused ? "\uf028" : ""
                                color: playerViewEntry.current ? playerViewRoot.accentColor : Theme.dim
                                font.family: "sans-serif"
                                font.pixelSize: playerViewRoot.space(11)
                            }
                            PlayerViewIconButton {
                                id: playerViewDeleteButton
                                contextRoot: playerViewRoot
                                z: 2
                                visible: !playerViewEntry.artistRow && !playerViewEntry.groupHeader
                                anchors.right: parent.right
                                anchors.rightMargin: playerViewRoot.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                size: 26
                                text: "\uf00d"
                                color: hovered ? "#d9737f" : "transparent"
                                opacity: playerViewEntry.hovered || hovered ? 1 : 0.4
                                enabled: !playerViewDeleter.running
                                onClicked: playerViewRoot.deleteTrack(playerViewEntry.modelData)
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: playerViewLibrary.count === 0
                        text: playerViewRoot.artistQuery ? "No results" : ""
                        color: Theme.dim
                        font.pixelSize: playerViewRoot.space(12)
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: playerViewRoot.space(12)
                height: playerViewRoot.space(104)
                radius: playerViewRoot.space(13)
                color: Theme.surface
                border.width: 1
                border.color: Theme.border
            }
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: playerViewRoot.space(24)
                height: playerViewRoot.space(78)
                PanelSlider {
                    id: playerViewProgress
                    width: parent.width
                    height: playerViewRoot.space(22)
                    bar: playerViewRoot.bar
                    trackHeight: playerViewRoot.space(3)
                    knobSize: playerViewRoot.space(10)
                    fillColor: playerViewRoot.accentColor
                    knobColor: "#e6d7dc"
                    trackColor: Theme.track
                    minimum: 0
                    maximum: Math.max(1, playerViewRoot.state.duration)
                    value: playerViewRoot.state.position
                    onReleased: function (v) {
                        playerViewRoot.run("seek", v);
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: playerViewRoot.space(15)
                    text: playerViewRoot.clock(playerViewProgress.dragging ? playerViewProgress.liveValue : playerViewRoot.state.position) + "  /  " + playerViewRoot.clock(playerViewRoot.state.duration)
                    color: "#d69aac"
                    font.family: "sans-serif"
                    font.pixelSize: playerViewRoot.space(11)
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    spacing: playerViewRoot.space(14)
                    PlayerViewIconButton {
                        contextRoot: playerViewRoot
                        text: "\uf074"
                        size: 32
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: !playerViewAction.running
                        checkable: true
                        checked: !!playerViewRoot.state.shuffle
                        opacity: enabled ? 1 : 0.4
                        Accessible.name: "Shuffle"
                        onClicked: playerViewRoot.run("shuffle")
                    }
                    PlayerViewIconButton {
                        contextRoot: playerViewRoot
                        text: "\uf048"
                        Accessible.name: "Previous track"
                        size: 36
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: playerViewRoot.run("previous")
                    }
                    PlayerViewIconButton {
                        contextRoot: playerViewRoot
                        text: playerViewRoot.state.path && !playerViewRoot.state.paused ? "\uf04c" : "\uf04b"
                        size: 48
                        primary: true
                        Accessible.name: playerViewRoot.state.paused ? "Play" : "Pause"
                        onClicked: playerViewRoot.run("toggle")
                    }
                    PlayerViewIconButton {
                        contextRoot: playerViewRoot
                        text: "\uf051"
                        Accessible.name: "Next track"
                        size: 36
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: playerViewRoot.run("next")
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: playerViewRoot.space(10)
                    spacing: playerViewRoot.space(9)
                    Text {
                        text: "\uf028"
                        color: "#d69aac"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: playerViewRoot.space(11)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PanelSlider {
                        width: playerViewRoot.space(88)
                        height: playerViewRoot.space(22)
                        bar: playerViewRoot.bar
                        trackHeight: playerViewRoot.space(3)
                        knobSize: playerViewRoot.space(9)
                        minimum: 0
                        maximum: 100
                        value: playerViewRoot.state.volume
                        fillColor: playerViewRoot.secondaryColor
                        knobColor: Theme.foreground
                        trackColor: Theme.track
                        onReleased: function (v) {
                            playerViewRoot.run("volume", v);
                        }
                    }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: playerViewRoot.space(112)
                width: Math.min(parent.width - playerViewRoot.space(48), playerViewRoot.space(440))
                height: playerViewDeletionNotice.implicitHeight + playerViewRoot.space(24)
                visible: !!playerViewRoot.deletionError || !!playerViewRoot.playbackError
                radius: playerViewRoot.space(12)
                color: "#d9737f"
                z: 20
                Text {
                    id: playerViewDeletionNotice
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: playerViewRoot.space(14)
                    text: playerViewRoot.deletionError || playerViewRoot.playbackError
                    color: Theme.foreground
                    font.family: "sans-serif"
                    font.pixelSize: playerViewRoot.space(11)
                    wrapMode: Text.Wrap
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        playerViewRoot.deletionError = "";
                        playerViewRoot.playbackError = "";
                    }
                }
            }
        }
    }

    component VideosView: Item {
        id: videosViewRoot
        function space(value) {
            return value;
        }
        property QtObject bar: null
        property bool opened: false
        property var videos: []
        property string selectedFolder: ""
        property string signature: ""
        property string error: ""
        property string hoveredVideo: ""
        property string playingVideo: ""
        property var playbackQueue: []
        property string trashPath: ""
        property string deleteError: ""
        property bool reloadPending: false
        signal dismissed
        readonly property var visibleVideos: videos.filter(function (video) {
            return (!videosViewRoot.selectedFolder || video.folder === videosViewRoot.selectedFolder)
                && (!videosViewSearch.text || video.name.toLowerCase().indexOf(videosViewSearch.text.toLowerCase()) >= 0
                    || video.folder.split("/").pop().toLowerCase().indexOf(videosViewSearch.text.toLowerCase()) >= 0);
        })
        readonly property var galleryEntries: {
            if (selectedFolder)
                return visibleVideos;
            var folders = {};
            var entries = [];
            visibleVideos.forEach(function (video) {
                if (!folders[video.folder]) {
                    folders[video.folder] = {
                        path: video.folder,
                        name: video.folder.split("/").pop(),
                        folder: video.folder,
                        thumbnail: video.thumbnail,
                        count: 0,
                        duration: 0,
                        isFolder: true
                    };
                    entries.push(folders[video.folder]);
                }
                folders[video.folder].count++;
            });
            return entries.sort(function (a, b) {
                return a.name.localeCompare(b.name) || a.path.localeCompare(b.path);
            });
        }
        function openFolder(folder) {
            selectedFolder = folder;
            hoveredVideo = "";
            Qt.callLater(function () {
                videosViewGallery.positionViewAtBeginning();
            });
        }
        function activateEntry(entry) {
            if (entry.isFolder)
                openFolder(entry.folder);
            else
                playVideo(entry.path);
        }
        function back() {
            if (playingVideo)
                stopVideo();
            else if (selectedFolder)
                openFolder("");
            else
                dismissed();
        }
        function refresh() {
            if (videosViewQuery.running)
                reloadPending = true;
            else
                videosViewQuery.running = true;
        }
        function open(payload) {
            opened = true;
            refresh();
            Qt.callLater(function () {
                videosViewCard.forceActiveFocus();
            });
        }
        function close() {
            opened = false;
            hoveredVideo = "";
            stopVideo();
        }
        function trashHoveredVideo() {
            if (!opened || videosViewTrashAction.running || videosViewSearch.activeFocus || !hoveredVideo)
                return;
            if (!videos.some(function (video) {
                return video.path === videosViewRoot.hoveredVideo;
            }))
                return;
            deleteError = "";
            trashPath = hoveredVideo;
            videosViewTrashAction.running = true;
        }
        function openInMpv() {
            var path = playingVideo || hoveredVideo;
            if (!opened || videosViewSearch.activeFocus || !path || !videos.some(function (video) {
                return video.path === path;
            }))
                return;
            close();
            Quickshell.execDetached(["mpv", "--", path]);
            dismissed();
        }
        function stopVideo() {
            playingVideo = "";
            playbackQueue = [];
            videosViewInlinePlayer.active = false;
            videosViewCard.forceActiveFocus();
        }
        function nextVideo() {
            if (!opened || !playingVideo)
                return;
            var index = playbackQueue.indexOf(playingVideo);
            for (var next = index + 1; next < playbackQueue.length; next++) {
                if (videos.some(function (video) {
                    return video.path === videosViewRoot.playbackQueue[next];
                })) {
                    playVideo(playbackQueue[next], true);
                    return;
                }
            }
            stopVideo();
        }
        function previousVideo() {
            if (!opened || !playingVideo)
                return;
            var index = playbackQueue.indexOf(playingVideo);
            for (var previous = index - 1; previous >= 0; previous--) {
                if (videos.some(function (video) {
                    return video.path === videosViewRoot.playbackQueue[previous];
                })) {
                    playVideo(playbackQueue[previous], true);
                    return;
                }
            }
        }
        function playVideo(path, continueQueue) {
            var video = videos.find(function (video) {
                return video.path === path;
            });
            if (!video)
                return;
            if (!continueQueue)
                playbackQueue = visibleVideos.map(function (video) {
                    return video.path;
                });
            hoveredVideo = "";
            playingVideo = path;
            var url = video.url || "file://" + path.split("/").map(function (part) {
                return encodeURIComponent(part);
            }).join("/");
            videosViewInlinePlayer.active = false;
            videosViewInlinePlayer.playbackSource = url;
            videosViewInlinePlayer.playbackTitle = video.name;
            videosViewInlinePlayer.active = true;
        }
        function duration(seconds) {
            var value = Math.floor(seconds || 0);
            var hours = Math.floor(value / 3600);
            return (hours ? hours + ":" : "") + (hours && value % 3600 < 600 ? "0" : "") + Math.floor(value % 3600 / 60) + ":" + (value % 60 < 10 ? "0" : "") + value % 60;
        }
        function size(bytes) {
            return bytes >= 1073741824 ? (bytes / 1073741824).toFixed(1) + " GiB" : (bytes / 1048576).toFixed(1) + " MiB";
        }
        Shortcut {
            sequence: "M"
            context: Qt.WindowShortcut
            enabled: videosViewRoot.opened && !videosViewSearch.activeFocus && (!!videosViewRoot.playingVideo || !!videosViewRoot.hoveredVideo)
            autoRepeat: false
            onActivated: videosViewRoot.openInMpv()
        }
        Shortcut {
            sequence: "N"
            context: Qt.WindowShortcut
            enabled: videosViewRoot.opened && !!videosViewRoot.playingVideo
            autoRepeat: false
            onActivated: videosViewRoot.nextVideo()
        }
        Shortcut {
            sequence: "P"
            context: Qt.WindowShortcut
            enabled: videosViewRoot.opened && !!videosViewRoot.playingVideo
            autoRepeat: false
            onActivated: videosViewRoot.previousVideo()
        }
        Shortcut {
            sequence: "Delete"
            context: Qt.WindowShortcut
            enabled: videosViewRoot.opened && !!videosViewRoot.hoveredVideo && !videosViewSearch.activeFocus && !videosViewTrashAction.running
            autoRepeat: false
            onActivated: videosViewRoot.trashHoveredVideo()
        }
        Process {
            id: videosViewTrashAction
            command: ["gio", "trash", "--", videosViewRoot.trashPath]
            onExited: function (code) {
                if (code === 0) {
                    videosViewRoot.videos = videosViewRoot.videos.filter(function (video) {
                        return video.path !== videosViewRoot.trashPath;
                    });
                    videosViewRoot.hoveredVideo = "";
                    videosViewRoot.signature = "";
                    videosViewRoot.refresh();
                } else {
                    videosViewRoot.deleteError = "Could not move video to Trash";
                    videosViewErrorTimer.restart();
                }
            }
        }
        Timer {
            id: videosViewErrorTimer
            interval: 6000
            onTriggered: videosViewRoot.deleteError = ""
        }
        Process {
            id: videosViewQuery
            onExited: {
                if (videosViewRoot.reloadPending) {
                    videosViewRoot.reloadPending = false;
                    Qt.callLater(function () {
                        videosViewRoot.refresh();
                    });
                }
            }
            command: ["python3", "-B", Quickshell.env("HOME") + "/.config/quickshell/scripts/videos.py", "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        if (text !== videosViewRoot.signature) {
                            var data = JSON.parse(text);
                            videosViewRoot.signature = text;
                            videosViewRoot.videos = data.videos;
                            videosViewRoot.error = data.error || "";
                        }
                    } catch (e) {
                        videosViewRoot.error = "Could not load videos";
                    }
                }
            }
        }
        Timer {
            interval: 3000
            running: videosViewRoot.opened
            repeat: true
            onTriggered: videosViewRoot.refresh()
        }
        Rectangle {
            id: videosViewCard
            objectName: "videos-browser"
            anchors.fill: parent
            radius: videosViewRoot.space(8)
            color: Theme.surface
            focus: true
            Keys.onEscapePressed: {
                videosViewRoot.back();
            }
            Item {
                id: videosViewHeader
                visible: !videosViewRoot.playingVideo
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: videosViewRoot.space(16)
                height: videosViewRoot.space(34)
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: videosViewRoot.space(10)
                    Rectangle {
                        objectName: "videos-folder-back"
                        visible: !!videosViewRoot.selectedFolder
                        width: videosViewRoot.space(30)
                        height: width
                        radius: 8
                        color: videosViewBackHit.containsMouse ? Theme.hover : Theme.surface
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Back to folders"
                        Keys.onReturnPressed: videosViewRoot.back()
                        Keys.onSpacePressed: videosViewRoot.back()
                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: Theme.accent
                            font.pixelSize: 18
                        }
                        MouseArea {
                            id: videosViewBackHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: videosViewRoot.back()
                        }
                    }
                    Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(videosViewRoot.space(330), videosViewRoot.width * 0.38)
                    elide: Text.ElideMiddle
                    text: videosViewRoot.selectedFolder
                        ? videosViewRoot.selectedFolder.split("/").pop() + "  ·  " + videosViewRoot.visibleVideos.length + " videos"
                        : videosViewRoot.galleryEntries.length + (videosViewRoot.galleryEntries.length === 1 ? " folder" : " folders")
                    color: Theme.muted
                    font.family: "sans-serif"
                    font.pixelSize: videosViewRoot.space(11)
                    }
                }
                Rectangle {
                    anchors.right: videosViewRefreshButton.left
                    anchors.rightMargin: videosViewRoot.space(8)
                    width: Math.min(videosViewSearch.activeFocus || videosViewSearch.text ? videosViewRoot.space(280) : videosViewRoot.space(220), parent.width * 0.55)
                    height: parent.height
                    radius: height / 2
                    color: videosViewSearch.activeFocus ? Qt.alpha(Theme.accent, 0.1) : Qt.rgba(0.902, 0.843, 0.863, 0.04)
                    border.width: 1
                    border.color: videosViewSearch.activeFocus ? Qt.alpha(Theme.accent, 0.7) : Qt.rgba(0.902, 0.843, 0.863, 0.1)
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Text {
                        id: videosViewSearchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: videosViewRoot.space(12)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf002"
                        color: videosViewSearch.activeFocus ? Theme.accent : Theme.muted
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: videosViewRoot.space(11)
                    }
                    TextInput {
                        id: videosViewSearch
                        objectName: "videos-search"
                        anchors.left: videosViewSearchIcon.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: videosViewRoot.space(8)
                        anchors.rightMargin: videosViewRoot.space(12)
                        color: Theme.foreground
                        selectionColor: "#45393f"
                        font.family: "sans-serif"
                        font.pixelSize: videosViewRoot.space(11)
                        selectByMouse: true
                        clip: true
                        onTextChanged: videosViewGallery.positionViewAtBeginning()
                        Text {
                            visible: !videosViewSearch.text && !videosViewSearch.activeFocus
                            text: "Search"
                            color: Theme.muted
                            font: videosViewSearch.font
                        }
                    }
                }
                Rectangle {
                    id: videosViewRefreshButton
                    anchors.right: parent.right
                    width: videosViewRoot.space(34)
                    height: width
                    radius: width / 2
                    color: videosViewRefreshHit.containsMouse ? Qt.alpha(Theme.accent, 0.16) : Qt.rgba(0.902, 0.843, 0.863, 0.04)
                    border.width: 1
                    border.color: videosViewRefreshHit.containsMouse ? Qt.alpha(Theme.accent, 0.6) : Qt.rgba(0.902, 0.843, 0.863, 0.1)
                    enabled: !videosViewQuery.running
                    activeFocusOnTab: true
                    Keys.onReturnPressed: videosViewRoot.refresh()
                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: Theme.accent
                        font.pixelSize: videosViewRoot.space(18)
                    }
                    MouseArea {
                        id: videosViewRefreshHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: videosViewRoot.refresh()
                    }
                }
            }
            GridView {
                id: videosViewGallery
                objectName: "videos-gallery"
                visible: !videosViewRoot.playingVideo
                anchors.top: videosViewHeader.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: videosViewRoot.space(12)
                anchors.bottomMargin: videosViewRoot.space(videosViewRoot.deleteError ? 40 : 12)
                readonly property int columns: Math.max(1, Math.min(4, Math.floor(width / videosViewRoot.space(260))))
                cellWidth: width / columns
                cellHeight: (cellWidth - videosViewRoot.space(12)) * 9 / 16 + videosViewRoot.space(12)
                model: videosViewRoot.galleryEntries
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                delegate: Item {
                    id: videosViewEntry
                    objectName: "videos-entry-" + modelData.path
                    required property var modelData
                    readonly property bool hot: videosViewHit.containsMouse || activeFocus
                    width: videosViewGallery.cellWidth
                    height: videosViewGallery.cellHeight
                    activeFocusOnTab: true
                    Keys.onReturnPressed: videosViewRoot.activateEntry(modelData)
                    Keys.onSpacePressed: videosViewRoot.activateEntry(modelData)
                    Repeater {
                        model: videosViewEntry.modelData.isFolder ? 2 : 0
                        Rectangle {
                            required property int index
                            anchors.fill: parent
                            anchors.margins: videosViewRoot.space(10) + (index + 1) * 3
                            anchors.topMargin: videosViewRoot.space(7) - (index + 1) * 4
                            radius: videosViewRoot.space(16)
                            color: index === 0 ? "#362d34" : "#2c252b"
                            border.width: 1
                            border.color: Qt.rgba(0.902, 0.843, 0.863, 0.06)
                            z: -1 - index
                            opacity: videosViewEntry.hot ? 1 : 0.8
                            anchors.bottomMargin: videosViewEntry.hot ? videosViewRoot.space(14) + index * 3 : videosViewRoot.space(10) + index * 3
                            Behavior on anchors.bottomMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }
                    Item {
                        id: videosViewTile
                        anchors.fill: parent
                        anchors.margins: videosViewRoot.space(6)
                        scale: videosViewEntry.hot ? 1.025 : 1
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: videosViewRoot.space(19)
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.alpha(Theme.accent, 0.55)
                            opacity: videosViewEntry.hot ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }
                        ClippingRectangle {
                            id: videosViewThumbnail
                            anchors.fill: parent
                            radius: videosViewRoot.space(16)
                            color: "#221c21"
                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -videosViewRoot.space(10)
                                text: videosViewEntry.modelData.isFolder ? "" : ""
                                color: Theme.track
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: videosViewRoot.space(30)
                            }
                            Image {
                                id: videosViewThumbImage
                                anchors.fill: parent
                                source: videosViewEntry.modelData.thumbnail
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 480
                                sourceSize.height: 270
                                scale: videosViewEntry.hot ? 1.08 : 1
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 240 } }
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * 0.62
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 0.5; color: "#99221c21" }
                                    GradientStop { position: 1; color: "#f2221c21" }
                                }
                            }
                            Rectangle {
                                visible: !!videosViewEntry.modelData.isFolder
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: videosViewRoot.space(8)
                                width: videosViewFolderBadge.implicitWidth + videosViewRoot.space(14)
                                height: videosViewRoot.space(20)
                                radius: height / 2
                                color: "#cc221c21"
                                border.width: 1
                                border.color: Qt.alpha(Theme.accent, 0.5)
                                Text {
                                    id: videosViewFolderBadge
                                    anchors.centerIn: parent
                                    text: "  " + (videosViewEntry.modelData.count || 0)
                                    color: Theme.accent
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: videosViewRoot.space(9)
                                    font.weight: Font.Bold
                                }
                            }
                            Item {
                                visible: !videosViewEntry.modelData.isFolder
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -videosViewRoot.space(8)
                                width: videosViewRoot.space(48)
                                height: width
                                opacity: videosViewEntry.hot ? 1 : 0
                                scale: videosViewEntry.hot ? 1 : 0.7
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + videosViewRoot.space(16)
                                    height: width
                                    radius: width / 2
                                    color: Qt.alpha(Theme.accent, 0.35)
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        blurEnabled: true
                                        blur: 1.0
                                        blurMax: 24
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: "#f2d69aac" }
                                        GradientStop { position: 1; color: "#f2d69aac" }
                                    }
                                    border.width: 1
                                    border.color: "#e6d7dc"
                                    Text {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: 2
                                        text: ""
                                        color: "#221c21"
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: videosViewRoot.space(15)
                                    }
                                }
                            }
                            Item {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: videosViewRoot.space(11)
                                anchors.bottomMargin: videosViewEntry.hot ? videosViewRoot.space(13) : videosViewRoot.space(10)
                                height: videosViewRoot.space(22)
                                Behavior on anchors.bottomMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Text {
                                    anchors.left: parent.left
                                    anchors.right: videosViewDuration.visible ? videosViewDuration.left : parent.right
                                    anchors.rightMargin: videosViewRoot.space(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: videosViewEntry.modelData.isFolder ? videosViewEntry.modelData.name : videosViewEntry.modelData.name
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    color: "#e6d7dc"
                                    font.family: "sans-serif"
                                    font.pixelSize: videosViewRoot.space(12)
                                    font.weight: Font.DemiBold
                                }
                                Rectangle {
                                    id: videosViewDuration
                                    visible: videosViewEntry.modelData.duration > 0
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: videosViewDurationText.implicitWidth + videosViewRoot.space(12)
                                    height: videosViewRoot.space(20)
                                    radius: height / 2
                                    color: "#cc221c21"
                                    border.width: 1
                                    border.color: Qt.rgba(0.902, 0.843, 0.863, 0.14)
                                    Text {
                                        id: videosViewDurationText
                                        anchors.centerIn: parent
                                        text: videosViewRoot.duration(videosViewEntry.modelData.duration)
                                        color: Theme.foreground
                                        font.family: "monospace"
                                        font.pixelSize: videosViewRoot.space(10)
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: videosViewRoot.space(16)
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(0.902, 0.843, 0.863, videosViewEntry.hot ? 0.18 : 0.08)
                            }
                        }
                    }
                    MouseArea {
                        id: videosViewHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: videosViewRoot.hoveredVideo = videosViewEntry.modelData.isFolder ? "" : videosViewEntry.modelData.path
                        onExited: if (videosViewRoot.hoveredVideo === videosViewEntry.modelData.path)
                            videosViewRoot.hoveredVideo = ""
                        Component.onDestruction: if (videosViewRoot.hoveredVideo === videosViewEntry.modelData.path)
                            videosViewRoot.hoveredVideo = ""
                        onClicked: videosViewRoot.activateEntry(videosViewEntry.modelData)
                    }
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - videosViewRoot.space(32)
                    visible: videosViewGallery.count === 0
                    text: videosViewRoot.error || (videosViewQuery.running ? "Loading…" : videosViewSearch.text ? "No matching videos" : "No MP4 videos")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.muted
                    font.family: "sans-serif"
                    font.pixelSize: videosViewRoot.space(12)
                }
            }
            Loader {
                id: videosViewInlinePlayer
                active: false
                property url playbackSource: ""
                property string playbackTitle: ""
                sourceComponent: InlineVideoPlayer {
                    sourceUrl: videosViewInlinePlayer.playbackSource
                    title: videosViewInlinePlayer.playbackTitle
                    queueIndex: videosViewRoot.playbackQueue.indexOf(videosViewRoot.playingVideo)
                    queueCount: videosViewRoot.playbackQueue.length
                }
                objectName: "inlineVideoLoader"
                anchors.fill: parent
                visible: !!videosViewRoot.playingVideo
                onLoaded: item.forceActiveFocus()
                onStatusChanged: if (status === Loader.Error) {
                    videosViewRoot.stopVideo();
                    videosViewRoot.deleteError = "Inline playback requires Qt Multimedia (qt6-multimedia).";
                    videosViewErrorTimer.restart();
                }
            }
            Connections {
                target: videosViewInlinePlayer.item
                function onBackRequested() {
                    videosViewRoot.stopVideo();
                }
                function onNextRequested() {
                    videosViewRoot.nextVideo();
                }
                function onPreviousRequested() {
                    videosViewRoot.previousVideo();
                }
                function onExternalRequested() {
                    videosViewRoot.openInMpv();
                }
                function onPlaybackFinished() {
                    var finishedVideo = videosViewRoot.playingVideo;
                    Qt.callLater(function () {
                        if (videosViewRoot.playingVideo === finishedVideo)
                            videosViewRoot.nextVideo();
                    });
                }
            }
            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: videosViewRoot.space(16)
                visible: !!videosViewRoot.deleteError
                text: videosViewRoot.deleteError
                color: "#d9737f"
                font.family: "sans-serif"
                font.pixelSize: videosViewRoot.space(11)
                elide: Text.ElideRight
            }
        }
    }

    component WallhavenView: Item {
        id: wallhavenViewRoot
        property QtObject bar: null
        property bool opened: false
        property bool loaded: false
        property var images: []
        property var selected: null
        property int page: 1
        property int pages: 1
        property string queryText: ""
        property string message: ""
        property var activeTags: []
        property string sorting: "toplist"
        function toggleTag(wallhavenViewTag) {
            if (wallhavenViewLookup.running)
                return;
            activeTags = activeTags.indexOf(wallhavenViewTag) >= 0 ? activeTags.filter(function (value) {
                return value !== wallhavenViewTag;
            }) : activeTags.concat([wallhavenViewTag]);
            search(1);
        }
        signal dismissed
        readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/wallhaven.py"
        function open(payload) {
            opened = true;
            if (!loaded)
                search(1);
        }
        function close() {
            opened = false;
        }
        function search(number, refresh) {
            if (wallhavenViewLookup.running)
                return;
            if (number === 1)
                queryText = [wallhavenViewSearchInput.text.trim()].concat(activeTags).filter(function (value) {
                    return !!value;
                }).join(" ");
            message = "Loading Wallhaven…";
            wallhavenViewLookup.command = ["python3", "-B", script, "search", queryText, String(number), sorting];
            if (refresh)
                wallhavenViewLookup.command = wallhavenViewLookup.command.concat(["--refresh"]);
            wallhavenViewLookup.running = true;
        }
        function refresh() {
            search(page, true);
        }
        function save(apply) {
            if (!selected || wallhavenViewAction.running)
                return;
            message = apply ? "Applying…" : "Saving…";
            wallhavenViewAction.command = ["python3", "-B", script, apply ? "apply" : "save", selected.id];
            wallhavenViewAction.running = true;
        }
        Process {
            id: wallhavenViewLookup
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(text);
                        wallhavenViewRoot.message = data.error || (data.images.length ? "" : "No wallpapers found");
                        if (!data.error) {
                            wallhavenViewRoot.loaded = true;
                            wallhavenViewRoot.images = data.images;
                            wallhavenViewRoot.page = data.page;
                            wallhavenViewRoot.pages = data.pages;
                            wallhavenViewGallery.positionViewAtBeginning();
                        }
                    } catch (error) {
                        wallhavenViewRoot.message = "Unable to load Wallhaven";
                    }
                }
            }
        }
        Process {
            id: wallhavenViewAction
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(text);
                        wallhavenViewRoot.message = data.error || data.message;
                    } catch (error) {
                        wallhavenViewRoot.message = "Unable to save wallpaper";
                    }
                }
            }
        }
        Item {
            id: wallhavenViewDiscovery
            width: parent.width
            height: 44
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18
                Repeater {
                    model: [
                        {
                            name: "Toplist",
                            key: "toplist"
                        },
                        {
                            name: "Latest",
                            key: "date_added"
                        },
                        {
                            name: "Random",
                            key: "random"
                        }
                    ]
                    Item {
                        id: wallhavenViewSortTab
                        required property var modelData
                        readonly property bool selected: wallhavenViewRoot.sorting === modelData.key
                        width: wallhavenViewSortLabel.implicitWidth
                        height: 38
                        enabled: !wallhavenViewLookup.running
                        activeFocusOnTab: true
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.name
                        Accessible.checked: selected
                        function choose() {
                            wallhavenViewRoot.sorting = modelData.key;
                            wallhavenViewRoot.search(1);
                        }
                        Keys.onReturnPressed: choose()
                        Keys.onSpacePressed: choose()
                        Text {
                            id: wallhavenViewSortLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: wallhavenViewSortTab.modelData.name
                            color: wallhavenViewSortTab.selected ? "#eee2e6" : wallhavenViewSortHit.containsMouse ? "#d69aac" : "#45393f"
                            font.pixelSize: 13
                            font.weight: wallhavenViewSortTab.selected ? Font.DemiBold : Font.Normal
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            radius: 1
                            color: Theme.accent
                            opacity: wallhavenViewSortTab.selected ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 140
                                }
                            }
                        }
                        MouseArea {
                            id: wallhavenViewSortHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wallhavenViewSortTab.choose()
                        }
                    }
                }
            }
            Rectangle {
                anchors.right: wallhavenViewRefreshButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(130, Math.min(300, parent.width - 284))
                height: 36
                radius: 12
                color: "#221c21"
                border.color: wallhavenViewSearchInput.activeFocus ? "#d4a5b5" : "#362d34"
                TextInput {
                    id: wallhavenViewSearchInput
                    x: 13
                    width: parent.width - 49
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#eee2e6"
                    font.pixelSize: 12
                    clip: true
                    selectByMouse: true
                    onAccepted: wallhavenViewRoot.search(1)
                    Text {
                        visible: !wallhavenViewSearchInput.text
                        text: "Search wallpapers"
                        color: "#45393f"
                        font: wallhavenViewSearchInput.font
                    }
                }
                ToolButton {
                    anchors.right: parent.right
                    width: 36
                    height: 36
                    enabled: !wallhavenViewLookup.running
                    Accessible.name: "Search wallpapers"
                    onClicked: wallhavenViewRoot.search(1)
                    contentItem: Text {
                        text: wallhavenViewLookup.running ? "···" : "\uf002"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 12
                        color: "#d69aac"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 12
                        color: parent.hovered ? "#362d34" : "transparent"
                    }
                }
            }
            ToolButton {
                id: wallhavenViewRefreshButton
                objectName: "wallhaven-refresh"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                enabled: !wallhavenViewLookup.running
                Accessible.name: "Refresh wallpapers"
                ToolTip.visible: hovered
                ToolTip.text: "Refresh wallpapers"
                onClicked: wallhavenViewRoot.refresh()
                contentItem: Text {
                    text: "↻"
                    font.pixelSize: 21
                    color: Theme.accent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 12
                    color: parent.hovered ? Theme.hover : "transparent"
                }
            }
        }
        Flickable {
            id: wallhavenViewSearchBar
            anchors.top: wallhavenViewDiscovery.bottom
            anchors.topMargin: 14
            width: parent.width
            height: 30
            contentWidth: wallhavenViewTags.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: wallhavenViewTags
                spacing: 8
                Repeater {
                    model: ["anime", "dark", "nature", "minimalism", "city"]
                    Rectangle {
                        id: wallhavenViewTag
                        required property string modelData
                        readonly property bool selected: wallhavenViewRoot.activeTags.indexOf(modelData) >= 0
                        width: wallhavenViewTagLabel.implicitWidth + 24
                        height: 28
                        radius: 14
                        enabled: !wallhavenViewLookup.running
                        activeFocusOnTab: true
                        color: selected ? "#d69aac" : wallhavenViewTagHit.containsMouse || activeFocus ? Theme.hover : "#221c21"
                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: modelData
                        Accessible.checked: selected
                        Keys.onReturnPressed: wallhavenViewRoot.toggleTag(modelData)
                        Keys.onSpacePressed: wallhavenViewRoot.toggleTag(modelData)
                        Text {
                            id: wallhavenViewTagLabel
                            anchors.centerIn: parent
                            text: wallhavenViewTag.modelData.charAt(0).toUpperCase() + wallhavenViewTag.modelData.slice(1)
                            color: wallhavenViewTag.selected ? "#221c21" : "#d69aac"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: wallhavenViewTagHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wallhavenViewRoot.toggleTag(wallhavenViewTag.modelData)
                        }
                    }
                }
            }
        }
        GridView {
            id: wallhavenViewGallery
            anchors.top: wallhavenViewSearchBar.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: wallhavenViewControls.top
            anchors.bottomMargin: 12
            clip: true
            cellWidth: width / Math.max(1, Math.floor(width / 260))
            cellHeight: cellWidth * 0.64
            model: wallhavenViewRoot.images
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                id: wallhavenViewTile
                required property var modelData
                width: wallhavenViewGallery.cellWidth
                height: wallhavenViewGallery.cellHeight
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 7
                    radius: 14
                    color: "#2c252b"
                    scale: wallhavenViewTileHit.pressed ? 0.98 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                    Image {
                        anchors.fill: parent
                        source: wallhavenViewTile.modelData.thumbnail
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
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
                                color: "#90221c21"
                            }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 13
                        border.width: wallhavenViewRoot.selected && wallhavenViewRoot.selected.id === wallhavenViewTile.modelData.id ? 2 : wallhavenViewTileHit.containsMouse ? 1 : 0
                        border.color: Theme.accent
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: wallhavenViewResolution.implicitWidth + 12
                        height: 22
                        radius: 7
                        color: "#b9221c21"
                        opacity: wallhavenViewTileHit.containsMouse ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }
                        }
                        Text {
                            id: wallhavenViewResolution
                            anchors.centerIn: parent
                            text: wallhavenViewTile.modelData.resolution
                            color: "#eee2e6"
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        id: wallhavenViewTileHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !wallhavenViewAction.running
                        onClicked: {
                            wallhavenViewRoot.selected = wallhavenViewTile.modelData;
                            wallhavenViewRoot.save(true);
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: wallhavenViewGallery
            width: wallhavenViewGallery.width - 40
            horizontalAlignment: Text.AlignHCenter
            visible: !wallhavenViewRoot.images.length
            text: wallhavenViewLookup.running ? "Loading Wallhaven…" : wallhavenViewRoot.message || "No wallpapers found"
            color: "#d69aac"
            font.pixelSize: 13
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
        Column {
            id: wallhavenViewControls
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 10
            Text {
                visible: !!wallhavenViewRoot.message
                width: parent.width
                text: wallhavenViewRoot.message
                color: "#d69aac"
                font.pixelSize: 11
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
            Item {
                width: parent.width
                height: 30
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14
                    ToolButton {
                        width: 30
                        height: 30
                        enabled: wallhavenViewRoot.page > 1 && !wallhavenViewLookup.running
                        Accessible.name: "Previous page"
                        onClicked: wallhavenViewRoot.search(wallhavenViewRoot.page - 1)
                        contentItem: Text {
                            text: "‹"
                            color: parent.enabled ? "#d69aac" : "#45393f"
                            font.pixelSize: 22
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 10
                            color: parent.hovered ? Theme.hover : "transparent"
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: wallhavenViewRoot.page + " / " + wallhavenViewRoot.pages
                        color: "#d69aac"
                        font.pixelSize: 10
                    }
                    ToolButton {
                        width: 30
                        height: 30
                        enabled: wallhavenViewRoot.page < wallhavenViewRoot.pages && !wallhavenViewLookup.running
                        Accessible.name: "Next page"
                        onClicked: wallhavenViewRoot.search(wallhavenViewRoot.page + 1)
                        contentItem: Text {
                            text: "›"
                            color: parent.enabled ? "#d69aac" : "#45393f"
                            font.pixelSize: 22
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 10
                            color: parent.hovered ? Theme.hover : "transparent"
                        }
                    }
                }
            }
        }
    }

    component WallpapersView: Item {
        id: wallpapersViewRoot
        function space(value) {
            return value;
        }
        property QtObject bar: null
        property string moduleName: "y.wallpapers"
        property var settings: ({})
        property var shell: null
        property var manifest: null
        signal dismissed
        property bool opened: false
        property var images: []
        property string selected: ""
        readonly property string previewSource: {
            var image = images.find(function (image) {
                return image.path === wallpapersViewRoot.selected;
            });
            return image ? image.url : images.length ? images[0].url : "";
        }
        property string mode: "normal"
        property string error: ""
        property bool applyQueued: false
        readonly property color accent: Theme.accent
        readonly property color textColor: Theme.foreground
        readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/wallpapers.py"
        function open(payload) {
            opened = true;
            error = "";
            Qt.callLater(function () {
                wallpapersViewCard.forceActiveFocus();
            });
            if (!wallpapersViewQuery.running)
                wallpapersViewQuery.running = true;
        }
        function close() {
            opened = false;
        }
        function dismiss() {
            opened = false;
            dismissed();
        }
        function toggle() {
            if (opened)
                dismiss();
            else
                open("{}");
        }
        function apply(random) {
            if (wallpapersViewAction.running) {
                applyQueued = true;
                return;
            }
            error = "";
            wallpapersViewAction.command = random ? ["python3", script, "random", mode] : ["python3", script, "apply", selected, mode];
            wallpapersViewAction.running = true;
        }
        readonly property int selectedIndex: images.findIndex(function (image) {
            return image.path === wallpapersViewRoot.selected;
        })
        function scrollWallpaper(event) {
            var delta = event.pixelDelta.y || event.pixelDelta.x || event.angleDelta.y || event.angleDelta.x;
            if (delta && !wallpapersViewWheelDelay.running) {
                navigate(delta < 0 ? 1 : -1);
                wallpapersViewWheelDelay.start();
            }
            event.accepted = true;
        }
        function navigate(direction) {
            if (images.length < 2)
                return;
            var index = ((selectedIndex < 0 ? 0 : selectedIndex) + direction + images.length) % images.length;
            choose(images[index].path);
        }
        function choose(path) {
            selected = path;
            wallpapersViewGallery.currentIndex = selectedIndex;
            wallpapersViewGallery.positionViewAtIndex(selectedIndex, ListView.Contain);
            apply(false);
        }
        function chooseMode(value) {
            mode = value;
            if (selected)
                apply(false);
        }

        Process {
            id: wallpapersViewQuery
            command: ["python3", wallpapersViewRoot.script, "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(text);
                        if (JSON.stringify(wallpapersViewRoot.images) !== JSON.stringify(data.images))
                            wallpapersViewRoot.images = data.images;
                        if (!wallpapersViewRoot.selected) {
                            wallpapersViewRoot.mode = data.selected.mode || "normal";
                            wallpapersViewRoot.selected = data.selected.path || (data.images.length ? data.images[0].path : "");
                            wallpapersViewGallery.currentIndex = wallpapersViewRoot.selectedIndex;
                            wallpapersViewGallery.positionViewAtIndex(wallpapersViewRoot.selectedIndex, ListView.Contain);
                        }
                    } catch (e) {}
                }
            }
        }
        Process {
            id: wallpapersViewAction
            stderr: StdioCollector {
                onStreamFinished: wallpapersViewRoot.error = String(text).trim()
            }
            onExited: function (code) {
                if (code === 0) {
                    wallpapersViewRoot.error = "";
                    if (!wallpapersViewQuery.running)
                        wallpapersViewQuery.running = true;
                }
                if (wallpapersViewRoot.applyQueued) {
                    wallpapersViewRoot.applyQueued = false;
                    Qt.callLater(function () {
                        wallpapersViewRoot.apply(false);
                    });
                }
            }
        }
        Timer {
            interval: 5000
            running: wallpapersViewRoot.opened
            repeat: true
            onTriggered: if (!wallpapersViewQuery.running)
                wallpapersViewQuery.running = true
        }

        Rectangle {
            id: wallpapersViewCard
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: wallpapersViewRoot.dismiss()
            Keys.onLeftPressed: wallpapersViewRoot.navigate(-1)
            Keys.onRightPressed: wallpapersViewRoot.navigate(1)
            radius: 14
            color: Theme.surface
            border.color: Theme.border
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                orientation: Qt.Vertical
                onWheel: function (event) {
                    wallpapersViewRoot.scrollWallpaper(event);
                }
            }
            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                orientation: Qt.Horizontal
                onWheel: function (event) {
                    wallpapersViewRoot.scrollWallpaper(event);
                }
            }
            Timer {
                id: wallpapersViewWheelDelay
                interval: 160
            }
            Image {
                id: wallpapersViewPreview
                objectName: "wallpaperPreview"
                anchors.fill: parent
                source: wallpapersViewRoot.previewSource
                sourceSize.width: 1600
                sourceSize.height: 1000
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                clip: true
            }
            Rectangle {
                id: wallpapersViewEffectSelector
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(294, parent.width - 24)
                height: 46
                radius: 23
                color: "#ed221c21"
                border.width: 1
                border.color: "#6645393f"
                Rectangle {
                    x: 5 + (wallpapersViewRoot.mode === "blur" ? 1 : wallpapersViewRoot.mode === "dark" ? 2 : 0) * (wallpapersViewEffectSelector.width - 10) / 3
                    y: 5
                    width: (wallpapersViewEffectSelector.width - 10) / 3
                    height: parent.height - 10
                    radius: 18
                    color: Theme.accent
                    border.width: 1
                    border.color: "#d69aac"
                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 5
                    Repeater {
                        model: [
                            {
                                label: "Normal",
                                value: "normal",
                                glyph: "\uf03e"
                            },
                            {
                                label: "Blur",
                                value: "blur",
                                glyph: "\uf043"
                            },
                            {
                                label: "Dark",
                                value: "dark",
                                glyph: "\uf186"
                            }
                        ]
                        Button {
                            id: wallpapersViewEffectButton
                            required property var modelData
                            readonly property bool selected: wallpapersViewRoot.mode === modelData.value
                            objectName: "wallpaper-mode-" + modelData.value
                            width: (wallpapersViewEffectSelector.width - 10) / 3
                            height: wallpapersViewEffectSelector.height - 10
                            enabled: wallpapersViewRoot.images.length > 0
                            focusPolicy: Qt.StrongFocus
                            Accessible.name: modelData.label
                            Accessible.role: Accessible.RadioButton
                            Accessible.checked: selected
                            hoverEnabled: true
                            onClicked: wallpapersViewRoot.chooseMode(modelData.value)
                            onHoveredChanged: {
                                if (hovered)
                                    wallpapersViewEffectHover.restart();
                                else
                                    wallpapersViewEffectHover.stop();
                            }
                            Timer {
                                id: wallpapersViewEffectHover
                                interval: 220
                                onTriggered: if (wallpapersViewRoot.opened && wallpapersViewEffectButton.hovered && wallpapersViewEffectButton.enabled && !wallpapersViewEffectButton.selected)
                                    wallpapersViewRoot.chooseMode(wallpapersViewEffectButton.modelData.value)
                            }
                            background: Rectangle {
                                radius: 18
                                color: !wallpapersViewEffectButton.selected && wallpapersViewEffectButton.hovered ? "#30d69aac" : "transparent"
                                border.width: wallpapersViewEffectButton.visualFocus ? 1 : 0
                                border.color: "#eee2e6"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }
                            contentItem: Item {
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 7
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: wallpapersViewEffectButton.modelData.glyph
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 12
                                        color: wallpapersViewEffectButton.selected ? Theme.surface : "#d69aac"
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 140
                                            }
                                        }
                                    }
                                    Text {
                                        text: wallpapersViewEffectButton.modelData.label
                                        font.family: "sans-serif"
                                        font.pixelSize: 11
                                        font.weight: wallpapersViewEffectButton.selected ? Font.DemiBold : Font.Medium
                                        color: wallpapersViewEffectButton.selected ? Theme.surface : "#e6d7dc"
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 140
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            MediaButton {
                id: wallpapersViewPreviousButton
                objectName: "previousWallpaper"
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "‹"
                fontSize: 28
                implicitWidth: 40
                implicitHeight: 44
                enabled: wallpapersViewRoot.images.length > 1
                Accessible.name: "Previous wallpaper"
                hoverEnabled: true
                onClicked: {
                    wallpapersViewPreviousHover.stop();
                    wallpapersViewRoot.navigate(-1);
                }
                onHoveredChanged: {
                    if (hovered)
                        wallpapersViewPreviousHover.restart();
                    else
                        wallpapersViewPreviousHover.stop();
                }
                Timer {
                    id: wallpapersViewPreviousHover
                    interval: 240
                    onTriggered: if (wallpapersViewRoot.opened && wallpapersViewPreviousButton.hovered && wallpapersViewPreviousButton.enabled)
                        wallpapersViewRoot.navigate(-1)
                }
            }
            MediaButton {
                id: wallpapersViewNextButton
                objectName: "nextWallpaper"
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                fontSize: 28
                implicitWidth: 40
                implicitHeight: 44
                enabled: wallpapersViewRoot.images.length > 1
                Accessible.name: "Next wallpaper"
                hoverEnabled: true
                onClicked: {
                    wallpapersViewNextHover.stop();
                    wallpapersViewRoot.navigate(1);
                }
                onHoveredChanged: {
                    if (hovered)
                        wallpapersViewNextHover.restart();
                    else
                        wallpapersViewNextHover.stop();
                }
                Timer {
                    id: wallpapersViewNextHover
                    interval: 240
                    onTriggered: if (wallpapersViewRoot.opened && wallpapersViewNextButton.hovered && wallpapersViewNextButton.enabled)
                        wallpapersViewRoot.navigate(1)
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(180, parent.height)
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#00000000"
                    }
                    GradientStop {
                        position: 1
                        color: "#b0221c21"
                    }
                }
            }
            Rectangle {
                id: wallpapersViewThumbnailTray
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: parent.width - 32
                height: Math.min(104, parent.height * 0.32)
                radius: 14
                color: "#b0221c21"
                border.color: "#4445393f"
                visible: wallpapersViewRoot.images.length > 0
                ListView {
                    id: wallpapersViewGallery
                    objectName: "wallpaperGallery"
                    anchors.fill: parent
                    anchors.margins: 10
                    model: wallpapersViewRoot.images
                    orientation: ListView.Horizontal
                    spacing: 8
                    flickableDirection: Flickable.HorizontalFlick
                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        orientation: Qt.Horizontal
                        onWheel: function (event) {
                            wallpapersViewRoot.scrollWallpaper(event);
                        }
                    }
                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        orientation: Qt.Vertical
                        onWheel: function (event) {
                            wallpapersViewRoot.scrollWallpaper(event);
                        }
                    }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 300
                    activeFocusOnTab: true
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: true
                    Keys.onReturnPressed: if (currentIndex >= 0 && currentIndex < wallpapersViewRoot.images.length)
                        wallpapersViewRoot.choose(wallpapersViewRoot.images[currentIndex].path)
                    Keys.onSpacePressed: if (currentIndex >= 0 && currentIndex < wallpapersViewRoot.images.length)
                        wallpapersViewRoot.choose(wallpapersViewRoot.images[currentIndex].path)
                    ScrollBar.horizontal: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        height: 4
                        contentItem: Rectangle {
                            implicitHeight: 4
                            radius: 2
                            color: Theme.accent
                            opacity: parent.pressed ? 0.8 : 0.35
                        }
                    }
                    delegate: Item {
                        id: wallpapersViewTile
                        required property var modelData
                        required property int index
                        objectName: "wallpaper-" + index
                        width: Math.min(wallpapersViewGallery.width * 0.72, (wallpapersViewGallery.height - 12) * 16 / 9)
                        height: wallpapersViewGallery.height - 12
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 10
                            color: Theme.background
                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: wallpapersViewTile.modelData.url
                                sourceSize.width: 240
                                sourceSize.height: 150
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                clip: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "transparent"
                                border.width: wallpapersViewRoot.selected === wallpapersViewTile.modelData.path || wallpapersViewTileHit.containsMouse || (wallpapersViewGallery.activeFocus && wallpapersViewTile.ListView.isCurrentItem) ? 2 : 0
                                border.color: wallpapersViewRoot.accent
                                opacity: wallpapersViewRoot.selected === wallpapersViewTile.modelData.path ? 1 : 0.6
                            }
                            MouseArea {
                                id: wallpapersViewTileHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: wallpapersViewThumbnailHover.restart()
                                onExited: wallpapersViewThumbnailHover.stop()
                                onClicked: {
                                    wallpapersViewThumbnailHover.stop();
                                    wallpapersViewGallery.currentIndex = wallpapersViewTile.index;
                                    wallpapersViewRoot.choose(wallpapersViewTile.modelData.path);
                                }
                                Timer {
                                    id: wallpapersViewThumbnailHover
                                    interval: 240
                                    onTriggered: if (wallpapersViewRoot.opened && wallpapersViewTileHit.containsMouse && !wallpapersViewGallery.moving && wallpapersViewRoot.selected !== wallpapersViewTile.modelData.path)
                                        wallpapersViewRoot.choose(wallpapersViewTile.modelData.path)
                                }
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: wallpapersViewTile.modelData.name || "Wallpaper"
                            Accessible.onPressAction: wallpapersViewRoot.choose(wallpapersViewTile.modelData.path)
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: wallpapersViewRoot.images.length === 0
                        text: wallpapersViewQuery.running ? "Loading…" : "No wallpapers"
                        color: Theme.dim
                        font.pixelSize: 13
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: wallpapersViewRoot.images.length === 0
                text: wallpapersViewQuery.running ? "Loading…" : "No wallpapers"
                color: Theme.dim
                font.pixelSize: 13
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: wallpapersViewThumbnailTray.top
                anchors.bottomMargin: 12
                width: Math.min(parent.width - 32, wallpapersViewErrorLabel.implicitWidth + 24)
                height: wallpapersViewErrorLabel.implicitHeight + 16
                radius: 10
                color: "#221c21"
                visible: !!wallpapersViewRoot.error
                Text {
                    id: wallpapersViewErrorLabel
                    anchors.centerIn: parent
                    width: parent.width - 24
                    text: wallpapersViewRoot.error
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: "#d9737f"
                    font.pixelSize: 12
                }
            }
        }
    }
}
