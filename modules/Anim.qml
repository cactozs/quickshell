import QtQuick
import "../style"

// Default expressive decelerate tween for `Behavior on` blocks.
NumberAnimation {
    duration: Theme.durShort
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curveEmphasizedDecelerate
}
