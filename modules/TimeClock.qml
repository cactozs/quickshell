pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../services"
import "../style"

// Clock with an M3 schedule glyph; click toggles the clock popup (timer and
// stopwatch).
Item {
    id: root

    property string screenName: ""
    // Vertical rail: no glyph, no AM/PM, and no side padding (the island has it).
    property bool compact: false

    implicitWidth: content.implicitWidth + (root.compact ? 0 : 16)
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: !root.compact
            text: Theme.iconClock
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Qt.formatDateTime(clock.date, root.compact ? "hh:mm" : "hh:mm AP")
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? Theme.fontSizeLabelMedium : Theme.fontSizeLabelLarge
            font.weight: Font.Medium
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggleClock(root.screenName)
    }
}
