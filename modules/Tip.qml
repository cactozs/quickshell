pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// M3 plain tooltip: surface container, extra-small corner, no border; fades
// in with a small upward drift.
PopupWindow {
    id: root

    required property Item target
    property string text: ""

    // Open state, driven by the owner; the window stays mapped while the
    // fade-out plays.
    property bool shown: false

    visible: shown || surface.opacity > 0.001
    color: "transparent"

    // Opens away from the bar's docking edge: below a top bar, above a bottom
    // one, sideways off a rail. A tip flipped back over its chip by the
    // compositor would drop the hover that shows it.
    readonly property string edge: ShellState.barPosition
    anchor.item: target
    anchor.edges: root.edge === "bottom" ? Edges.Top | Edges.Left
        : root.edge === "left" ? Edges.Right | Edges.Top
        : root.edge === "right" ? Edges.Left | Edges.Top
        : Edges.Bottom | Edges.Left
    anchor.gravity: root.edge === "bottom" ? Edges.Top | Edges.Right
        : root.edge === "left" ? Edges.Right | Edges.Bottom
        : root.edge === "right" ? Edges.Left | Edges.Bottom
        : Edges.Bottom | Edges.Right

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 12

    // Ambient shadow under the tooltip (New style only); follows its fade.
    // No acrylic: blur is only available on panel windows, not popups.
    RectangularShadow {
        anchors.fill: surface
        radius: surface.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: Theme.glass
        opacity: surface.opacity
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.shapeXS
        // No acrylic: blur is only available on panel windows, not popups, so
        // the chip veil would leave it readable through. A solid tone instead.
        color: Theme.popupSurface
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        transform: Translate {
            id: drift

            y: root.shown ? 0 : 6

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }
            }
        }

        Text {
            id: label

            anchors.centerIn: parent
            text: root.text
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelMedium
            font.weight: Font.Medium
        }
    }

}
