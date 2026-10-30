pragma ComponentBehavior: Bound

import QtQuick
import "../style"

// M3 Expressive slider: thick track with a narrow pill handle;
// `moved` fires while dragging, `committed` on release.
Item {
    id: slider

    property real value: 0
    property color handleColor: Theme.sliderColor

    signal moved(real position)
    signal committed(real position)

    implicitHeight: 40

    // Thumb center inset: the handle travels over the track minus its half.
    readonly property real inset: 8
    readonly property real thumbWidth: dragArea.pressed ? 2 : 4

    function valueAt(x: real): real {
        return Math.max(0, Math.min(1, (x - slider.inset) / Math.max(1, slider.width - 2 * slider.inset)));
    }

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        x: slider.inset
        width: Math.max(0, parent.width - 2 * slider.inset)
        // Nothing keeps the M3 track as a precise line, not a capsule.
        height: Theme.nothing ? 4 : 16
        radius: Theme.nothing ? 2 : Theme.shapeFull
        color: Theme.surfaceContainerHighest

        Rectangle {
            width: slider.value * parent.width
            height: parent.height
            radius: parent.radius
            topRightRadius: 0
            bottomRightRadius: 0
            color: slider.handleColor
        }

        Rectangle {
            id: thumb

            width: slider.thumbWidth
            height: Theme.nothing ? 16 : 32
            radius: Theme.shapeFull
            x: slider.value * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: slider.handleColor

            Behavior on width { AnimEmph {} }

        }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        onPressed: mouse => slider.moved(slider.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (dragArea.pressed)
                slider.moved(slider.valueAt(mouse.x));
        }
        onReleased: mouse => slider.committed(slider.valueAt(mouse.x))
    }
}
