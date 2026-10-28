pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../services"
import "../style"

// Date with an M3 calendar glyph; hovering shows the month calendar popup
// (Monday-first, today highlighted), clicking opens the weather popup.
Item {
    id: root

    property string screenName: ""
    // Vertical rail: no glyph, numeric date, no side padding.
    property bool compact: false

    implicitWidth: content.implicitWidth + (root.compact ? 0 : 16)
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
            visible: !root.compact
            text: Theme.iconCalendar
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Qt.formatDateTime(clock.date, root.compact ? "dd.MM" : "ddd, dd MMM")
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? Theme.fontSizeLabelMedium : Theme.fontSizeLabelLarge
            font.weight: Font.Medium
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggleWeather(root.screenName)
    }

    // The calendar and the weather card would overlap, so the hover calendar
    // yields while the weather popup is open.
    CalendarPopup {
        id: calendar
        target: root
        shown: hover.hovered && ShellState.weatherScreen !== root.screenName
    }
}
