import QtQuick

Rectangle {
    property bool hasCursor: false
    property bool current: false
    property bool outline: false
    property color foreground: "#eee2e6"
    property color fill: "#362d34"
    property color currentFill: "#362d34"
    radius: 5
    color: hasCursor ? fill : current ? currentFill : "transparent"
    border.width: hasCursor || outline ? 1 : 0
    border.color: hasCursor ? "#d69aac" : "#362d34"
}
