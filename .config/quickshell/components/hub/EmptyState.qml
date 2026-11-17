import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

Column {
    id: empty
    property string glyph: ""
    property string title: ""
    property string hint: ""
    property bool busy: false
    spacing: 6
    Text {
        id: emptyIcon
        anchors.horizontalCenter: parent.horizontalCenter
        text: empty.busy ? "󰑓" : empty.glyph
        font.family: Theme.iconFont
        font.pixelSize: 34
        color: Qt.alpha(Theme.accent, 0.55)
        RotationAnimation on rotation {
            running: empty.busy
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
            onStopped: emptyIcon.rotation = 0
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: empty.title
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: Theme.muted
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: empty.hint !== ""
        text: empty.hint
        font.pixelSize: 11
        color: Theme.dim
    }
}
