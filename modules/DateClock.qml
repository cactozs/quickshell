pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../style"

// Date with an M3 calendar glyph; hovering shows the month calendar popup
// (Monday-first, today highlighted).
Item {
    id: root

    implicitWidth: content.implicitWidth + 16
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Theme.iconCalendar
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Qt.formatDateTime(clock.date, "ddd, dd MMM")
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            font.weight: Font.Medium
        }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: calendar.shown = hovered
    }

    CalendarPopup {
        id: calendar
        target: root
    }
}
