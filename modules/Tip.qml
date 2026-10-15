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

    visible: false
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
        opacity: 0

        transform: Translate {
            id: drift
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

    ParallelAnimation {
        id: showAnim

        NumberAnimation {
            target: surface
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEmphasized
        }

        NumberAnimation {
            target: drift
            property: "y"
            from: 6
            to: 0
            duration: Theme.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEmphasizedDecelerate
        }
    }

    onVisibleChanged: {
        if (visible) {
            showAnim.restart();
        } else {
            surface.opacity = 0;
            drift.y = 6;
        }
    }
}
