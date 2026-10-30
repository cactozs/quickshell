import QtQuick
import "../style"

// Emphasized (non-decelerate) twin of Anim.
NumberAnimation {
    duration: Theme.durShort
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curveEmphasized
}
