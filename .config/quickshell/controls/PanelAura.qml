import "PanelTheme.js" as Theme
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property real radius: Theme.panelRadius
    property color primary: Theme.glowPrimary
    property color secondary: Theme.glowSecondary
    property real intensity: 0.35
    anchors.fill: parent

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width * 0.12
                centerY: -root.height * 0.08
                centerRadius: Math.max(root.width, root.height) * 0.7
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: Qt.alpha(root.primary, 0.22 * root.intensity) }
                GradientStop { position: 0.55; color: Qt.alpha(root.primary, 0.05 * root.intensity) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathRectangle { x: 0; y: 0; width: root.width; height: root.height; radius: root.radius }
        }
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width * 1.02
                centerY: root.height * 1.05
                centerRadius: Math.max(root.width, root.height) * 0.6
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: Qt.alpha(root.secondary, 0.16 * root.intensity) }
                GradientStop { position: 0.6; color: Qt.alpha(root.secondary, 0.03 * root.intensity) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathRectangle { x: 0; y: 0; width: root.width; height: root.height; radius: root.radius }
        }
        ShapePath {
            strokeWidth: 1
            strokeColor: Theme.highlight
            fillColor: "transparent"
            PathRectangle { x: 1; y: 1; width: root.width - 2; height: root.height - 2; radius: Math.max(0, root.radius - 1) }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 1
        width: parent.width * 0.7
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.35; color: Qt.alpha(Theme.accent, 0.22) }
            GradientStop { position: 0.65; color: Qt.alpha(Theme.accentAlt, 0.18) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
