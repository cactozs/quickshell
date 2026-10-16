pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
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

    anchor.item: target
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 12

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.shapeXS
        color: Theme.surfaceContainerHighest

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
