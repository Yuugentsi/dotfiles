import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../controls"
import QtQuick.Controls

Item {
    id: root
    property bool opened: false
    signal backRequested
    signal panelRequested(string panel)
    property var state: ({
            brightnessAvailable: false,
            brightness: 75,
            sunsetAvailable: false,
            sunsetRunning: false,
            temperature: 2700,
            gamma: 100,
            nightEnabled: false
        })
    property var confirmedState: state
    property var pending: ({})
    property string error: ""
    property string actionPayload: ""
    property int revision: 0
    readonly property bool busy: action.running || Object.keys(pending).length > 0
    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/display.py"
    readonly property var profiles: [
        {
            key: "study",
            label: "Study",
            icon: "\uf19d",
            brightness: 75,
            gamma: 95,
            temperature: 2700,
            night: true
        },
        {
            key: "reading",
            label: "Reading",
            icon: "\uf02d",
            brightness: 55,
            gamma: 85,
            temperature: 2200,
            night: true
        },
        {
            key: "sleep",
            label: "Sleep",
            icon: "\uf186",
            brightness: 40,
            gamma: 70,
            temperature: 1400,
            night: true
        }
    ]
    readonly property string activeProfile: {
        var selected = profiles.find(function (profile) {
            return (!root.state.brightnessAvailable || Math.abs(root.state.brightness - profile.brightness) < 2) && (!root.state.sunsetAvailable || (Math.abs(root.state.gamma - profile.gamma) < 1 && root.state.nightEnabled === profile.night && (!profile.night || Math.abs(root.state.temperature - profile.temperature) < 50)));
        });
        return selected ? selected.key : "";
    }
    function applyProfile(name) {
        var profile = profiles.find(function (profile) {
            return profile.key === name;
        });
        if (!profile || (!state.brightnessAvailable && !state.sunsetAvailable))
            return;
        error = "";
        revision += 1;
        var next = Object.assign({}, pending);
        delete next.temperature;
        delete next.night;
        if (state.brightnessAvailable)
            next.brightness = profile.brightness;
        if (state.sunsetAvailable) {
            next.gamma = profile.gamma;
            next.temperature = profile.temperature;
            next.night = profile.night;
        }
        pending = next;
        state = mergePending(state);
        changeDelay.restart();
    }
    function open() {
        opened = true;
        refresh();
    }
    function close() {
        opened = false;
    }
    function toggle() {
        if (opened)
            close();
        else
            open();
    }
    function refresh() {
        if (!query.running && !busy)
            query.running = true;
    }
    function mergePending(value) {
        var next = Object.assign({}, value);
        for (var key of Object.keys(pending)) {
            next[key === "night" ? "nightEnabled" : key] = pending[key];
            if (key === "temperature")
                next.nightEnabled = true;
        }
        return next;
    }
    function setValue(name, value) {
        error = "";
        revision += 1;
        var next = Object.assign({}, pending);
        next[name] = value;
        pending = next;
        state = mergePending(state);
        changeDelay.restart();
    }
    function flush() {
        if (action.running || !Object.keys(pending).length)
            return;
        var name = Object.keys(pending)[0];
        var value = pending[name];
        var next = Object.assign({}, pending);
        delete next[name];
        pending = next;
        actionPayload = JSON.stringify({
            action: name,
            value: value
        }) + "\n";
        action.stdinEnabled = true;
        action.running = true;
    }
    Timer {
        id: changeDelay
        interval: 120
        onTriggered: root.flush()
    }
    Timer {
        interval: 3000
        running: root.opened
        repeat: true
        onTriggered: root.refresh()
    }
    Process {
        id: query
        property int requestedRevision: 0
        command: ["python3", "-I", "-B", root.script]
        onStarted: {
            requestedRevision = root.revision;
            write('{"action":"state"}\n');
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (query.requestedRevision !== root.revision)
                    return;
                try {
                    var result = JSON.parse(text);
                    if (result.ok) {
                        root.confirmedState = result.state;
                        root.state = root.mergePending(result.state);
                    } else
                        root.error = result.error || "Could not read display controls.";
                } catch (exception) {
                    root.error = "Could not read display controls.";
                }
            }
        }
    }
    Process {
        id: action
        command: ["python3", "-I", "-B", root.script]
        onStarted: {
            write(root.actionPayload);
            root.actionPayload = "";
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = JSON.parse(text);
                    if (result.ok)
                        root.confirmedState = result.state;
                    else
                        root.error = result.error || "Could not change display settings.";
                } catch (exception) {
                    root.error = "Could not change display settings.";
                }
                root.state = root.mergePending(root.confirmedState);
            }
        }
        onExited: Qt.callLater(function () {
            root.flush();
        })
    }
    IpcHandler {
        target: "display"
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
    }
    PanelWindow {
        id: panel
        visible: root.opened
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "display"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Rectangle {
            anchors.fill: parent
            color: "#ac080e16"
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
        PanelNavigation {
            x: 16
            y: 8
            width: parent.width - 32
            currentPanel: "display"
            onSelected: function (panel) {
                root.panelRequested(panel);
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(420, panel.width - 32)
            height: Math.min(view.implicitHeight + 40, panel.height - 112)
            radius: 24
            color: "#18111f"
            border.width: 1
            border.color: "#50365f"
            focus: true
            Keys.onEscapePressed: root.close()
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            DisplayView {
                id: view
                anchors.fill: parent
                anchors.margins: 20
                backend: root
            }
        }
    }

    component CyberFrame: Item {
        id: cyberFrameRoot
        property color fillColor: "#100d18"
        property color strokeColor: "#67477c"
        property real cut: 14
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                strokeColor: cyberFrameRoot.strokeColor
                strokeWidth: 1
                fillColor: cyberFrameRoot.fillColor
                startX: 1
                startY: cyberFrameRoot.cut
                PathLine {
                    x: cyberFrameRoot.cut
                    y: 1
                }
                PathLine {
                    x: cyberFrameRoot.width - cyberFrameRoot.cut
                    y: 1
                }
                PathLine {
                    x: cyberFrameRoot.width - 1
                    y: cyberFrameRoot.cut
                }
                PathLine {
                    x: cyberFrameRoot.width - 1
                    y: cyberFrameRoot.height - cyberFrameRoot.cut
                }
                PathLine {
                    x: cyberFrameRoot.width - cyberFrameRoot.cut
                    y: cyberFrameRoot.height - 1
                }
                PathLine {
                    x: 1
                    y: cyberFrameRoot.height - 1
                }
                PathLine {
                    x: 1
                    y: cyberFrameRoot.cut
                }
            }
        }
    }

    component DisplayViewLabelText: Text {

        color: "#bba6ca"
        font.family: "sans-serif"
        font.pixelSize: 12
    }

    component DisplayViewGlyph: Text {

        font.family: "Symbols Nerd Font Mono"
    }

    component DisplayViewLightSlider: Slider {
        id: displayViewLightSliderSlider
        required property var contextRoot
        opacity: enabled ? 1 : 0.3
        background: Rectangle {
            x: displayViewLightSliderSlider.leftPadding
            y: displayViewLightSliderSlider.topPadding + displayViewLightSliderSlider.availableHeight / 2 - height / 2
            width: displayViewLightSliderSlider.availableWidth
            height: 4
            radius: 2
            color: "#493451"
            Rectangle {
                width: displayViewLightSliderSlider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: contextRoot.accent
            }
        }
        handle: Rectangle {
            x: displayViewLightSliderSlider.leftPadding + displayViewLightSliderSlider.visualPosition * (displayViewLightSliderSlider.availableWidth - width)
            y: displayViewLightSliderSlider.topPadding + displayViewLightSliderSlider.availableHeight / 2 - height / 2
            width: 11
            height: 11
            radius: 6
            color: displayViewLightSliderSlider.pressed ? "#ffffff" : "#dcc6ff"
        }
    }

    component DisplayView: Item {
        id: displayViewRoot
        required property var backend
        readonly property color accent: "#c3a0ff"
        readonly property color ember: "#ff9c66"
        implicitHeight: displayViewContent.implicitHeight
        ScrollView {
            id: displayViewScroll
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Column {
                id: displayViewContent
                width: displayViewScroll.availableWidth
                spacing: 14
                Item {
                    width: parent.width
                    height: 44
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 13
                        color: "#39253e"
                        DisplayViewGlyph {
                            anchors.centerIn: parent
                            text: "\uf185"
                            color: displayViewRoot.ember
                            font.pixelSize: 19
                        }
                    }
                    DisplayViewLabelText {
                        x: 52
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Display"
                        color: "#f3eaff"
                        font.pixelSize: 21
                        font.weight: Font.DemiBold
                    }
                    Button {
                        id: displayViewCloseButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        Accessible.name: "Close display"
                        onClicked: displayViewRoot.backend.close()
                        contentItem: DisplayViewLabelText {
                            text: "×"
                            color: displayViewCloseButton.hovered ? "#f8efff" : "#a08bae"
                            font.pixelSize: 21
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 10
                            color: displayViewCloseButton.hovered ? "#3b2a47" : "#271d30"
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 12
                    color: "#211728"
                    Row {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 3
                        Repeater {
                            model: displayViewRoot.backend.profiles
                            Button {
                                id: displayViewModeButton
                                required property var modelData
                                readonly property bool selected: displayViewRoot.backend.activeProfile === modelData.key
                                objectName: "display-profile-" + modelData.key
                                width: (displayViewContent.width - 12) / 3
                                height: 34
                                enabled: displayViewRoot.backend.state.brightnessAvailable || displayViewRoot.backend.state.sunsetAvailable
                                hoverEnabled: true
                                Accessible.name: modelData.label + " display profile"
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: selected
                                onClicked: {
                                    displayViewProfileHover.stop();
                                    displayViewRoot.backend.applyProfile(modelData.key);
                                }
                                onHoveredChanged: {
                                    if (hovered)
                                        displayViewProfileHover.restart();
                                    else
                                        displayViewProfileHover.stop();
                                }
                                Timer {
                                    id: displayViewProfileHover
                                    interval: 320
                                    onTriggered: if (displayViewModeButton.hovered && displayViewModeButton.enabled && !displayViewModeButton.selected && !displayViewRoot.backend.busy)
                                        displayViewRoot.backend.applyProfile(displayViewModeButton.modelData.key)
                                }
                                contentItem: Item {
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 7
                                        DisplayViewGlyph {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: displayViewModeButton.modelData.icon
                                            color: displayViewModeButton.selected ? displayViewRoot.ember : "#9e83b0"
                                            font.pixelSize: 12
                                        }
                                        DisplayViewLabelText {
                                            text: displayViewModeButton.modelData.label
                                            color: displayViewModeButton.selected ? "#f0dfff" : "#b6a0c5"
                                            font.pixelSize: 11
                                            font.weight: displayViewModeButton.selected ? Font.DemiBold : Font.Normal
                                        }
                                    }
                                }
                                background: Rectangle {
                                    radius: 9
                                    color: displayViewModeButton.selected ? "#45304f" : displayViewModeButton.hovered ? "#302039" : "transparent"
                                    border.width: displayViewModeButton.selected ? 1 : 0
                                    border.color: "#80608e"
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 130
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Row {
                    width: parent.width
                    spacing: 10
                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: 116
                        radius: 17
                        color: "#251b30"
                        border.width: 1
                        border.color: "#3b2b49"
                        DisplayViewGlyph {
                            x: 14
                            y: 14
                            text: "\uf185"
                            color: displayViewRoot.ember
                            font.pixelSize: 13
                        }
                        DisplayViewLabelText {
                            x: 35
                            y: 14
                            text: "Brightness"
                            font.pixelSize: 11
                        }
                        DisplayViewLabelText {
                            x: 14
                            y: 37
                            text: displayViewRoot.backend.state.brightnessAvailable ? Math.round(displayViewBrightness.value) + "%" : "—"
                            color: "#f0e6ff"
                            font.pixelSize: 25
                            font.weight: Font.Medium
                        }
                        DisplayViewLightSlider {
                            id: displayViewBrightness
                            contextRoot: displayViewRoot
                            objectName: "displayBrightness"
                            x: 12
                            y: 78
                            width: parent.width - 24
                            height: 26
                            from: 10
                            to: 100
                            stepSize: 5
                            snapMode: Slider.SnapAlways
                            value: displayViewRoot.backend.state.brightness
                            enabled: displayViewRoot.backend.state.brightnessAvailable
                            Accessible.name: "Display brightness"
                            onMoved: displayViewRoot.backend.setValue("brightness", Math.round(value))
                        }
                    }
                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: 116
                        radius: 17
                        color: "#251b30"
                        border.width: 1
                        border.color: "#3b2b49"
                        DisplayViewGlyph {
                            x: 14
                            y: 14
                            text: "\uf042"
                            color: displayViewRoot.accent
                            font.pixelSize: 13
                        }
                        DisplayViewLabelText {
                            x: 35
                            y: 14
                            text: "Gamma"
                            font.pixelSize: 11
                        }
                        DisplayViewLabelText {
                            x: 14
                            y: 37
                            text: Math.round(displayViewGamma.value) + "%"
                            color: "#f0e6ff"
                            font.pixelSize: 25
                            font.weight: Font.Medium
                        }
                        DisplayViewLightSlider {
                            id: displayViewGamma
                            contextRoot: displayViewRoot
                            objectName: "displayGamma"
                            x: 12
                            y: 78
                            width: parent.width - 24
                            height: 26
                            from: 30
                            to: 100
                            stepSize: 5
                            snapMode: Slider.SnapAlways
                            value: displayViewRoot.backend.state.gamma
                            enabled: displayViewRoot.backend.state.sunsetAvailable
                            Accessible.name: "Display gamma"
                            onMoved: displayViewRoot.backend.setValue("gamma", Math.round(value))
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: displayViewRoot.backend.state.nightEnabled ? 260 : 64
                    radius: 18
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#2b1c36"
                        }
                        GradientStop {
                            position: 1
                            color: "#1f1729"
                        }
                    }
                    border.width: 1
                    border.color: displayViewRoot.backend.state.nightEnabled ? "#5b3e70" : "#3b2b49"
                    Item {
                        x: 16
                        y: 16
                        width: parent.width - 32
                        height: 32
                        DisplayViewGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf186"
                            color: displayViewRoot.ember
                            font.pixelSize: 17
                        }
                        DisplayViewLabelText {
                            x: 28
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Night light"
                            color: "#e7d6f5"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        ToggleSwitch {
                            objectName: "displayNight"
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: !!displayViewRoot.backend.state.nightEnabled
                            enabled: displayViewRoot.backend.state.sunsetAvailable
                            activeFocusOnTab: true
                            Accessible.role: Accessible.CheckBox
                            Accessible.name: "Night light"
                            Accessible.checked: checked
                            onToggled: displayViewRoot.backend.setValue("night", !checked)
                            Keys.onSpacePressed: displayViewRoot.backend.setValue("night", !checked)
                            Keys.onReturnPressed: displayViewRoot.backend.setValue("night", !checked)
                        }
                    }
                    Dial {
                        id: displayViewTemperature
                        objectName: "displayTemperature"
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 55
                        width: 188
                        height: 188
                        visible: !!displayViewRoot.backend.state.nightEnabled
                        from: 1000
                        to: 2700
                        stepSize: 100
                        value: displayViewRoot.backend.state.temperature
                        wrap: false
                        Accessible.name: "Color temperature"
                        onMoved: displayViewRoot.backend.setValue("temperature", Math.round(value))
                        background: Canvas {
                            id: displayViewDialCanvas
                            anchors.fill: parent
                            onPaint: {
                                var context = getContext("2d");
                                context.clearRect(0, 0, width, height);
                                var center = width / 2;
                                var radius = width / 2 - 14;
                                var start = 130 * Math.PI / 180;
                                var span = 280 * Math.PI / 180;
                                context.lineWidth = 7;
                                context.lineCap = "round";
                                context.strokeStyle = "#493053";
                                context.beginPath();
                                context.arc(center, center, radius, start, start + span);
                                context.stroke();
                                var gradient = context.createLinearGradient(0, height, width, 0);
                                gradient.addColorStop(0, "#ff9c66");
                                gradient.addColorStop(0.5, "#cf8dbc");
                                gradient.addColorStop(1, "#c3a0ff");
                                context.strokeStyle = gradient;
                                context.beginPath();
                                context.arc(center, center, radius, start, start + span * displayViewTemperature.position);
                                context.stroke();
                            }
                            Connections {
                                target: displayViewTemperature
                                function onValueChanged() {
                                    displayViewDialCanvas.requestPaint();
                                }
                            }
                        }
                        handle: Rectangle {
                            x: displayViewTemperature.width / 2 + (displayViewTemperature.width / 2 - 14) * Math.cos((displayViewTemperature.angle - 90) * Math.PI / 180) - width / 2
                            y: displayViewTemperature.height / 2 + (displayViewTemperature.height / 2 - 14) * Math.sin((displayViewTemperature.angle - 90) * Math.PI / 180) - height / 2
                            width: 15
                            height: 15
                            radius: 8
                            color: "#f5eaff"
                            border.width: 3
                            border.color: "#9b72bc"
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            DisplayViewLabelText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Math.round(displayViewTemperature.value)
                                color: "#f5eaff"
                                font.pixelSize: 35
                                font.weight: Font.Light
                            }
                            DisplayViewLabelText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Kelvin"
                                font.pixelSize: 10
                                color: "#aa91bd"
                            }
                        }
                        DisplayViewLabelText {
                            x: 15
                            y: parent.height - 20
                            text: "1000"
                            font.pixelSize: 9
                            color: displayViewRoot.ember
                        }
                        DisplayViewLabelText {
                            anchors.right: parent.right
                            anchors.rightMargin: 15
                            y: parent.height - 20
                            text: "2700"
                            font.pixelSize: 9
                            color: displayViewRoot.accent
                        }
                    }
                }
                DisplayViewLabelText {
                    width: parent.width
                    visible: !!displayViewRoot.backend.error
                    text: displayViewRoot.backend.error
                    textFormat: Text.PlainText
                    color: "#ffac8c"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
