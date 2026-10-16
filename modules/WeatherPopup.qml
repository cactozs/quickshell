pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// Weather popup for the bar's time chip: current conditions, the next 24 h
// in 3 h steps and a 3-day forecast (services/Weather, Open-Meteo).
// The owner drives `visible` via `shown`, like CalendarPopup.
// shortcut: closes only by re-clicking the clock, add outside-click dismiss when annoying.
PopupWindow {
    id: root

    required property Item target

    property bool shown: false

    readonly property int pad: 16

    visible: shown || surface.opacity > 0.001
    color: "transparent"

    anchor.item: target
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    implicitWidth: (content.visible ? content.implicitWidth : status.implicitWidth) + 2 * root.pad
    implicitHeight: (content.visible ? content.implicitHeight : status.implicitHeight) + 2 * root.pad

    onShownChanged: {
        if (root.shown)
            Weather.refresh();
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.shapeLG
        color: Theme.surfaceContainerHighest

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

        Text {
            id: status

            visible: !Weather.hasData
            anchors.centerIn: parent
            text: Weather.error !== "" ? Weather.error : "Загрузка…"
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
                        text: Weather.label
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelLarge
                    }
                }
            }

            Text {
                text: "Ощущается " + Math.round(Weather.feels) + "° • Ветер " + Math.round(Weather.wind) + " м/с • Влажность " + Weather.humidity + "%"
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
                            text: modelData.day
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
