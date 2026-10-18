pragma ComponentBehavior: Bound

import QtQuick
import "../style"

// The glass dressing of a card under the "new" pack: the 1px inner rim and a
// 1px specular line along the top edge. Fills its parent (a rounded Rectangle)
// and stays under the content, so nothing is drawn over the text or the chips
// inside. Every token is transparent under m3, so it can be added
// unconditionally.
Item {
    id: root

    anchors.fill: parent

    // The parent card's corner, one pixel in — where the rim runs.
    readonly property real corner: parent ? Math.max(0, (parent.radius ?? 0) - 1) : 0

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.corner
        color: "transparent"
        border.width: Theme.hairlineWidth
        border.color: Theme.cardRim
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
}
