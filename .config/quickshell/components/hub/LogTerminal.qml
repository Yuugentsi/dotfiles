import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../controls/PanelTheme.js" as Theme

Rectangle {
    id: term
    property string linesText: ""
    property string caption: "yt-dlp"
    property bool running: false
    property color tint: Theme.accent
    property string liveLine: ""
    property var knownLines: []
    readonly property string mono: "JetBrains Mono"

    radius: 12
    color: "#f0221c21"
    border.width: 1
    border.color: Qt.alpha(Theme.foreground, 0.08)
    clip: true

    function tagColor(tag) {
        var t = tag.toLowerCase();
        if (t.indexOf("error") === 0) return Theme.danger;
        if (t.indexOf("warning") === 0) return "#e8c99a";
        if (t === "[download]") return "#d69aac";
        if (t === "[youtube]" || t === "[youtube:tab]") return "#d9737f";
        if (t === "[extractaudio]" || t === "[merger]" || t === "[videoremuxer]" || t === "[metadata]" || t === "[embedthumbnail]") return Theme.success;
        if (t === "[info]") return "#d69aac";
        return Theme.accent;
    }

    function ingest() {
        var next = linesText === "" ? [] : linesText.split("\n");
        var prev = knownLines;
        var fresh = next.length;
        if (prev.length > 0 && linesModel.count > 0) {
            var last = prev[prev.length - 1];
            fresh = -1;
            for (var i = next.length - 1; i >= 0; i--) {
                if (next[i] === last) {
                    fresh = next.length - 1 - i;
                    break;
                }
            }
            if (fresh < 0) {
                linesModel.clear();
                fresh = next.length;
            }
        }
        for (var j = next.length - fresh; j < next.length; j++) {
            var line = next[j];
            var match = /^(\[[^\]]+\]|ERROR:|WARNING:)\s?(.*)$/.exec(line);
            linesModel.append({ tag: match ? match[1] : "", body: match ? match[2] : line, number: linesModel.count + 1 });
        }
        knownLines = next;
    }

    onLinesTextChanged: ingest()
    Component.onCompleted: ingest()

    ListModel { id: linesModel }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: Qt.alpha(Theme.foreground, 0.035)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: ["#d9737f", "#e8c99a", "#a9c4a0"]
                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        color: Qt.alpha(modelData, 0.75)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: term.caption
                font.family: term.mono
                font.pixelSize: 10
                font.weight: Font.Bold
                color: Theme.dim
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: linesModel.count + " lines"
                    font.family: term.mono
                    font.pixelSize: 9
                    color: Theme.dim
                }

                Rectangle {
                    id: liveDot
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: term.running ? term.tint : Theme.dim
                    SequentialAnimation on opacity {
                        running: term.running
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                        onStopped: liveDot.opacity = 1
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.alpha(Theme.foreground, 0.06)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: linesView
                anchors.fill: parent
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                clip: true
                model: linesModel
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: HubScrollBar {}
                property bool pinned: true
                onMovementEnded: pinned = atYEnd
                onCountChanged: if (pinned) Qt.callLater(positionViewAtEnd)
                Component.onCompleted: positionViewAtEnd()

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 240 }
                    NumberAnimation { property: "x"; from: 10; to: 0; duration: 240; easing.type: Easing.OutCubic }
                }

                footer: Item {
                    width: linesView.width
                    height: term.running ? 18 : 0
                    Row {
                        x: 44
                        visible: term.running
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            visible: term.liveLine !== ""
                            text: term.liveLine
                            font.family: term.mono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: term.tint
                        }
                        Text {
                            text: "▍"
                            font.family: term.mono
                            font.pixelSize: 11
                            color: term.tint
                            SequentialAnimation on opacity {
                                running: term.running
                                loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                    }
                }

                delegate: Item {
                    id: lineItem
                    readonly property bool newest: index === linesView.count - 1
                    width: linesView.width
                    height: Math.max(15, bodyText.implicitHeight)

                    Rectangle {
                        anchors.fill: parent
                        color: lineItem.newest && term.running ? Qt.alpha(term.tint, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    Text {
                        id: gutter
                        x: 8
                        width: 26
                        horizontalAlignment: Text.AlignRight
                        text: model.number
                        font.family: term.mono
                        font.pixelSize: 9
                        color: Qt.alpha(Theme.dim, 0.7)
                        topPadding: 2
                    }

                    Text {
                        id: bodyText
                        x: 44
                        width: parent.width - x - 12
                        textFormat: Text.StyledText
                        wrapMode: Text.WrapAnywhere
                        font.family: term.mono
                        font.pixelSize: 10
                        color: lineItem.newest ? Theme.foreground : Qt.alpha(Theme.foreground, 0.72)
                        text: {
                            var esc = function (v) { return v.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); };
                            var head = model.tag !== "" ? "<font color=\"" + term.tagColor(model.tag) + "\"><b>" + esc(model.tag) + "</b></font> " : "";
                            return head + esc(model.body);
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: linesModel.count === 0
                text: term.running ? "Waiting for yt-dlp…" : "No output"
                font.family: term.mono
                font.pixelSize: 10
                color: Theme.dim
            }

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 14
                visible: !linesView.atYBeginning
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f0221c21" }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }
}
