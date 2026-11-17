pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property int variant: 0
    property string title: "Enjoy the Silence"
    property string heading: "Audio"
    property string symbol: "󰎇"
    property real maximumWidth: 960
    implicitWidth: Math.max(120, Math.min(maximumWidth, Math.ceil(metrics.advanceWidth) + 54))
    implicitHeight: Math.max(variant === 0 ? 54 : 44, Math.ceil(layout.implicitHeight) + (variant === 0 ? 35 : variant === 1 ? 25 : 24))

    TextMetrics { id: metrics; text: root.title; font: song.font }
    Text {
        id: layout
        visible: false
        width: root.implicitWidth - 54
        text: root.title
        font: song.font
        textFormat: Text.PlainText
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    Rectangle {
        visible: root.variant === 0
        anchors.fill: parent
        color: "#c0c0c0"
        border.color: "#111111"
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 1; color: "#ffffff" }
        Rectangle { x: 1; y: 1; width: 1; height: parent.height - 2; color: "#ffffff" }
        Rectangle { x: 2; y: parent.height - 2; width: parent.width - 4; height: 1; color: "#808080" }
        Rectangle { x: parent.width - 2; y: 2; width: 1; height: parent.height - 4; color: "#808080" }
        Rectangle {
            x: 3; y: 3; width: parent.width - 6; height: 16
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#000080" }
                GradientStop { position: 1; color: "#1084d0" }
            }
            Text { x: 5; y: 1; text: root.heading; color: "white"; font.family: "Noto Sans"; font.pixelSize: 10; font.bold: true }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 2; y: 2; width: 12; height: 12
                color: "#c0c0c0"; border.color: "#ffffff"
                Text { anchors.centerIn: parent; text: "×"; color: "#101010"; font.pixelSize: 11; font.bold: true }
            }
        }
        Text {
            x: 10; y: 26
            text: root.symbol
            color: "#000080"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20
        }
    }

    Rectangle {
        visible: root.variant === 1
        anchors.fill: parent
        radius: 3
        color: "#fa08130c"
        border.color: "#3f8758"
        Text {
            x: 10; y: 5
            text: "[ AUDIO ]"
            color: "#5db77b"
            font.family: "JetBrains Mono"; font.pixelSize: 7; font.letterSpacing: 1
        }
        Text {
            x: 10; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 5
            text: ">_"
            color: "#a4ffbc"
            font.family: "JetBrains Mono"; font.pixelSize: 12
        }
        Repeater {
            model: Math.floor(root.height / 3)
            Rectangle {
                required property int index
                x: 1; y: index * 3; width: root.width - 2; height: 1
                color: "#09000000"
            }
        }
    }

    Rectangle {
        visible: root.variant === 2
        anchors.fill: parent
        radius: 16
        border.color: "#a9e4ff"
        gradient: Gradient {
            GradientStop { position: 0; color: "#eefaff" }
            GradientStop { position: 0.44; color: "#a3bbdb" }
            GradientStop { position: 0.48; color: "#42699c" }
            GradientStop { position: 1; color: "#adcbed" }
        }
        Rectangle {
            x: 3; y: 3; width: parent.width - 6; height: parent.height - 6; radius: 13
            gradient: Gradient {
                GradientStop { position: 0; color: "#eb2b5682" }
                GradientStop { position: 0.49; color: "#eb132d56" }
                GradientStop { position: 1; color: "#eb294d80" }
            }
            Rectangle {
                x: 5; y: 2; width: parent.width - 10; height: Math.min(14, parent.height / 2); radius: 7
                gradient: Gradient {
                    GradientStop { position: 0; color: "#60d4f9ff" }
                    GradientStop { position: 1; color: "#00d4f9ff" }
                }
            }
        }
        Rectangle {
            x: 10; anchors.verticalCenter: parent.verticalCenter; width: 25; height: 25; radius: 13
            border.color: "#c5faff"
            gradient: Gradient {
                GradientStop { position: 0; color: "#91ebff" }
                GradientStop { position: 0.5; color: "#216bb9" }
                GradientStop { position: 1; color: "#103d81" }
            }
            Text { anchors.centerIn: parent; text: "♪"; color: "#e3fbff"; font.pixelSize: 17 }
        }
    }

    Text {
        id: song
        x: 42
        y: root.variant === 0 ? 25 : root.variant === 1 ? 18 : (root.height - height) / 2
        width: root.width - 54
        height: layout.implicitHeight
        text: root.title
        textFormat: Text.PlainText
        color: root.variant === 0 ? "#111111" : root.variant === 1 ? "#b2ffbd" : "#f1fbff"
        font.family: root.variant === 1 ? "JetBrains Mono" : "Noto Sans"
        font.pixelSize: root.variant === 1 ? 12 : 13
        font.weight: root.variant === 0 ? Font.Normal : Font.Medium
        style: root.variant === 1 ? Text.Outline : Text.Normal
        styleColor: "#244f31"
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }
}
