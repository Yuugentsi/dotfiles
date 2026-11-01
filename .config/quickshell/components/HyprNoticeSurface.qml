import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property bool hud: false
    property color accentColor: "#cba6f7"

    Rectangle {
        anchors.fill: parent
        visible: !root.hud
        radius: 4
        gradient: Gradient {
            GradientStop { position: 0; color: "#1e1e2e" }
            GradientStop { position: 1; color: "#181825" }
        }
        border.width: 1
        border.color: "#45475a"
        Rectangle {
            x: 10
            anchors.bottom: parent.bottom
            width: parent.width - 20
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#cba6f7" }
                GradientStop { position: 1; color: "#b4befe" }
            }
        }
    }
    Shape {
        anchors.fill: parent
        visible: root.hud
        ShapePath {
            strokeWidth: 1
            strokeColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
            fillColor: "#11111b"
            startX: 11
            startY: 1
            PathLine { x: root.width - 1; y: 1 }
            PathLine { x: root.width - 1; y: root.height - 11 }
            PathLine { x: root.width - 11; y: root.height - 1 }
            PathLine { x: 1; y: root.height - 1 }
            PathLine { x: 1; y: 11 }
            PathLine { x: 11; y: 1 }
        }
    }
    Rectangle {
        visible: root.hud
        x: 14
        y: 1
        width: 36
        height: 2
        color: root.accentColor
    }
    Rectangle {
        visible: root.hud
        x: parent.width - 40
        y: parent.height - 3
        width: 24
        height: 2
        color: "#cba6f7"
    }
}
