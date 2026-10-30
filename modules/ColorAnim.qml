import QtQuick
import "../style"

// Default color tween for `Behavior on color`.
ColorAnimation {
    duration: Theme.durShort
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curveEmphasized
}
