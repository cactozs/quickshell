pragma ComponentBehavior: Bound

import QtQuick
import "../style"

// M3 state layer: transient overlay carrying hover (8%) and press (10%)
// feedback on top of the parent's container color. Follows the parent's
// corner radius, including while it morphs.
Rectangle {
    id: root

    property bool hovered: false
    property bool pressed: false

    anchors.fill: parent
    radius: parent ? (parent.radius ?? 0) : 0

    // Default; call sites override with the container's content color.
    color: Theme.surfaceText
    opacity: root.pressed ? Theme.statePressed : (root.hovered ? Theme.stateHover : 0)
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEmphasized
        }
    }
}
