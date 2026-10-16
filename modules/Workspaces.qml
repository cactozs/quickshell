pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// niri workspaces as M3 navigation-bar: one sliding secondaryContainer pill
// stretches behind the active chip, neighbours part around it.
// Click focuses, wheel steps through workspaces.
Item {
    id: root

    required property string screenName

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: implicitHeight

    readonly property var wsList: root.screenName !== "" ? Niri.workspacesFor(root.screenName) : []
    readonly property int activeIndex: {
        for (let i = 0; i < root.wsList.length; i++)
            if (root.wsList[i].is_active === true) return i;
        return -1;
    }
    // Live delegate behind the highlight. Row.children tracks rebuilds, so
    // the pill animates from the old x to the new one instead of jumping.
    // var (not Item): delegates carry a custom `pressed` property.
    readonly property var activeCell: (root.activeIndex >= 0 && row.children.length > root.activeIndex)
        ? row.children[root.activeIndex] : null
    readonly property bool activePressed: root.activeCell !== null && root.activeCell.pressed === true

    onActiveIndexChanged: {
        if (root.activeIndex >= 0 && root.wsList[root.activeIndex])
            Niri.consumeWorkspacePop(root.wsList[root.activeIndex].id);
    }

    // Shared sliding pill: x glides, width overshoots = the rubber stretch.
    Rectangle {
        id: slide

        y: (parent.height - Theme.chipHeight) / 2
        height: Theme.chipHeight
        x: root.activeCell !== null ? root.activeCell.x : 0
        width: root.activeCell !== null ? root.activeCell.width : 0
        visible: root.activeCell !== null

        radius: root.activePressed ? Theme.shapeMD : Theme.shapeFull
        color: Theme.secondaryContainer

        Behavior on x {
            NumberAnimation {
                duration: 100
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durMorph
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }
    }

    Row {
        id: row

        x: 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.wsList

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property bool active: modelData.is_active === true
                readonly property bool pressed: clickArea.pressed

                implicitWidth: Math.max(label.implicitWidth + 24, active ? 48 : 28)
                implicitHeight: Theme.barHeight
                width: implicitWidth
                height: implicitHeight

                // First-mount entrance only: the Repeater rebuilds every chip
                // on each workspace update, Niri remembers seen ids.
                Component.onCompleted: {
                    if (Niri.markWorkspaceSeen(cell.modelData.id))
                        appear.start();
                }

                NumberAnimation {
                    id: appear
                    target: cell
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }

                Rectangle {
                    id: box

                    anchors.centerIn: parent
                    width: parent.width
                    height: Theme.chipHeight
                    radius: Theme.shapeFull
                    color: "transparent"

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
