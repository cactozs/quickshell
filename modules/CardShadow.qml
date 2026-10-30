import QtQuick
import QtQuick.Effects
import "../style"

// Standard popup shadow: follows the target's radius, opacity and scale.
RectangularShadow {
    id: root

    required property Rectangle target
    property bool shown: Theme.glass
    property bool followOpacity: true
    property bool followScale: true

    anchors.fill: root.target
    radius: root.target.radius
    blur: Theme.cardShadowBlur
    offset.y: Theme.cardShadowOffset
    color: Theme.cardShadow
    visible: root.shown
    opacity: root.followOpacity ? root.target.opacity : 1
    scale: root.followScale ? root.target.scale : 1
}
