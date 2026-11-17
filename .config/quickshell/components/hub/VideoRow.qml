import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../controls/PanelTheme.js" as Theme

SwipeRow {
    id: video
    property string videoTitle: ""
    property string channel: ""
    property string thumbnail: ""
    property string duration: ""
    property bool playlist: false
    signal audioRequested
    signal videoRequested
    signal opened

    height: 96
    rightIcon: "󰎆"
    rightLabel: playlist ? "All · MP3" : "MP3"
    rightTint: Theme.success
    leftIcon: "󰕧"
    leftLabel: playlist ? "All · MP4" : "MP4"
    leftTint: Theme.accent
    onSwipedRight: video.audioRequested()
    onSwipedLeft: video.videoRequested()
    onClicked: if (playlist) video.opened()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        anchors.rightMargin: 12
        spacing: 14

        Item {
            Layout.preferredWidth: 134
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.alpha(Theme.foreground, 0.06)

                Text {
                    anchors.centerIn: parent
                    visible: thumb.status !== Image.Ready
                    text: "󰗃"
                    font.family: Theme.iconFont
                    font.pixelSize: 22
                    color: Theme.dim
                }
            }

            Image {
                id: thumb
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: video.thumbnail
                asynchronous: true
                visible: false
            }

            Item {
                id: thumbMask
                anchors.fill: parent
                layer.enabled: true
                visible: false
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: thumb
                maskEnabled: true
                maskSource: thumbMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
                opacity: thumb.status === Image.Ready ? 1 : 0
                scale: video.hovered ? 1.03 : 1
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.foreground, video.hovered ? 0.18 : 0.08)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 34
                height: 34
                radius: 17
                color: "#b0221c21"
                opacity: video.hovered ? 1 : 0
                scale: video.hovered ? 1 : 0.8
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1
                    text: video.playlist ? "󰲸" : "󰐊"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.foreground
                }
            }

            Rectangle {
                visible: video.duration !== "" || video.playlist
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 5
                width: durationText.implicitWidth + 10
                height: 17
                radius: 5
                color: "#d0000000"
                Text {
                    id: durationText
                    anchors.centerIn: parent
                    text: video.playlist ? "󰲸 " + (video.duration !== "" ? video.duration : "list") : video.duration
                    font.family: video.playlist ? Theme.iconFont : "JetBrains Mono"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.foreground
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: video.videoTitle
                font.pixelSize: 13
                font.weight: Font.DemiBold
                lineHeight: 1.1
                color: Theme.foreground
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                visible: video.playlist
                Layout.topMargin: 3
                text: "Click to browse tracks"
                font.pixelSize: 10
                color: Theme.dim
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    radius: 8
                    color: Qt.alpha(Theme.accent, 0.2)
                    Text {
                        anchors.centerIn: parent
                        text: video.channel !== "" ? video.channel.charAt(0).toUpperCase() : "?"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Theme.accent
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: video.channel !== "" ? video.channel : "YouTube"
                    font.pixelSize: 11
                    color: Theme.muted
                    elide: Text.ElideRight
                }

                Row {
                    spacing: 6
                    opacity: video.hovered ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    HubButton {
                        implicitHeight: 28
                        icon: "󰎆"
                        label: video.playlist ? "All MP3" : "MP3"
                        tint: Theme.success
                        onClicked: video.audioRequested()
                    }

                    HubButton {
                        implicitHeight: 28
                        icon: "󰕧"
                        label: video.playlist ? "All MP4" : "MP4"
                        onClicked: video.videoRequested()
                    }
                }
            }
        }
    }
}
