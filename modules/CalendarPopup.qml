pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// Month calendar popup for the bar's date chip: fixed-cell grid (Monday-first)
// with today on a primary circle, so the columns actually align. The data is
// rebuilt on every show so it survives midnight; the owner drives `visible`.
PopupWindow {
    id: root

    required property Item target

    property var cal: null

    readonly property var monthNames: I18n.t([
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ])
    readonly property var dayNames: I18n.t(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"])

    readonly property int cell: 34
    readonly property int cellSpacing: 2
    readonly property int pad: 14
    readonly property int gridWidth: cell * 7 + cellSpacing * 6

    // Open state, driven by the owner (DateClock); the popup stays mapped
    // while the exit animation plays.
    property bool shown: false

    visible: shown || surface.opacity > 0.001
    color: "transparent"

    anchor.item: target
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    implicitWidth: column.implicitWidth + 2 * root.pad
    implicitHeight: column.implicitHeight + 2 * root.pad

    // Ambient shadow under the surface (New style only); follows its
    // entrance fade/scale. No acrylic: blur needs a panel window, not a popup.
    RectangularShadow {
        anchors.fill: surface
        radius: surface.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: Theme.glass
        opacity: surface.opacity
        scale: surface.scale
    }

    function build(): void {
        const now = new Date();
        const y = now.getFullYear();
        const m = now.getMonth();
        root.cal = {
            "title": root.monthNames[m] + " " + y,
            // Monday-first offset of the 1st (Date.getDay() is Sunday-first).
            "offset": (new Date(y, m, 1).getDay() + 6) % 7,
            "days": new Date(y, m + 1, 0).getDate(),
            "today": now.getDate()
        };
    }

    onShownChanged: {
        if (root.shown)
            root.build();
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.shapeLG
        // No acrylic on a popup window, so the solid twin of the chip tone.
        color: Theme.popupSurface
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

        Column {
            id: column

            anchors.centerIn: parent
            spacing: 10

            Text {
                width: root.gridWidth
                text: root.cal ? root.cal.title : ""
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitleMedium
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
            }

            Grid {
                columns: 7
                spacing: root.cellSpacing

                Repeater {
                    model: root.dayNames

                    Text {
                        required property string modelData

                        width: root.cell
                        height: 20
                        text: modelData
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelMedium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Grid {
                columns: 7
                spacing: root.cellSpacing

                // Leading blanks, so the 1st lands under its weekday.
                Repeater {
                    model: root.cal ? root.cal.offset : 0

                    delegate: Item {
                        width: root.cell
                        height: root.cell
                    }
                }

                Repeater {
                    model: root.cal ? root.cal.days : 0

                    delegate: Item {
                        id: dayCell

                        required property int index

                        readonly property int day: index + 1
                        readonly property bool isToday: root.cal !== null && day === root.cal.today

                        width: root.cell
                        height: root.cell

                        Rectangle {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            radius: Theme.shapeFull
                            color: "transparent"
                            // M3 date picker: today is outlined, not filled.
                            border.width: dayCell.isToday ? 1 : 0
                            border.color: dayCell.isToday ? Theme.primary : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.day
                            color: dayCell.isToday ? Theme.primary : Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelMedium
                            font.weight: dayCell.isToday ? Font.Medium : Font.Normal
                        }
                    }
                }
            }
        }
    }

}
