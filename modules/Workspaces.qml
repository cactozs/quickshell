pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// niri workspaces as M3 navigation-bar: one sliding secondaryContainer pill
// stretches behind the active chip, neighbours part around it.
// Click focuses, wheel steps through workspaces.
//
// niri creates workspaces on demand, so the chip row has to survive any
// count. The bar gives it `maxWidth` (the room left of the clock island,
// island padding excluded). A uniform ceiling keeps the whole row inside it:
// every chip is at most `fitCap` wide, so the sum can never overrun. Normal
// counts stay at the old metrics; dense rows trade padding and label room
// down to a readable floor, and only past that floor does the row shift to
// keep the active chip whole.
Item {
    id: root

    required property string screenName
    // Room for the chips alone; the bar reserves the island and row paddings.
    required property real maxWidth

    readonly property int spacing: 2

    implicitWidth: Math.min(root.contentWidth, root.maxWidth)
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: implicitHeight
    // Clip only a dense row's overflow. Clipping at the content width would
    // cut the pill while it slides out of a chip that niri just closed.
    clip: root.contentWidth > root.maxWidth

    readonly property var wsList: root.screenName !== "" ? Niri.workspacesFor(root.screenName) : []
    readonly property int activeIndex: {
        for (let i = 0; i < root.wsList.length; i++)
            if (root.wsList[i].is_active === true) return i;
        return -1;
    }

    // Per-chip ceiling that makes the whole row fit by construction. The 20px
    // floor is a readability limit, not a geometry one: below it the row is
    // allowed to overflow, and `offset` keeps the active chip in view.
    readonly property real fitCap: {
        if (root.wsList.length === 0) return 1e9;
        const gaps = root.spacing * (root.wsList.length - 1);
        return Math.max(20, Math.floor((root.maxWidth - gaps) / root.wsList.length));
    }

    // Padding shrinks with the ceiling: 12px is the old look, and at the 20px
    // floor the 1px side padding still leaves room for a two-digit label. A
    // fixed font-size reference keeps the text from being squeezed to zero.
    readonly property real chipHPad: Math.max(1, Math.min(12,
        Math.floor((root.fitCap - (Theme.fontSizeLabelLarge + 4)) / 2)))

    readonly property real contentWidth: row.implicitWidth

    // Last resort for more chips than the bar can physically show: slide the
    // row until the active chip is fully inside the viewport. Keeping it
    // visible beats the old behaviour, where the active workspace could be
    // the one cut off.
    readonly property real offset: {
        const cell = root.activeCell;
        if (root.contentWidth <= root.width || cell === null)
            return 0;
        return Math.max(-cell.x, Math.min(0, root.width - cell.x - cell.width));
    }

    // Live delegate behind the highlight; itemAt, not Row.children: the
    // Repeater is itself a child item and does not have the delegates' order.
    // var (not Item): delegates carry a custom `pressed` property.
    readonly property var activeCell: root.activeIndex >= 0 && root.activeIndex < repeater.count
        ? repeater.itemAt(root.activeIndex) : null
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
        x: root.offset + (root.activeCell !== null ? root.activeCell.x : 0)
        width: root.activeCell !== null ? root.activeCell.width : 0
        visible: root.activeCell !== null

        radius: root.activePressed ? Theme.chipRadiusPressed : Theme.chipRadius
        color: Theme.secondaryContainer

        Behavior on x {
            NumberAnimation {
                duration: Theme.dur(100)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.dur(100)
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

        x: root.offset
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Behavior on x {
            NumberAnimation {
                duration: Theme.dur(100)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        Repeater {
            id: repeater

            model: root.wsList

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property bool active: modelData.is_active === true
                readonly property bool pressed: clickArea.pressed
                readonly property string labelText: String(cell.modelData.name ?? cell.modelData.idx)

                // Natural width from the label, capped so the row can fit.
                // TextMetrics only measures this one string, so no shared
                // measurement state and no feedback into the chip width.
                readonly property real naturalWidth: Math.max(
                    Math.ceil(measurer.advanceWidth + 2 * root.chipHPad) + 1,
                    cell.active ? 48 : 28)
                readonly property bool capped: cell.naturalWidth > root.fitCap
                readonly property real labelPad: cell.capped ? Math.min(root.chipHPad, 2) : root.chipHPad

                implicitWidth: Math.min(cell.naturalWidth, root.fitCap)
                implicitHeight: Theme.barHeight
                width: implicitWidth
                height: implicitHeight

                TextMetrics {
                    id: measurer

                    text: cell.labelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    font.weight: Font.Medium
                }

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
                    radius: Theme.chipRadius
                    color: "transparent"

                    StateLayer {
                        hovered: hover.hovered
                        pressed: clickArea.pressed
                        color: cell.active ? Theme.secondaryContainerText : Theme.surfaceText
                    }

                    Text {
                        id: label

                        anchors.centerIn: parent
                        width: Math.max(0, cell.width - 2 * cell.labelPad)
                        horizontalAlignment: Text.AlignHCenter
                        // Measured against the same font above; only labels
                        // wider than the chosen ceiling end with an ellipsis.
                        elide: Text.ElideRight
                        text: cell.labelText
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

                    onClicked: Niri.focusWorkspace(cell.modelData.idx, root.screenName)
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
