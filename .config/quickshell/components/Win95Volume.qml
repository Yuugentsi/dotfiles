import QtQuick

Item {
    id: root
    property real value: 0
    property bool muted: false
    implicitWidth: indicator.implicitWidth + 24
    implicitHeight: 52

    HyprNoticeSurface {
        anchors.fill: parent
        title: root.muted ? "Volume - Muted" : "Volume"
        HyprLevelIndicator {
            id: indicator
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            value: root.value
            muted: root.muted
            symbol: root.muted ? "󰖁" : "󰕾"
        }
    }
}
