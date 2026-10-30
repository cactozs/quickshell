pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// System monitor popup for the bar's monitoring chip: usage bars plus
// sparklines for CPU/GPU/RAM, temps, network rates, uptime and load.
// Fullscreen transparent PanelWindow like WeatherPopup, card docked right
// like QuickSettings; Esc or a click outside dismisses it.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.systemScreen === root.modelData.name

    readonly property int pad: 16
    readonly property int cardWidth: 380

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
    WlrLayershell.namespace: "quickshell:system"
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

    // The region only lands on the commit after the frame that set it; kick
    // repaints while the card resizes so the blur can't trail behind it.
    BlurKick {
        id: blurKick

        region: blurRegion
    }

    BlurTarget { item: card; kicker: blurKick }

    // LazyOverlay builds the window already open, so onShownChanged alone
    // would miss the first open; both paths kick the focus.
    Timer {
        id: focusKick
        interval: 50
        onTriggered: keyCatcher.forceActiveFocus()
    }

    Component.onCompleted: {
        if (root.shown)
            focusKick.restart();
    }

    onShownChanged: {
        if (root.shown)
            focusKick.restart();
    }

    // click outside the card dismisses the popup
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeSystem()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                ShellState.closeSystem();
            event.accepted = true;
        }
    }

    // Ambient shadow under the card (New style only); follows the card's
    // entrance fade/scale.
    CardShadow { target: card }

    Rectangle {
        id: card

        // Opens against the bar's edge: under a top bar, above a bottom one,
        // beside a rail.
        x: Theme.popupLeft ? Theme.popupLeftMargin
            : parent.width - width - Theme.popupRightMargin
        y: Theme.popupBottom ? parent.height - height - Theme.popupBottomMargin
            : Theme.popupTopMargin

        width: root.cardWidth
        height: content.implicitHeight + 2 * root.pad
        radius: Theme.shapeLG
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92

        Behavior on opacity { AnimEmph {} }

        Behavior on scale { SpringAnim {} }

        transform: Translate {
            id: drift

            y: root.shown ? 0 : 6

            Behavior on y { Anim {} }
        }

        // Swallow clicks on the card so they don't reach the dismiss area.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.pad
            }

            spacing: 12

            Text {
                width: parent.width
                text: I18n.t("Мониторинг")
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitleMedium
                font.weight: Font.Medium
            }

            Meter {
                title: "CPU"
                value: SystemMonitor.cpuUsage + "% • " + SystemMonitor.cpuTemp
                usage: SystemMonitor.cpuUsage
                series: SystemMonitor.cpuHistory
                fill: Theme.primary
            }

            Meter {
                visible: SystemMonitor.hasGpu
                title: "GPU"
                value: SystemMonitor.gpuUsage + " • " + SystemMonitor.gpuTemp
                usage: SystemMonitor.gpuUsageNum
                series: SystemMonitor.gpuHistory
                fill: Theme.tertiary
            }

            Meter {
                title: "RAM"
                value: SystemMonitor.ramUsage + "% • " + SystemMonitor.ramUsed + " / " + SystemMonitor.ramTotal
                usage: SystemMonitor.ramUsage
                series: SystemMonitor.ramHistory
                fill: Theme.secondary
            }

            Column {
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: I18n.t("Сеть")
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: "↓ " + SystemMonitor.rxSpeed + "   ↑ " + SystemMonitor.txSpeed
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                }
            }

            Text {
                width: parent.width
                visible: SystemMonitor.uptime !== "" || SystemMonitor.loadAvg !== ""
                text: I18n.t("Аптайм ") + SystemMonitor.uptime + (SystemMonitor.loadAvg !== "" ? " • Load " + SystemMonitor.loadAvg : "")
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
            }
        }
    }

    // One metric: label + value row, usage bar, sparkline history.
    component Meter: Column {
        id: meter

        property string title: ""
        property string value: ""
        property int usage: 0
        property var series: []
        property color fill: Theme.primary

        width: parent ? parent.width : 0
        height: implicitHeight
        spacing: 6

        Item {
            width: parent.width
            height: Math.max(titleLabel.implicitHeight, valueLabel.implicitHeight)

            Text {
                id: titleLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: meter.title
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelLarge
                font.weight: Font.Medium
            }

            Text {
                id: valueLabel

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - titleLabel.implicitWidth - 12
                horizontalAlignment: Text.AlignRight
                text: meter.value
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
                elide: Text.ElideRight
            }
        }

        Rectangle {
            width: parent.width
            height: 8
            radius: Theme.shapeFull
            color: Theme.surfaceContainerHighest

            Rectangle {
                width: Math.max(0, Math.min(1, meter.usage / 100)) * parent.width
                height: parent.height
                radius: parent.radius
                color: meter.fill
            }
        }

        Spark {
            width: parent.width
            values: meter.series
            lineColor: meter.fill
        }
    }

    // Minimal sparkline: polyline + translucent fill over 0..100.
    component Spark: Item {
        id: spark

        property var values: []
        property color lineColor: Theme.primary

        height: 40

        Canvas {
            id: canvas

            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const n = spark.values.length;
                if (n < 2)
                    return;
                const yOf = v => height - 2 - (Math.max(0, Math.min(100, v)) / 100 * (height - 4));
                ctx.beginPath();
                ctx.moveTo(0, yOf(spark.values[0]));
                for (let i = 1; i < n; i++)
                    ctx.lineTo(i / (n - 1) * width, yOf(spark.values[i]));
                ctx.lineWidth = 2;
                ctx.lineJoin = "round";
                ctx.strokeStyle = spark.lineColor;
                ctx.stroke();
                // Fill under the line back down to the bottom edge.
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                ctx.closePath();
                ctx.fillStyle = spark.lineColor;
                ctx.globalAlpha = 0.18;
                ctx.fill();
                ctx.globalAlpha = 1;
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Connections {
            target: spark
            function onValuesChanged(): void {
                canvas.requestPaint();
            }
            function onLineColorChanged(): void {
                canvas.requestPaint();
            }
        }

        Component.onCompleted: canvas.requestPaint()
    }
}
