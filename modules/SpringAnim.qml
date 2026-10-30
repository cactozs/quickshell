import QtQuick
import "../style"

// OutBack stand-in for the M3E spatial spring.
NumberAnimation {
    duration: Theme.durMedium
    easing.type: Easing.OutBack
    easing.overshoot: Theme.springOvershoot
}
