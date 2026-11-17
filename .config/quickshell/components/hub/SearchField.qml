import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

Rectangle {
    id: field
    property string glyph: "󰍉"
    property string placeholder: ""
    property string actionLabel: "Search"
    property string actionIcon: "󰍉"
    property bool busy: false
    property bool showAction: true
    property alias input: fieldInput
    property alias text: fieldInput.text
    default property alias trailing: trailingRow.data
    signal submitted
    implicitHeight: 46
    radius: height / 2
    color: Qt.alpha(Theme.foreground, fieldInput.activeFocus ? 0.06 : 0.035)
    border.width: 1
    border.color: fieldInput.activeFocus ? Qt.alpha(Theme.accent, 0.6) : Qt.alpha(Theme.foreground, 0.08)
    Behavior on border.color { ColorAnimation { duration: 140 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 7
        spacing: 10

        Text {
            text: field.glyph
            font.family: Theme.iconFont
            font.pixelSize: 17
            color: fieldInput.activeFocus ? Theme.accent : Theme.dim
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        TextInput {
            id: fieldInput
            Layout.fillWidth: true
            font.pixelSize: 13
            color: Theme.foreground
            selectionColor: Qt.alpha(Theme.accent, 0.4)
            selectedTextColor: Theme.foreground
            clip: true
            selectByMouse: true
            onAccepted: field.submitted()

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: field.placeholder
                font.pixelSize: 13
                color: Theme.dim
                elide: Text.ElideRight
                visible: fieldInput.text === ""
            }
        }

        Row {
            id: trailingRow
            spacing: 6
        }

        HubButton {
            visible: field.showAction
            primary: true
            icon: field.actionIcon
            label: field.actionLabel
            spinning: field.busy
            onClicked: field.submitted()
        }
    }
}
