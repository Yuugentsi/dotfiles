import QtQuick
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

ScrollBar {
    id: bar
    policy: ScrollBar.AsNeeded
    visible: size < 1
    contentItem: Rectangle {
        implicitWidth: 4
        radius: 2
        color: bar.pressed || bar.hovered ? Qt.alpha(Theme.accent, 0.6) : Qt.alpha(Theme.foreground, 0.16)
    }
    background: Item {}
}
