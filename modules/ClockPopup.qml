pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// Clock popup for the bar's time chip: a countdown and a stopwatch. Same
// fullscreen transparent PanelWindow as WeatherPopup; the state itself lives
// in services/ClockTools so it keeps running after this window is destroyed.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.clockScreen === root.modelData.name

    readonly property int pad: 16
    readonly property int innerWidth: 340

    // "timer" | "stopwatch"; the window is rebuilt closed, so it always opens
    // on the timer.
    property string mode: "timer"

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || card.opacity > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:clock"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Acrylic behind the card (New and Blur). Off as soon as it closes: a
    // compositor blur region cannot fade, so it would hang under the card.
    BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurRegion : null

    // Unscaled twin of the card for the blur region: it only rebuilds on
    // x/y/w/h changes, so it must not see the entrance scale.
    Item {
        id: blurAnchor
        anchors.fill: card
    }

    Region {
        id: blurRegion

        Region { item: blurAnchor; radius: card.radius }
    }

    // Focus the duration field so digits can be typed right away; the layer
    // surface needs a moment to gain keyboard focus, hence the kick.
    function openInit(): void {
        focusKick.restart();
    }

    function focusInput(): void {
        if (root.mode === "timer")
            durationInput.forceActiveFocus();
        else
            keyCatcher.forceActiveFocus();
    }

    // Typing "5" or "5:30" in the duration field and pressing Enter starts a
    // new countdown.
    function applyDuration(): void {
        const text = durationInput.text.trim();
        const match = text.match(/^(\d{1,3})(?::(\d{0,2}))?$/);
        durationInput.text = "";
        if (!match)
            return;
        const minutes = parseInt(match[1]);
        const seconds = match[2] !== undefined && match[2] !== "" ? parseInt(match[2]) : 0;
        if (seconds > 59)
            return;
        const ms = (minutes * 60 + seconds) * 1000;
        if (ms <= 0)
            return;
        ClockTools.setCountdown(ms);
        ClockTools.startCountdown();
    }

    Component.onCompleted: {
        if (root.shown)
            root.openInit();
    }

    onShownChanged: {
        if (root.shown)
            root.openInit();
    }

    Timer {
        id: focusKick
        interval: 50
        onTriggered: root.focusInput()
    }

    // click outside the card dismisses the popup
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeClock()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                ShellState.closeClock();
            event.accepted = true;
        }
    }

    // Ambient shadow under the card (New style only); follows the card's
    // entrance fade/scale.
    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: Theme.glass
        opacity: card.opacity
        scale: card.scale
    }

    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.barHeight + 2 * Theme.barMargin

        width: root.innerWidth + 2 * root.pad
        height: body.implicitHeight + 2 * root.pad
        radius: Theme.shapeLG
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        transform: Translate {
            id: drift

            y: root.shown ? 0 : 6

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }
            }
        }

        // Swallow clicks on the card so they don't reach the dismiss area.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: body

            width: root.innerWidth
            anchors.centerIn: parent
            spacing: 14

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                IconButton {
                    hPadding: 14
                    label: I18n.t("Таймер")
                    containerColor: root.mode === "timer" ? Theme.primaryContainer : Theme.surfaceContainerHighest
                    contentColor: root.mode === "timer" ? Theme.primaryContainerText : Theme.surfaceText
                    onClicked: {
                        root.mode = "timer";
                        Qt.callLater(root.focusInput);
                    }
                }

                IconButton {
                    hPadding: 14
                    label: I18n.t("Секундомер")
                    containerColor: root.mode === "stopwatch" ? Theme.primaryContainer : Theme.surfaceContainerHighest
                    contentColor: root.mode === "stopwatch" ? Theme.primaryContainerText : Theme.surfaceText
                    onClicked: {
                        root.mode = "stopwatch";
                        Qt.callLater(root.focusInput);
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 12
                visible: root.mode === "timer"

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: ClockTools.format(ClockTools.countdownLeftMs, true)
                    color: ClockTools.countdownRunning ? Theme.primary : Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeDisplayMedium
                    font.weight: Font.Medium
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("Длительность")
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelMedium
                    }

                    Rectangle {
                        width: 92
                        height: 32
                        radius: Theme.chipRadius
                        color: Theme.surfaceContainerHighest

                        TextInput {
                            id: durationInput

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            color: Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBodyMedium

                            validator: RegularExpressionValidator {
                                regularExpression: /[0-9:]{0,6}/
                            }

                            onAccepted: root.applyDuration()

                            Keys.onEscapePressed: ShellState.closeClock()
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: durationInput.text === ""
                            text: I18n.t("мин:сек")
                            color: Theme.surfaceVariantText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBodyMedium
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Repeater {
                        model: [1, 5, 10, 15, 25, 45]

                        delegate: IconButton {
                            required property int modelData

                            hPadding: 10
                            label: "" + modelData
                            containerColor: ClockTools.countdownTotal === modelData * 60000
                                ? Theme.primaryContainer
                                : Theme.surfaceContainerHighest
                            contentColor: ClockTools.countdownTotal === modelData * 60000
                                ? Theme.primaryContainerText
                                : Theme.surfaceText
                            onClicked: ClockTools.setCountdown(modelData * 60000)
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    IconButton {
                        icon: ClockTools.countdownRunning ? Theme.iconPause : Theme.iconPlay
                        label: ClockTools.countdownRunning ? I18n.t("Пауза") : I18n.t("Старт")
                        containerColor: Theme.primary
                        contentColor: Theme.primaryText
                        onClicked: ClockTools.toggleCountdown()
                    }

                    IconButton {
                        icon: Theme.iconRestart
                        label: I18n.t("Сброс")
                        containerColor: Theme.surfaceContainerHighest
                        contentColor: Theme.surfaceText
                        onClicked: ClockTools.resetCountdown()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 12
                visible: root.mode === "stopwatch"

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: ClockTools.formatStopwatch(ClockTools.stopwatchElapsedMs)
                    color: ClockTools.stopwatchRunning ? Theme.primary : Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeDisplayMedium
                    font.weight: Font.Medium
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    IconButton {
                        icon: ClockTools.stopwatchRunning ? Theme.iconPause : Theme.iconPlay
                        label: ClockTools.stopwatchRunning ? I18n.t("Пауза") : I18n.t("Старт")
                        containerColor: Theme.primary
                        contentColor: Theme.primaryText
                        onClicked: ClockTools.toggleStopwatch()
                    }

                    IconButton {
                        icon: ClockTools.stopwatchRunning ? "" : Theme.iconRestart
                        label: ClockTools.stopwatchRunning ? I18n.t("Круг") : I18n.t("Сброс")
                        containerColor: Theme.surfaceContainerHighest
                        contentColor: Theme.surfaceText
                        onClicked: {
                            if (ClockTools.stopwatchRunning)
                                ClockTools.lapStopwatch();
                            else
                                ClockTools.resetStopwatch();
                        }
                    }
                }

                Flickable {
                    id: lapList

                    width: parent.width
                    height: Math.min(lapColumn.height, 140)
                    contentHeight: lapColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: ClockTools.laps.length > 0

                    Column {
                        id: lapColumn

                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: ClockTools.laps

                            delegate: Item {
                                required property var modelData

                                width: lapColumn.width
                                height: 24

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.t("Круг ") + modelData.n
                                    color: Theme.surfaceVariantText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabelLarge
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ClockTools.formatStopwatch(modelData.ms)
                                    color: Theme.surfaceText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabelLarge
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
