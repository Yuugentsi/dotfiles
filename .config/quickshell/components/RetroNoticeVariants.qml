pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property int variant: 0
    property string heading: "Audio"
    property string title: "Enjoy the Silence"
    property string symbol: "󰎇"
    property bool muted: false
    property int fontSize: 12
    property real level: -1
    property real maximumWidth: 960
    readonly property bool meter: level >= 0
    readonly property var themes: [
        {name: "Windows 95", bg: "#c0c0c0", bar: "#000080", end: "#1084d0", fg: "#111111", ink: "#ffffff", edge: "#111111", accent: "#000080", font: "Noto Sans"},
        {name: "Mac OS 9", bg: "#dddddd", bar: "#dddddd", end: "#dddddd", fg: "#181818", ink: "#181818", edge: "#555555", accent: "#6c78a0", font: "Noto Sans"},
        {name: "BeOS", bg: "#dedede", bar: "#ffcf3a", end: "#ffbd2f", fg: "#151515", ink: "#151515", edge: "#555555", accent: "#d49400", font: "Noto Sans"},
        {name: "Amiga Workbench", bg: "#0055aa", bar: "#ffffff", end: "#ffffff", fg: "#ffffff", ink: "#0055aa", edge: "#000000", accent: "#ff8800", font: "JetBrains Mono"},
        {name: "NeXTSTEP", bg: "#a0a0a0", bar: "#252525", end: "#252525", fg: "#101010", ink: "#ffffff", edge: "#111111", accent: "#333333", font: "Noto Sans"},
        {name: "OS/2 Warp", bg: "#cccccc", bar: "#18456b", end: "#2d7692", fg: "#111111", ink: "#ffffff", edge: "#354d5d", accent: "#146878", font: "Noto Sans"},
        {name: "Solaris CDE", bg: "#ada5bd", bar: "#746787", end: "#746787", fg: "#201a2a", ink: "#fff4d6", edge: "#52455f", accent: "#5b486d", font: "Noto Sans"},
        {name: "DOS Blue", bg: "#0000aa", bar: "#0000aa", end: "#0000aa", fg: "#ffffff", ink: "#ffff55", edge: "#aaaaaa", accent: "#55ffff", font: "JetBrains Mono"},
        {name: "Amber CRT", bg: "#100d05", bar: "#100d05", end: "#100d05", fg: "#ffd287", ink: "#c9923d", edge: "#926929", accent: "#ffbc56", font: "JetBrains Mono"},
        {name: "Y2K Chrome", bg: "#254978", bar: "#6b9ac5", end: "#14345c", fg: "#effaff", ink: "#ffffff", edge: "#bceaff", accent: "#89eaff", font: "Noto Sans"}
    ]
    readonly property var theme: themes[variant]
    readonly property int headerHeight: variant === 7 || variant === 8 ? 18 : 22
    implicitWidth: meter ? 184 : Math.max(120, Math.min(maximumWidth, Math.ceil(metrics.advanceWidth) + 48))
    implicitHeight: Math.max(headerHeight + 30, Math.ceil(layout.implicitHeight) + headerHeight + 14)

    TextMetrics { id: metrics; text: root.title; font: label.font }
    Text {
        id: layout
        visible: false
        width: root.implicitWidth - 48
        text: root.meter ? "" : root.title
        textFormat: Text.PlainText
        font: label.font
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    Rectangle {
        id: surface
        x: 0; y: root.variant === 2 ? 12 : 0
        width: root.width; height: root.height - y
        radius: root.variant === 9 ? 12 : 0
        color: root.theme.bg
        border.width: root.variant === 5 || root.variant === 6 ? 2 : 1
        border.color: root.theme.edge
        Rectangle {
            visible: root.variant < 7
            x: 1; y: 1; width: parent.width - 2; height: 1
            color: root.variant === 6 ? "#d8d0e5" : "#ffffff"
        }
        Rectangle {
            visible: root.variant < 7
            x: 1; y: 1; width: 1; height: parent.height - 2
            color: root.variant === 6 ? "#d8d0e5" : "#ffffff"
        }
        Rectangle {
            visible: root.variant === 7
            anchors.fill: parent; anchors.margins: 3
            color: "transparent"; border.color: root.theme.edge
        }
        Rectangle {
            visible: root.variant === 9
            anchors.fill: parent; anchors.margins: 2; radius: 10
            color: "transparent"; border.color: "#6c9fc5"
        }
    }

    Rectangle {
        id: titlebar
        x: root.variant === 2 ? 0 : 3
        y: root.variant === 2 ? 0 : 3
        width: root.variant === 2 ? Math.min(root.width - 8, 126) : root.width - 6
        height: 16
        radius: root.variant === 9 ? 8 : 0
        gradient: Gradient {
            orientation: root.variant === 9 ? Gradient.Vertical : Gradient.Horizontal
            GradientStop { position: 0; color: root.theme.bar }
            GradientStop { position: 1; color: root.theme.end }
        }
        Repeater {
            model: root.variant === 1 ? 6 : 0
            Rectangle {
                required property int index
                x: 4; y: 2 + index * 2; width: titlebar.width - 8; height: 1; color: "#9c9c9c"
            }
        }
        Rectangle {
            visible: root.variant === 1 || root.variant === 7
            anchors.centerIn: parent
            width: caption.implicitWidth + 10; height: parent.height
            color: root.theme.bar
        }
        Text {
            id: caption
            x: root.variant === 1 ? (parent.width - width) / 2 : root.variant === 2 ? 19 : 5
            y: 1
            text: root.heading
            color: root.theme.ink
            font.family: root.theme.font
            font.pixelSize: 10
            font.weight: Font.Bold
            textFormat: Text.PlainText
        }
        Rectangle {
            visible: root.variant < 7
            x: root.variant === 1 || root.variant === 2 ? 3 : parent.width - 14
            y: 2; width: 12; height: 12
            color: root.variant === 4 ? "#777777" : root.theme.bg
            border.color: root.variant === 1 ? "#555555" : "#ffffff"
            Text {
                visible: root.variant !== 1 && root.variant !== 2
                anchors.centerIn: parent
                text: root.variant === 4 ? "◆" : "×"
                color: root.variant === 4 ? "#ffffff" : root.theme.fg
                font.pixelSize: root.variant === 4 ? 7 : 10
            }
        }
    }

    Text {
        x: 10
        y: root.headerHeight + (root.meter ? 6 : 5)
        text: root.meter ? root.muted ? "󰖁" : "󰕾" : root.variant === 8 ? ">_" : root.variant === 7 ? "♫" : root.symbol
        color: root.theme.accent
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
    }
    Text {
        id: label
        visible: !root.meter
        x: 36; y: root.headerHeight + 5
        width: root.width - 48
        height: layout.implicitHeight
        text: root.title
        textFormat: Text.PlainText
        font.family: root.theme.font
        font.pixelSize: root.fontSize
        color: root.theme.fg
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }
    Rectangle {
        visible: root.meter
        x: 36; y: root.headerHeight + 7; width: root.width - 82; height: 14
        color: root.variant < 7 ? "#80777777" : "transparent"
        border.color: root.theme.edge
        Row {
            x: 2; y: 2; spacing: 2
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    width: 5; height: 10
                    color: index < (root.muted ? 0 : root.level) * 14 ? root.theme.accent : "transparent"
                }
            }
        }
    }
    Text {
        visible: root.meter
        anchors.right: parent.right; anchors.rightMargin: 8
        y: root.headerHeight + 6
        text: Math.round(root.level * 100) + "%"
        font.family: root.theme.font; font.pixelSize: 11
        color: root.theme.fg
    }
    Repeater {
        model: root.variant === 8 ? Math.floor(root.height / 3) : 0
        Rectangle {
            required property int index
            x: 1; y: index * 3; width: root.width - 2; height: 1; color: "#20000000"
        }
    }
}
