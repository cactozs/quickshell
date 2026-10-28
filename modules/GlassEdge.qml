pragma ComponentBehavior: Bound

import QtQuick
import "../style"

// The dressing of a card: under "new" the 1px inner rim and a 1px specular line
// along the top edge; under "old" a black outline and the raised/sunken bevel.
// Fills its parent (a Rectangle) and stays under the content, so nothing is
// drawn over the text or the chips inside. Every token is transparent or zero
// under m3, so it can be added unconditionally.
Item {
    id: root

    anchors.fill: parent

    // Inverts the bevel for pressed buttons and selected segments.
    property bool sunken: false

    // The parent card's corner, one pixel in — where the rim runs.
    readonly property real corner: parent ? Math.max(0, (parent.radius ?? 0) - 1) : 0

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.corner
        // A plate may round only its bottom corners (a narrow flush panel);
        // everywhere else the per-corner values fall back to `radius`.
        bottomLeftRadius: Math.max(0, (parent.bottomLeftRadius ?? 0) - 1)
        bottomRightRadius: Math.max(0, (parent.bottomRightRadius ?? 0) - 1)
        color: "transparent"
        border.width: Theme.hairlineWidth
        border.color: Theme.cardRim
        visible: !Theme.old
    }

    // The edge catching the light, fading out before the corners turn.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: root.corner
        anchors.rightMargin: root.corner
        height: 1
        visible: Theme.glass

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.glassSpecular }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Old's black outline, then the bevel one pixel inside it. White top/left
    // and gray bottom/right read as raised; swapped, as pressed.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Theme.hairline
        visible: Theme.old
    }

    Rectangle {
        visible: Theme.old
        x: 1
        y: 1
        width: Math.max(0, parent.width - 2)
        height: 1
        color: root.sunken ? Theme.bevelDark : Theme.bevelLight
    }

    Rectangle {
        visible: Theme.old
        x: 1
        y: 1
        width: 1
        height: Math.max(0, parent.height - 2)
        color: root.sunken ? Theme.bevelDark : Theme.bevelLight
    }

    Rectangle {
        visible: Theme.old
        x: 1
        y: Math.max(1, parent.height - 2)
        width: Math.max(0, parent.width - 2)
        height: 1
        color: root.sunken ? Theme.bevelLight : Theme.bevelDark
    }

    Rectangle {
        visible: Theme.old
        x: Math.max(1, parent.width - 2)
        y: 1
        width: 1
        height: Math.max(0, parent.height - 2)
        color: root.sunken ? Theme.bevelLight : Theme.bevelDark
    }
}
