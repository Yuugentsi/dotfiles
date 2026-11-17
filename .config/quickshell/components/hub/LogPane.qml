import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

ColumnLayout {
    id: pane
    property string title: ""
    property var entries: []
    property string fallbackLabel: "Log"
    signal back
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        HubButton {
            icon: "󰁍"
            label: "Back"
            onClicked: pane.back()
        }

        Text {
            Layout.fillWidth: true
            text: pane.title
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.foreground
            elide: Text.ElideRight
        }

        Text {
            text: pane.entries.length + (pane.entries.length === 1 ? " entry" : " entries")
            font.pixelSize: 11
            color: Theme.dim
        }
    }

    HubList {
        Layout.fillWidth: true
        Layout.fillHeight: true
        rowSpacing: 6
        model: pane.entries
        emptyGlyph: "󰦨"
        emptyTitle: "No entries yet"
        emptyHint: "Activity will show up here"
        rowDelegate: Rectangle {
            id: entry
            readonly property color kindColor: modelData.kind === "error" ? Theme.danger : modelData.kind === "downloaded" ? Theme.success : Theme.accent
            width: ListView.view ? ListView.view.width : 0
            height: entryCol.implicitHeight + 20
            radius: 12
            color: Qt.alpha(Theme.foreground, 0.03)
            border.width: 1
            border.color: modelData.kind === "error" ? Qt.alpha(Theme.danger, 0.3) : Qt.alpha(Theme.foreground, 0.06)

            Rectangle {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height - 20
                radius: 2
                color: entry.kindColor
            }

            ColumnLayout {
                id: entryCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: (modelData.label || pane.fallbackLabel).toUpperCase()
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: entry.kindColor
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title || ""
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: modelData.kind === "error" ? Theme.danger : Theme.foreground
                        elide: Text.ElideRight
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !!modelData.detail
                    text: modelData.detail || ""
                    font.pixelSize: 11
                    color: Theme.muted
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }
        }
    }
}
