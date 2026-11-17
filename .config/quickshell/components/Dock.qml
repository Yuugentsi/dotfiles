pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool autoHide: true
    property bool ready: false
    property bool saving: false
    property string errorMessage: ""
    property var favorites: ["kitty", "librewolf", "thunar", "spotify"]
    readonly property var windows: ToplevelManager.toplevels.values
    readonly property var applications: DesktopEntries.applications.values
    readonly property var groups: {
        const result = []
        const entries = applications
        for (const favorite of favorites) {
            const entry = DesktopEntries.byId(favorite)
            if (entry) result.push({ key: entry.id, entry: entry, windows: [], pinned: true })
        }
        for (const window of windows) {
            if (!window.appId) continue
            const appId = window.appId.toLowerCase()
            const entry = entries.find(candidate => candidate.startupClass && candidate.startupClass.toLowerCase() === appId)
                || DesktopEntries.heuristicLookup(window.appId)
            const key = entry ? entry.id : window.appId
            let group = result.find(candidate => candidate.key === key)
            if (!group) {
                group = { key: key, entry: entry, windows: [], pinned: false }
                result.push(group)
            }
            group.windows.push(window)
        }
        return result
    }

    function activate(group, direction) {
        if (!group.windows.length) {
            if (group.entry) group.entry.execute()
            return
        }
        const active = group.windows.findIndex(window => window.activated)
        const index = active < 0 ? 0 : (active + direction + group.windows.length) % group.windows.length
        group.windows[index].activate()
    }

    function toggleFavorite(group) {
        if (!ready || saving || !group.entry) return
        const previous = favorites
        favorites = group.pinned ? favorites.filter(key => key !== group.key) : favorites.concat([group.key])
        saving = true
        state.previous = previous
        state.setText(JSON.stringify({ favorites: favorites }, null, 2) + "\n")
    }

    FileView {
        id: state
        property var previous: []
        path: Quickshell.statePath("dock.json")
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text())
                if (!Array.isArray(saved.favorites) || !saved.favorites.every(key => typeof key === "string")) throw new Error("invalid favorites")
                root.favorites = [...new Set(saved.favorites)]
                root.ready = true
            } catch (error) {
                root.errorMessage = "Could not load favorites"
            }
        }
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) root.ready = true
            else root.errorMessage = "Could not load favorites"
        }
        onSaveFailed: {
            root.saving = false
            root.favorites = previous
            root.errorMessage = "Could not save favorites"
        }
        onSaved: { root.saving = false; root.errorMessage = "" }
    }

    IpcHandler {
        target: "dock"
        function toggleAutoHide(): void { root.autoHide = !root.autoHide }
        function status(): string {
            return JSON.stringify({ autoHide: root.autoHide, favorites: root.favorites, groups: root.groups.length, ready: root.ready, error: root.errorMessage })
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: dock
            required property var modelData
            screen: modelData
            readonly property var controller: root
            property bool expanded: false
            property string selectedKey: ""
            readonly property var selectedGroup: controller.groups.find(group => group.key === selectedKey) || null
            readonly property bool showing: !controller.autoHide || expanded || selectedGroup !== null
            readonly property real cellWidth: 62
            anchors.bottom: true
            implicitWidth: Math.min(screen.width - 24, Math.max(250, controller.groups.length * cellWidth + 32))
            implicitHeight: 380
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "macos-dock"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                item: hoverZone
                Region { item: reveal }
                Region { item: contextCard }
            }

            Timer {
                id: hideDelay
                interval: 650
                onTriggered: {
                    if (!dockHover.hovered && !menuHover.hovered && !edgeHover.hovered) {
                        dock.selectedKey = ""
                        dock.expanded = false
                    }
                }
            }
            Timer {
                id: revealDelay
                interval: 100
                onTriggered: dock.expanded = true
            }

            Item {
                id: reveal
                anchors.bottom: parent.bottom
                width: parent.width
                height: 3
                HoverHandler {
                    id: edgeHover
                    onHoveredChanged: {
                        if (hovered) { hideDelay.stop(); revealDelay.restart() }
                        else { revealDelay.stop(); hideDelay.restart() }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1
                    height: 1
                    radius: 0.5
                    color: "#90c3a0ff"
                    opacity: dock.showing ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
            }

            Item {
                id: hoverZone
                width: parent.width
                height: dock.showing ? 120 : 0
                anchors.bottom: parent.bottom
                HoverHandler {
                    id: dockHover
                    onHoveredChanged: {
                        if (hovered) { dock.expanded = true; hideDelay.stop() }
                        else hideDelay.restart()
                    }
                }

                Item {
                    id: surface
                    width: parent.width
                    height: 120
                    y: dock.showing ? 0 : 130
                    opacity: dock.showing ? 1 : 0
                    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Rectangle {
                        x: 2
                        y: 42
                        width: parent.width - 4
                        height: 70
                        radius: 23
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#ce2b1c36" }
                            GradientStop { position: 1; color: "#b81f1729" }
                        }
                        border.width: 1
                        border.color: "#80608e"
                        Rectangle {
                            x: 1; y: 1
                            width: parent.width - 2
                            height: parent.height / 2
                            radius: 22
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#18c3a0ff" }
                                GradientStop { position: 1; color: "#00c3a0ff" }
                            }
                        }
                    }

                    Flickable {
                        id: viewport
                        x: 16
                        width: parent.width - 32
                        height: 116
                        contentWidth: Math.max(width, icons.width)
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick
                        Row {
                            id: icons
                            x: Math.max(0, (viewport.width - width) / 2)
                            height: viewport.height
                            Repeater {
                                model: dock.controller.groups
                                Item {
                                    id: tile
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: modelData.windows.some(window => window.activated)
                                    readonly property real distance: dockHover.hovered ? Math.abs(dockHover.point.position.x - (viewport.x + icons.x + x - viewport.contentX + width / 2)) : 999
                                    readonly property real magnification: 1 + 0.48 * Math.max(0, 1 - distance / 110)
                                    width: dock.cellWidth
                                    height: 116
                                    ToolTip.visible: hit.containsMouse && !dock.selectedGroup
                                    ToolTip.delay: 450
                                    ToolTip.text: modelData.entry ? modelData.entry.name : modelData.key

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 51
                                        width: 52; height: 52; radius: 14
                                        color: tile.active ? "#7045304f" : hit.containsMouse ? "#4030253e" : "transparent"
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    Item {
                                        id: iconContainer
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 53 - (tile.magnification - 1) * 48
                                        width: 48; height: 48
                                        scale: tile.magnification
                                        transformOrigin: Item.Bottom
                                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        Image {
                                            id: appIcon
                                            anchors.fill: parent
                                            source: tile.modelData.entry && tile.modelData.entry.icon ? Quickshell.iconPath(tile.modelData.entry.icon, true) : ""
                                            sourceSize.width: 96
                                            sourceSize.height: 96
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: appIcon.status !== Image.Ready
                                            radius: 12
                                            color: "#5b3e70"
                                            Text {
                                                anchors.centerIn: parent
                                                text: (tile.modelData.entry ? tile.modelData.entry.name : tile.modelData.key).slice(0, 1).toUpperCase()
                                                color: "#f3eaff"
                                                font.pixelSize: 24
                                            }
                                        }
                                    }
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 105
                                        spacing: 3
                                        Repeater {
                                            model: Math.min(3, tile.modelData.windows.length)
                                            Rectangle {
                                                width: tile.active ? 6 : 4
                                                height: 4; radius: 2
                                                color: tile.active ? "#ff9c66" : "#c3a0ff"
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: hit
                                        x: 0; y: 24
                                        width: parent.width; height: 90
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.RightButton) {
                                                dock.selectedKey = dock.selectedKey === tile.modelData.key ? "" : tile.modelData.key
                                            } else if (mouse.button === Qt.MiddleButton || (mouse.modifiers & Qt.ShiftModifier)) {
                                                if (tile.modelData.entry) tile.modelData.entry.execute()
                                            } else {
                                                dock.selectedKey = ""
                                                dock.controller.activate(tile.modelData, 1)
                                            }
                                        }
                                        onWheel: function(wheel) {
                                            dock.controller.activate(tile.modelData, wheel.angleDelta.y > 0 ? -1 : 1)
                                            wheel.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: contextCard
                x: (dock.width - width) / 2
                y: dock.selectedGroup ? dock.height - 126 - height : dock.height
                width: Math.min(310, dock.width - 12)
                height: dock.selectedGroup ? Math.min(246, menuColumn.implicitHeight + 20) : 0
                visible: dock.selectedGroup !== null
                radius: 15
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f22b1c36" }
                    GradientStop { position: 1; color: "#f01f1729" }
                }
                border.width: 1
                border.color: "#80608e"
                HoverHandler {
                    id: menuHover
                    onHoveredChanged: {
                        if (hovered) hideDelay.stop()
                        else hideDelay.restart()
                    }
                }
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    contentWidth: availableWidth
                    Column {
                        id: menuColumn
                        width: contextCard.width - 20
                        spacing: 3
                        Label {
                            width: parent.width
                            padding: 8
                            text: dock.selectedGroup ? (dock.selectedGroup.entry ? dock.selectedGroup.entry.name : dock.selectedGroup.key) : ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: "#f3eaff"
                            font.bold: true
                        }
                        MenuButton {
                            width: parent.width
                            visible: !!(dock.selectedGroup && dock.selectedGroup.entry)
                            text: "Open new window"
                            onClicked: { dock.selectedGroup.entry.execute(); dock.selectedKey = "" }
                        }
                        MenuButton {
                            width: parent.width
                            visible: !!(dock.selectedGroup && dock.selectedGroup.entry)
                            enabled: dock.controller.ready && !dock.controller.saving
                            text: dock.selectedGroup && dock.selectedGroup.pinned ? "Unpin from favorites" : "Pin to favorites"
                            onClicked: {
                                dock.controller.toggleFavorite(dock.selectedGroup)
                                dock.selectedKey = ""
                            }
                        }
                        Repeater {
                            model: dock.selectedGroup ? dock.selectedGroup.windows : []
                            MenuButton {
                                id: windowButton
                                required property var modelData
                                width: menuColumn.width
                                text: (modelData.activated ? "●  " : "") + (modelData.title || "Window")
                                onClicked: { modelData.activate(); dock.selectedKey = "" }
                                contentItem: Text {
                                    text: windowButton.text
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: "#e7d6f5"
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            text: dock.controller.errorMessage
                            visible: text.length > 0
                            wrapMode: Text.Wrap
                            color: "#ffac8c"
                        }
                        MenuButton {
                            width: parent.width
                            text: "Close menu"
                            onClicked: dock.selectedKey = ""
                        }
                    }
                }
            }


        }
    }

    component MenuButton: Button {
        id: action
        implicitHeight: 34
        hoverEnabled: true
        leftPadding: 12
        rightPadding: 12
        opacity: enabled ? 1 : 0.4
        background: Rectangle {
            radius: 10
            color: action.down ? "#45304f" : action.hovered ? "#3b2a47" : "#251b30"
            border.width: 1
            border.color: action.hovered ? "#80608e" : "#3b2b49"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        contentItem: Text {
            text: action.text
            textFormat: Text.PlainText
            color: action.hovered ? "#f3eaff" : "#bba6ca"
            font.family: "sans-serif"
            font.pixelSize: 11
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
