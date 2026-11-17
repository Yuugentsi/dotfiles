import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

Item {
    id: hubList
    property var model: []
    property Component rowDelegate
    property int rowSpacing: 8
    property string emptyGlyph: ""
    property string emptyTitle: ""
    property string emptyHint: ""
    property bool busy: false
    property bool loadingMore: false
    property bool hasMore: false
    readonly property real fitHeight: listView.count === 0 || busy ? 200 : listView.contentHeight
    signal endReached

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: hubList.rowSpacing
        model: hubList.model
        delegate: hubList.rowDelegate
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: HubScrollBar {}
        onContentYChanged: {
            if (hubList.hasMore && !hubList.loadingMore && !hubList.busy && count > 0 && contentHeight > height && contentY + height >= contentHeight - 160)
                hubList.endReached();
        }
        footer: Item {
            width: listView.width
            height: hubList.hasMore || hubList.loadingMore ? 52 : 0
            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: parent.height > 0
                Text {
                    id: moreIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰑓"
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                    color: Theme.accent
                    RotationAnimation on rotation {
                        running: hubList.loadingMore
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        onStopped: moreIcon.rotation = 0
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hubList.loadingMore ? "Loading more…" : "Scroll for more"
                    font.pixelSize: 11
                    color: Theme.dim
                }
            }
        }
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
        }
    }

    EmptyState {
        anchors.centerIn: parent
        visible: listView.count === 0 || hubList.busy
        glyph: hubList.emptyGlyph
        title: hubList.busy ? "Searching…" : hubList.emptyTitle
        hint: hubList.busy ? "" : hubList.emptyHint
        busy: hubList.busy
    }
}
