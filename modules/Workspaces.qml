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

            onActiveChanged: {
                if (active)
                    pop.restart();
            }

            Rectangle {
                id: chip

                anchors.centerIn: parent

                implicitWidth: label.implicitWidth + 24
                implicitHeight: Theme.chipHeight
                width: implicitWidth
                height: implicitHeight

                // Full pill at rest; squares off while pressed, springs back.
                radius: clickArea.pressed ? Theme.shapeSM : Theme.shapeFull
                color: cell.active ? Theme.secondaryContainer : "transparent"
                scale: popScale

                property real popScale: 1

                Behavior on radius {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.3
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
                        duration: 130
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasizedDecelerate
                    }

                    NumberAnimation {
                        target: chip
                        property: "popScale"
                        to: 1
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.3
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
