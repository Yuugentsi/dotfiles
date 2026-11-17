import "PanelTheme.js" as Theme
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ComboBox {
    id: root
    property var labels: []
    implicitHeight: 34
    font.pixelSize: 11
    leftPadding: 10
    rightPadding: 24
    contentItem: Text {
        text: root.labels[root.currentIndex] || root.currentText
        color: "#d69aac"
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: root.width - 21
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        color: Theme.muted
        font.pixelSize: 15
    }
    background: Rectangle {
        radius: 9
        color: root.hovered ? Theme.hover : "#221c21"
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.border
    }
    delegate: ItemDelegate {
        id: option
        required property int index
        required property var modelData
        width: root.width
        implicitHeight: 34
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: root.labels[option.index] || String(option.modelData)
            color: "#d69aac"
            font: root.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 6
            color: option.highlighted ? "#362d34" : "transparent"
        }
    }
    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 220)
        padding: 4
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollBar.vertical: ScrollBar {}
        }
        background: Rectangle {
            radius: 10
            color: "#221c21"
            border.width: 1
            border.color: "#45393f"
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
