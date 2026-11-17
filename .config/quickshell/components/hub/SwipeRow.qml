import QtQuick
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

SwipeDelegate {
    id: row
    property bool allowRight: true
    property bool allowLeft: true
    property string rightIcon: "󰎆"
    property string rightLabel: "MP3"
    property color rightTint: Theme.success
    property string leftIcon: "󰕧"
    property string leftLabel: "MP4"
    property color leftTint: Theme.accent
    default property alias content: inner.data
    signal swipedRight
    signal swipedLeft

    width: ListView.view ? ListView.view.width : 0
    padding: 0
    hoverEnabled: true
    swipe.enabled: allowRight || allowLeft
    swipe.transition: Transition {
        SmoothedAnimation { velocity: 4; easing.type: Easing.OutCubic }
    }
    swipe.onCompleted: {
        if (swipe.position > 0)
            row.swipedRight();
        else
            row.swipedLeft();
        Qt.callLater(function () {
            row.swipe.close();
        });
    }
    swipe.left: allowRight ? rightAction : null
    swipe.right: allowLeft ? leftAction : null

    Component {
        id: rightAction
        Rectangle {
            width: row.width
            height: row.height
            radius: 14
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(row.rightTint, 0.32) }
                GradientStop { position: 1; color: Qt.alpha(row.rightTint, 0.04) }
            }
            border.width: 1
            border.color: Qt.alpha(row.rightTint, 0.45)
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                opacity: Math.min(1, Math.abs(row.swipe.position) * 2.5)
                scale: 0.8 + Math.min(0.2, Math.abs(row.swipe.position) * 0.5)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.rightIcon
                    font.family: Theme.iconFont
                    font.pixelSize: 22
                    color: row.rightTint
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.rightLabel
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Theme.foreground
                }
            }
        }
    }

    Component {
        id: leftAction
        Rectangle {
            width: row.width
            height: row.height
            radius: 14
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(row.leftTint, 0.04) }
                GradientStop { position: 1; color: Qt.alpha(row.leftTint, 0.32) }
            }
            border.width: 1
            border.color: Qt.alpha(row.leftTint, 0.45)
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                opacity: Math.min(1, Math.abs(row.swipe.position) * 2.5)
                scale: 0.8 + Math.min(0.2, Math.abs(row.swipe.position) * 0.5)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.leftLabel
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Theme.foreground
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.leftIcon
                    font.family: Theme.iconFont
                    font.pixelSize: 22
                    color: row.leftTint
                }
            }
        }
    }

    background: Rectangle {
        radius: 14
        color: Math.abs(row.swipe.position) > 0 ? "#2c252b" : row.hovered ? Qt.alpha(Theme.foreground, 0.06) : Qt.alpha(Theme.foreground, 0.03)
        border.width: 1
        border.color: Qt.alpha(Theme.foreground, 0.07)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    contentItem: Item {
        id: inner
    }
}
