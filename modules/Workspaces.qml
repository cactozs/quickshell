pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// niri workspaces as M3 navigation-bar indicators: the active workspace is a
// secondaryContainer pill, the rest are plain labels with a state layer.
// Click focuses, wheel steps through workspaces.
Row {
    id: root

    required property string screenName

    spacing: 2

    Repeater {
        model: root.screenName !== "" ? Niri.workspacesFor(root.screenName) : []

        delegate: Item {
            id: cell

            required property var modelData

            readonly property bool active: modelData.is_active === true

            implicitWidth: chip.implicitWidth
            implicitHeight: Theme.barHeight
            opacity: 1

            onActiveChanged: {
                if (active && Niri.consumeWorkspacePop(cell.modelData.id))
                    pop.restart();
            }

            // First mount: fade + spring in. The Repeater rebuilds every chip
            // whenever the workspace list is reassigned, so Niri remembers
            // which ids have already appeared, and which activation still
            // owes a pop (onActiveChanged never fires on a fresh delegate).
            Component.onCompleted: {
                const popping = active && Niri.consumeWorkspacePop(cell.modelData.id);
                if (Niri.markWorkspaceSeen(cell.modelData.id))
                    appear.start();
                else if (popping)
                    pop.restart();
            }

            Rectangle {
                id: chip

                anchors.centerIn: parent

                // M3 nav indicator: active pill never narrower than 48.
                implicitWidth: Math.max(label.implicitWidth + 24, cell.active ? 48 : 28)
                implicitHeight: Theme.chipHeight
                width: implicitWidth
                height: implicitHeight

                // Full pill at rest; squares off while pressed, springs back.
                radius: clickArea.pressed ? Theme.shapeMD : Theme.shapeFull
                color: cell.active ? Theme.secondaryContainer : "transparent"
                scale: popScale

                property real popScale: 1

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durMorph
                        easing.type: Easing.OutBack
                        easing.overshoot: Theme.springOvershoot
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasized
                    }
                }

                SequentialAnimation {
                    id: pop

                    NumberAnimation {
                        target: chip
                        property: "popScale"
                        to: 1.12
                        duration: Theme.durPop
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasizedDecelerate
                    }

                    NumberAnimation {
                        target: chip
                        property: "popScale"
                        to: 1
                        duration: Theme.durSettle
                        easing.type: Easing.OutBack
                        easing.overshoot: Theme.springOvershoot
                    }
                }

                // First-mount entrance: fade under a springy scale-up.
                ParallelAnimation {
                    id: appear

                    NumberAnimation {
                        target: cell
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasizedDecelerate
                    }

                    NumberAnimation {
                        target: chip
                        property: "popScale"
                        from: 0.6
                        to: 1
                        duration: Theme.durMedium
                        easing.type: Easing.OutBack
                        easing.overshoot: Theme.springOvershoot
                    }
                }

                StateLayer {
                    hovered: hover.hovered
                    pressed: clickArea.pressed
                    color: cell.active ? Theme.secondaryContainerText : Theme.surfaceText
                }

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: String(cell.modelData.name ?? cell.modelData.idx)
                    color: cell.active ? Theme.secondaryContainerText : Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    font.weight: Font.Medium

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveEmphasized
                        }
                    }
                }
            }

            HoverHandler {
                id: hover
            }

            MouseArea {
                id: clickArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: Niri.focusWorkspace(cell.modelData.idx)
            }
        }
    }

    WheelHandler {
        acceptedModifiers: Qt.NoModifier

        onWheel: event => {
            if (event.angleDelta.y > 0)
                Niri.focusWorkspaceUp();
            else if (event.angleDelta.y < 0)
                Niri.focusWorkspaceDown();
        }
    }
}
