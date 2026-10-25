// Declare it after the scrim and before the card: it renders under the card.
// Root is an explicitly sized transparent item so the click-outside MouseArea
// covers the whole layer surface, not just the implicit 0x0 of an Item child.

import Quickshell
import QtQuick
import QtQuick.Effects
import "../style"

Rectangle {
    id: root

    color: "transparent"
    width: parent.width
    height: parent.height

    required property Item card
    // Launcher's fullscreen grid fills the output and stays shadowless.
    property bool shadow: Theme.glass

    signal dismiss()

    // Unscaled twin of the card: the region must not see the entrance scale.
    // Geometry is copied instead of anchored: `card` is a sibling of this
    // component, not of its children, and anchors cannot cross that boundary.
    Item {
        id: blurAnchor
        x: root.card.x
        y: root.card.y
        width: root.card.width
        height: root.card.height
    }

    Region {
        id: region

        Region { item: blurAnchor; radius: root.card.radius }
    }

    readonly property alias blurRegion: region

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
    }

    RectangularShadow {
        x: root.card.x
        y: root.card.y
        width: root.card.width
        height: root.card.height
        radius: root.card.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: root.shadow
        opacity: root.card.opacity
        scale: root.card.scale
    }
}
