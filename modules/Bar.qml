pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../style"

// M3 Expressive bar: three floating islands (surfaceContainer sides, raised
// clock hero) hosting the niri workspaces, window title, clock and status chips.
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

    WlrLayershell.namespace: "quickshell:bar"

    readonly property bool shown: !ShellState.barHidden

    // Mod+P (niri bind) through the `bar` IPC target hides the bar; unmapping also
    // releases the exclusive zone, so windows reclaim the space. The window stays
    // mapped while the fade-out plays.
    visible: root.shown || islands.opacity > 0.001

    Item {
        id: islands

        anchors.fill: parent
        opacity: root.shown ? 1 : 0

        transform: Translate {
            y: root.shown ? 0 : -Theme.barHeight

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        // left island: workspaces + focused window title
        Rectangle {
            id: leftIsland

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(leftRow.implicitWidth + 2 * Theme.barPadding, Math.floor(root.width * 0.3))
            height: Theme.barHeight
            radius: Theme.shapeFull
            color: Theme.surfaceContainer
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durLong
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }

            Row {
                id: leftRow

                anchors.left: parent.left
                anchors.leftMargin: Theme.barPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Workspaces {
                    screenName: root.modelData.name
                }

                WindowTitle {
                    maxWidth: Math.floor(root.width * 0.18)
                }
            }
        }

        // center island: clock hero, raised one tonal step over the sides
        Rectangle {
            id: centerIsland

            anchors.centerIn: parent
            width: centerRow.implicitWidth + 2 * Theme.barPadding
            height: Theme.barHeight
            radius: Theme.shapeFull
            color: Theme.surfaceContainerHigh

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durLong
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }

            Row {
                id: centerRow

                anchors.centerIn: parent
                spacing: 4

                KeyboardLayout {}
                DateClock {}
                TimeClock {
                    screenName: root.modelData.name
                }
            }
        }

        // right island: status cluster + notification + power FAB
        Rectangle {
            id: rightIsland

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: rightRow.implicitWidth + 2 * Theme.barPadding
            height: Theme.barHeight
            radius: Theme.shapeFull
            color: Theme.surfaceContainer

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durLong
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }

            Row {
                id: rightRow

                anchors.right: parent.right
                anchors.rightMargin: Theme.barPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Backlight {}
                SystemStats {
                    screenName: root.modelData.name
                }
                Volume {}
                Battery {}

                NotificationBell {
                    screenName: root.modelData.name
                }

                PowerButton {
                    screenName: root.modelData.name
                }
            }
        }
    }
}
