pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// Weather popup for the bar's time chip: current conditions, the next 24 h
// in 3 h steps and a 3-day forecast (services/Weather, Open-Meteo).
// Fullscreen transparent PanelWindow like QuickSettings: only the card under
// the bar is visible, a click outside the card or Esc dismisses it.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.weatherScreen === root.modelData.name

    readonly property int pad: 16

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
    WlrLayershell.namespace: "quickshell:weather"
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

    // What opening the popup does. A lazily built window (LazyOverlay) is born
    // already open, so its onShownChanged never fires; both paths call this.
    function openInit(): void {
        Weather.refresh();
        focusKick.restart();
    }

    Component.onCompleted: {
        if (root.shown)
            root.openInit();
    }

    onShownChanged: {
        if (root.shown)
            root.openInit();
    }

    // Layer surfaces take a moment to gain keyboard focus; make sure the key
    // catcher ends up active either way.
    Timer {
        id: focusKick
        interval: 50
        onTriggered: keyCatcher.forceActiveFocus()
    }

    // click outside the card dismisses the popup
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeWeather()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                ShellState.closeWeather();
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

        // Centered on a top/bottom bar's edge, beside a side rail.
        x: ShellState.barPosition === "left" ? Theme.popupLeftMargin
            : ShellState.barPosition === "right" ? parent.width - width - Theme.popupRightMargin
            : Math.round((parent.width - width) / 2)
        anchors.top: Theme.popupBottom ? undefined : parent.top
        anchors.bottom: Theme.popupBottom ? parent.bottom : undefined
        anchors.topMargin: Theme.popupTopMargin
        anchors.bottomMargin: Theme.popupBottomMargin

        width: (content.visible ? content.implicitWidth : status.implicitWidth) + 2 * root.pad
        height: (content.visible ? content.implicitHeight : status.implicitHeight) + 2 * root.pad
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

        Text {
            id: status

            visible: !Weather.hasData
            anchors.centerIn: parent
            text: I18n.t(Weather.error !== "" ? Weather.error : "Загрузка…")
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
        }

        Column {
            id: content

            visible: Weather.hasData
            anchors.centerIn: parent
            spacing: 12

            Row {
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.icon
                    color: Theme.primary
                    font.family: Theme.iconFont
                    font.pixelSize: 44
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: Math.round(Weather.temp) + "°"
                        color: Theme.surfaceText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeHeadlineMedium
                        font.weight: Font.Medium
                    }

                    Text {
                        text: I18n.t(Weather.label)
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelLarge
                    }
                }
            }

            Text {
                text: I18n.t("Ощущается ") + Math.round(Weather.feels) + I18n.t("° • Ветер ") + Math.round(Weather.wind) + I18n.t(" м/с • Влажность ") + Weather.humidity + "%"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
            }

            Row {
                id: hoursRow

                spacing: 4

                Repeater {
                    model: Weather.hours

                    delegate: Column {
                        required property var modelData

                        width: 52
                        spacing: 4

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.hour
                            color: Theme.surfaceVariantText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelMedium
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.icon
                            color: Theme.surfaceVariantText
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.temp + "°"
                            color: Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelLarge
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Column {
                spacing: 4

                Repeater {
                    model: Weather.days

                    delegate: Row {
                        required property var modelData

                        width: hoursRow.width

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 90
                            text: I18n.t(modelData.day)
                            color: Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelLarge
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.icon
                            color: Theme.surfaceVariantText
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.tmin + "° … " + modelData.tmax + "°"
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
