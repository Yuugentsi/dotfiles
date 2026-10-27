import QtQuick

Rectangle {
    property bool hasCursor: false
    property bool current: false
    property bool outline: false
    property color foreground: "#eef3f8"
    property color fill: "#383044"
    property color currentFill: "#383044"
    radius: 5
    color: hasCursor ? fill : current ? currentFill : "transparent"
    border.width: hasCursor || outline ? 1 : 0
    border.color: hasCursor ? "#c3b7ff" : "#37343f"
}
