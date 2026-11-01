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
        color: button.selected ? Theme.foreground : button.hovered ? "#e4d1f7" : Theme.muted
        font.pixelSize: 11
        font.weight: button.selected ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 9
        color: button.down ? "#493052" : button.selected ? Theme.selected : button.hovered ? Theme.hover : Theme.surface
        border.width: 1
        border.color: button.activeFocus ? Theme.accent : button.selected ? Theme.border : Theme.border
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
