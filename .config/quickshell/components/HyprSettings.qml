import "../controls/PanelTheme.js" as Theme
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../controls"

Rectangle {
    id: root
    required property bool opened
    signal closeRequested
    property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/hypr.py"
    property var settings: ({
            rules: [],
            monitors: [],
            revision: ""
        })
    property string message: ""
    property bool failed: false
    property string payload: ""
    readonly property bool busy: process.running
    readonly property bool ready: settings.rules.length > 0 && !busy
    readonly property var selectedRule: settings.rules[0] || ({})
    readonly property var monitor: settings.monitors.find(function (item) {
        return root.selectedRule.output ? item.name === root.selectedRule.output : true;
    }) || ({})
    readonly property string resolution: String(selectedRule.mode || "preferred").split("@")[0]
    readonly property string refreshRate: String(selectedRule.mode || "").split("@")[1] || "auto"
    readonly property var validScales: (settings.validScales || [1]).filter(function (scale) {
        return scale >= 1 && scale <= 2;
    })
    property real pendingScale: -1
    property real applyingScale: -1
    property real wheelRemainder: 0
    readonly property real displayedScale: pendingScale >= 0 ? pendingScale : applyingScale >= 0 ? applyingScale : Number(selectedRule.scale || 1)
    readonly property int scaleIndex: {
        var nearest = 0;
        for (var index = 1; index < validScales.length; index++)
            if (Math.abs(validScales[index] - displayedScale) < Math.abs(validScales[nearest] - displayedScale))
                nearest = index;
        return nearest;
    }
    readonly property var visiblePresets: {
        var available = settings.presets || [];
        var selected = [];
        for (var mode of ["preferred", "1400x1050", "1920x1080"]) {
            var preset = available.find(function (item) {
                return item.mode.split("@")[0] === mode;
            });
            if (preset)
                selected.push(preset);
        }
        for (var item of available) {
            if (selected.length >= 3)
                break;
            if (selected.indexOf(item) < 0)
                selected.push(item);
        }
        return selected;
    }
    property int pendingPreset: -1
    property int applyingPreset: -1
    property real presetProgress: 0
    readonly property int activePreset: {
        var index = visiblePresets.findIndex(function (preset) {
            return preset.mode.split("@")[0] === root.resolution;
        });
        return Math.max(0, index);
    }
    readonly property int displayedPreset: pendingPreset >= 0 ? pendingPreset : applyingPreset >= 0 ? applyingPreset : activePreset
    readonly property real lowerScale: adjacentScale(-1)
    readonly property real higherScale: adjacentScale(1)
    implicitHeight: content.implicitHeight
    color: "transparent"

    function queuePreset(index) {
        if (!visiblePresets.length || !settings.rules.length)
            return;
        var next = Math.max(0, Math.min(visiblePresets.length - 1, index));
        if (next === activePreset && applyingPreset < 0) {
            pendingPreset = -1;
            presetDelay.stop();
            presetProgressAnimation.stop();
            presetProgress = 0;
            return;
        }
        pendingPreset = next;
        presetProgressAnimation.restart();
        presetDelay.restart();
    }
    function stepPreset(steps) {
        var index = Math.max(0, Math.min(visiblePresets.length - 1, displayedPreset + steps));
        if (index !== displayedPreset)
            queuePreset(index);
    }
    function flushChanges() {
        if (!ready)
            return;
        if (pendingPreset >= 0) {
            if (presetDelay.running)
                return;
            var index = pendingPreset;
            pendingPreset = -1;
            pendingScale = -1;
            applyingPreset = index;
            var preset = visiblePresets[index];
            if (!apply({
                mode: preset.mode,
                scale: preset.scale,
                position: preset.position
            }))
                applyingPreset = -1;
            return;
        }
        flushScale();
    }
    Timer {
        id: presetDelay
        interval: 1000
        onTriggered: root.flushChanges()
    }
    Timer {
        id: presetWheelLock
        interval: 120
    }
    NumberAnimation {
        id: presetProgressAnimation
        target: root
        property: "presetProgress"
        from: 0
        to: 1
        duration: presetDelay.interval
    }
    onDisplayedPresetChanged: Qt.callLater(function () {
        if (!presetWheel.moving)
            presetWheel.positionViewAtIndex(root.displayedPreset, ListView.Center);
    })
    function request(value) {
        if (busy)
            return;
        payload = JSON.stringify(value) + "\n";
        process.stdinEnabled = true;
        process.running = true;
    }
    function scaleLabel(scale) {
        return Number((scale * 100).toFixed(1)) + "%";
    }
    function queueScale(value) {
        if (!validScales.length || !isFinite(value))
            return;
        pendingScale = validScales.reduce(function (nearest, scale) {
            return Math.abs(scale - value) < Math.abs(nearest - value) ? scale : nearest;
        }, validScales[0]);
        scaleDelay.restart();
    }
    function flushScale() {
        if (!ready || pendingScale < 0)
            return;
        var value = pendingScale;
        pendingScale = -1;
        if (Math.abs(value - Number(selectedRule.scale)) < 0.001)
            return;
        applyingScale = value;
        apply({
            scale: value
        });
    }
    Timer {
        id: scaleDelay
        interval: 120
        onTriggered: root.flushScale()
    }
    function adjacentScale(direction) {
        var current = displayedScale;
        var choices = validScales.filter(function (scale) {
            return direction < 0 ? scale < current - 0.001 : scale > current + 0.001;
        });
        return choices.length ? choices[direction < 0 ? choices.length - 1 : 0] : current;
    }
    function refresh() {
        message = "";
        request({
            action: "monitors.state"
        });
    }
    function resetDisplay() {
        if (!ready)
            return;
        presetDelay.stop();
        presetWheelLock.stop();
        presetProgressAnimation.stop();
        scaleDelay.stop();
        presetProgress = 0;
        pendingPreset = -1;
        pendingScale = -1;
        wheelRemainder = 0;
        apply({ mode: "preferred", scale: 1, position: "auto" }, false);
    }
    function apply(changes, preserveMode) {
        if (!ready)
            return false;
        var value = Object.assign({
            mode: selectedRule.mode,
            scale: selectedRule.scale,
            position: selectedRule.position
        }, changes);
        if (value.mode === selectedRule.mode && Number(value.scale) === Number(selectedRule.scale) && value.position === selectedRule.position)
            return false;
        message = "";
        failed = false;
        request({
            action: "monitors.apply",
            preserveMode: preserveMode !== false,
            revision: settings.revision,
            index: 0,
            value: value
        });
        return true;
    }
    onOpenedChanged: {
        if (opened) {
            refresh();
        } else {
            presetDelay.stop();
            presetWheelLock.stop();
            presetProgressAnimation.stop();
            presetProgress = 0;
            pendingPreset = -1;
            pendingScale = -1;
        }
    }
    Component.onCompleted: if (opened)
        refresh()

    Process {
        id: process
        property bool applying: false
        command: ["python3", "-I", "-B", root.script]
        onStarted: {
            applying = JSON.parse(root.payload).action === "monitors.apply";
            write(root.payload);
            stdinEnabled = false;
        }
        onExited: Qt.callLater(function () {
            root.flushChanges();
        })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = JSON.parse(text);
                    root.failed = !result.ok;
                    if (result.ok) {
                        root.settings = result.state;
                        root.message = "";
                    } else {
                        root.message = result.error || "Could not update display settings.";
                    }
                } catch (exception) {
                    root.failed = true;
                    root.message = "Could not read display settings.";
                }
                root.applyingScale = -1;
                root.applyingPreset = -1;
                if (root.failed) {
                    root.pendingScale = -1;
                    root.pendingPreset = -1;
                }
            }
        }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            HyprChoiceButton {
                label: "×"
                implicitWidth: 28
                implicitHeight: 28
                Accessible.name: "Close Hypr"
                onClicked: root.closeRequested()
            }
            Item {
                Layout.fillWidth: true
            }
            Item {
                width: 24
                height: 22
                Rectangle {
                    width: 24
                    height: 16
                    radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: "#b9a3d1"
                }
                Rectangle {
                    x: 8
                    y: 19
                    width: 8
                    height: 1
                    color: Theme.dim
                }
            }
            Item {
                Layout.fillWidth: true
            }
            HyprChoiceButton {
                objectName: "display-reset"
                label: "↻"
                implicitWidth: 28
                implicitHeight: 28
                enabled: root.ready
                Accessible.name: "Reset display settings"
                onClicked: root.resetDisplay()
                ToolTip.visible: hovered
                ToolTip.text: "Reset"
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 174
            Rectangle {
                x: 0
                y: 52
                width: parent.width
                height: 54
                radius: 16
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Theme.surface
                    }
                    GradientStop {
                        position: 0.5
                        color: Theme.selected
                    }
                    GradientStop {
                        position: 1
                        color: Theme.surface
                    }
                }
                border.width: 1
                border.color: Theme.border
                Rectangle {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 18
                    radius: 2
                    color: Theme.accent
                }
            }
            ListView {
                id: presetWheel
                property int dragStartPreset: 0
                objectName: "display-preset-wheel"
                anchors.fill: parent
                anchors.bottomMargin: 16
                model: root.visiblePresets
                currentIndex: root.displayedPreset
                orientation: ListView.Vertical
                clip: true
                snapMode: ListView.SnapToItem
                boundsBehavior: Flickable.StopAtBounds
                maximumFlickVelocity: 180
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: 52
                preferredHighlightEnd: 106
                highlightMoveDuration: 100
                header: Item {
                    height: 52
                    width: 1
                }
                footer: Item {
                    height: 52
                    width: 1
                }
                onCountChanged: Qt.callLater(function () {
                    presetWheel.positionViewAtIndex(root.displayedPreset, ListView.Center);
                })
                onMovementStarted: dragStartPreset = root.displayedPreset
                onMovementEnded: root.queuePreset(Math.max(dragStartPreset - 1, Math.min(dragStartPreset + 1, currentIndex)))
                delegate: Item {
                    id: presetItem
                    required property var modelData
                    required property int index
                    readonly property real distance: Math.min(1, Math.abs(y - presetWheel.contentY + height / 2 - presetWheel.height / 2) / height)
                    objectName: "display-preset-" + index
                    width: presetWheel.width
                    height: 54
                    opacity: 1 - distance * 0.68
                    scale: 1 - distance * 0.12
                    Text {
                        anchors.centerIn: parent
                        text: presetItem.modelData.mode === "preferred" ? "Automatic" : presetItem.modelData.mode.split("@")[0].replace("x", " × ")
                        color: Theme.foreground
                        font.pixelSize: 24
                        font.weight: Font.Medium
                        font.letterSpacing: -0.65
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.settings.rules.length > 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.queuePreset(presetItem.index)
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: (modelData.mode === "preferred" ? "Automatic" : modelData.mode) + " preset"
                    Accessible.onPressAction: root.queuePreset(index)
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    enabled: root.settings.rules.length > 0
                    onWheel: function (event) {
                        var delta = event.angleDelta.y || event.pixelDelta.y;
                        if (!delta)
                            return;
                        if (!presetWheelLock.running) {
                            root.stepPreset(delta > 0 ? -1 : 1);
                        } else if (root.pendingPreset >= 0) {
                            presetDelay.restart();
                            presetProgressAnimation.restart();
                        }
                        presetWheelLock.restart();
                        event.accepted = true;
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 32
                height: 2
                radius: 1
                color: Theme.track
                opacity: root.pendingPreset >= 0 ? 1 : 0
                Rectangle {
                    width: parent.width * root.presetProgress
                    height: parent.height
                    radius: 1
                    color: Theme.accent
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Repeater {
                    model: root.visiblePresets.length
                    Rectangle {
                        required property int index
                        width: 3
                        height: root.displayedPreset === index ? 12 : 3
                        radius: 2
                        color: root.displayedPreset === index ? Theme.accent : "#6d587e"
                        Behavior on height {
                            NumberAnimation {
                                duration: 140
                            }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            HyprChoiceButton {
                objectName: "display-preset-previous"
                label: "⌃"
                implicitWidth: 29
                implicitHeight: 26
                enabled: root.settings.rules.length > 0 && root.displayedPreset > 0
                Accessible.name: "Previous display preset"
                onClicked: root.stepPreset(-1)
            }
            Text {
                text: String(root.displayedPreset + 1).padStart(2, "0") + " / " + String(root.visiblePresets.length).padStart(2, "0")
                color: "#8e7da2"
                font.pixelSize: 10
                font.letterSpacing: 1
            }
            HyprChoiceButton {
                objectName: "display-preset-next"
                label: "⌄"
                implicitWidth: 29
                implicitHeight: 26
                enabled: root.settings.rules.length > 0 && root.displayedPreset < root.visiblePresets.length - 1
                Accessible.name: "Next display preset"
                onClicked: root.stepPreset(1)
            }
        }
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#3d3248"
        }
        Item {
            id: scaleCard
            objectName: "display-scale-control"
            Layout.fillWidth: true
            Layout.preferredHeight: 103
            MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                enabled: root.settings.rules.length > 0
                onWheel: function (event) {
                    var delta = event.angleDelta.y / 120;
                    if (!delta && event.pixelDelta.y)
                        delta = event.pixelDelta.y / 30;
                    root.wheelRemainder += delta;
                    var steps = root.wheelRemainder > 0 ? Math.floor(root.wheelRemainder) : Math.ceil(root.wheelRemainder);
                    root.wheelRemainder -= steps;
                    if (steps) {
                        var index = Math.max(0, Math.min(root.validScales.length - 1, root.scaleIndex + steps));
                        root.queueScale(root.validScales[index]);
                    }
                    event.accepted = true;
                }
            }
            Text {
                y: 2
                text: root.scaleLabel(root.displayedScale)
                color: Theme.foreground
                font.pixelSize: 28
                font.weight: Font.Light
                font.letterSpacing: -1
            }
            Row {
                anchors.right: parent.right
                y: 4
                spacing: 8
                HyprChoiceButton {
                    objectName: "display-scale-decrease"
                    label: "−"
                    implicitWidth: 28
                    implicitHeight: 28
                    enabled: root.settings.rules.length > 0 && root.lowerScale < root.displayedScale
                    Accessible.name: "Decrease display scale"
                    onClicked: root.queueScale(root.lowerScale)
                }
                HyprChoiceButton {
                    objectName: "display-scale-increase"
                    label: "+"
                    implicitWidth: 28
                    implicitHeight: 28
                    enabled: root.settings.rules.length > 0 && root.higherScale > root.displayedScale
                    Accessible.name: "Increase display scale"
                    onClicked: root.queueScale(root.higherScale)
                }
            }
            Slider {
                id: scaleSlider
                objectName: "display-scale-slider"
                y: 48
                width: parent.width
                height: 26
                from: 0
                to: Math.max(1, root.validScales.length - 1)
                stepSize: 1
                snapMode: Slider.SnapAlways
                value: root.scaleIndex
                enabled: root.settings.rules.length > 0 && root.validScales.length > 1
                Accessible.name: "Display scale"
                onMoved: root.queueScale(root.validScales[Math.round(value)])
                background: Rectangle {
                    x: scaleSlider.leftPadding
                    y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                    width: scaleSlider.availableWidth
                    height: 3
                    radius: 2
                    color: "#3a3045"
                    Rectangle {
                        width: scaleSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                    }
                    Repeater {
                        model: root.validScales.length
                        Rectangle {
                            required property int index
                            x: parent.width * index / Math.max(1, root.validScales.length - 1) - 1
                            y: 7
                            width: 2
                            height: 3
                            radius: 1
                            color: index === root.scaleIndex ? Theme.accent : "#554560"
                        }
                    }
                }
                handle: Rectangle {
                    x: scaleSlider.leftPadding + scaleSlider.visualPosition * (scaleSlider.availableWidth - width)
                    y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                    width: 12
                    height: 12
                    radius: 6
                    color: scaleSlider.pressed ? "#ffffff" : "#e0ccf9"
                }
            }
            Text {
                anchors.left: parent.left
                y: 87
                text: "100%"
                color: Theme.dim
                font.pixelSize: 9
            }
            Text {
                anchors.right: parent.right
                y: 87
                text: "200%"
                color: Theme.dim
                font.pixelSize: 9
            }
        }
        Text {
            Layout.fillWidth: true
            visible: root.failed && root.message.length > 0
            text: root.message
            textFormat: Text.PlainText
            color: "#ffac8c"
            wrapMode: Text.Wrap
            font.pixelSize: 10
        }
    }
}
