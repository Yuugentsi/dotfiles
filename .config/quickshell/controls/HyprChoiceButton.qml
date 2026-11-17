import "PanelTheme.js" as Theme
import QtQuick
import QtQuick.Controls

Button {
    id: button
    property string label: ""
    property bool selected: false
    implicitWidth: Math.max(48, caption.implicitWidth + 22)
    implicitHeight: 32
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: selected ? "Selected" : ""
    contentItem: Text {
        id: caption
        text: button.label
        color: button.selected ? Theme.foreground : button.hovered ? Theme.foreground : Theme.muted
        font.pixelSize: 11
        font.weight: button.selected ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Theme.controlRadius
        color: button.down ? Theme.selected : button.selected ? Qt.alpha(Theme.accent, 0.2) : button.hovered ? Theme.hover : Qt.alpha(Theme.foreground, 0.04)
        border.width: 1
        border.color: button.activeFocus ? Theme.accent : button.selected ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.foreground, 0.08)
        Behavior on color {
            ColorAnimation {
                duration: 110
            }
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
