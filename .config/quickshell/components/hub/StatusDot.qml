import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

Rectangle {
    id: dot
    property bool live: false
    implicitWidth: 8
    implicitHeight: 8
    radius: width / 2
    color: live ? Theme.success : Theme.dim
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 2.2
        height: width
        radius: width / 2
        color: Qt.alpha(Theme.success, 0.18)
        visible: dot.live
    }
    SequentialAnimation on opacity {
        running: dot.live
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        onStopped: dot.opacity = 1
    }
}
