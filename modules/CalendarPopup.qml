pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../style"

// Month calendar popup for the bar's date chip: fixed-cell grid (Monday-first)
// with today on a primary circle, so the columns actually align. The data is
// rebuilt on every show so it survives midnight; the owner drives `visible`.
PopupWindow {
    id: root

    required property Item target

    property var cal: null

    readonly property var monthNames: [
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ]
    readonly property var dayNames: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    readonly property int cell: 30
    readonly property int cellSpacing: 2
    readonly property int pad: 14
    readonly property int gridWidth: cell * 7 + cellSpacing * 6

    visible: false
    color: "transparent"

    anchor.item: target
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    implicitWidth: column.implicitWidth + 2 * root.pad
    implicitHeight: column.implicitHeight + 2 * root.pad

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

    onVisibleChanged: {
        if (visible) {
            root.build();
            showAnim.restart();
        } else {
            surface.opacity = 0;
            drift.y = 6;
        }
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.shapeLG
        color: Theme.surfaceContainerHighest
        opacity: 0

        transform: Translate {
            id: drift
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
                font.pixelSize: Theme.fontSizeLabelLarge
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
                            width: 26
                            height: 26
                            radius: width / 2
                            color: dayCell.isToday ? Theme.primary : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.day
                            color: dayCell.isToday ? Theme.primaryText : Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelMedium
                            font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: showAnim

        NumberAnimation {
            target: surface
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEmphasized
        }

        NumberAnimation {
            target: drift
            property: "y"
            from: 6
            to: 0
            duration: Theme.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEmphasizedDecelerate
        }
    }
}
