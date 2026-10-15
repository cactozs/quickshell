pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../style"

// M3 Expressive bar: a floating pill (surfaceContainer, corner-full, 6 px
// gaps) hosting the niri workspaces, window title, clock and status chips.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: Theme.barMargin
        left: Theme.barMargin
        right: Theme.barMargin
    }

    // Bar bottom sits at barMargin + barHeight; windows start one barMargin
    // below it. Quickshell adds `margins` to this value on top of it.
    exclusiveZone: Theme.barHeight + Theme.barMargin
    implicitHeight: Theme.barHeight
    color: "transparent"

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.shapeFull
        color: Theme.surfaceContainer

        Behavior on color {
            ColorAnimation {
                duration: Theme.durLong
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        // left: workspaces + focused window title
        Row {
            id: leftRow

            anchors.left: parent.left
            anchors.leftMargin: Theme.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            LauncherButton {
                screenName: root.modelData.name
            }

            ClipboardButton {
                screenName: root.modelData.name
            }

            Workspaces {
                screenName: root.modelData.name
            }

            WindowTitle {
                maxWidth: Math.floor(root.width * 0.33)
            }
        }

        // center: keyboard layout chip + date + time
        Row {
            anchors.centerIn: parent
            spacing: 4

            KeyboardLayout {}
            DateClock {}
            TimeClock {}
        }

        // right: status chips + power
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Backlight {}
            SystemStats {}
            Volume {}
            Battery {}

            PowerButton {
                screenName: root.modelData.name
            }
        }
    }
}
