pragma ComponentBehavior: Bound

import QtQuick
import "../style"

// Compact icon control for dense surfaces (notification cards and history
// rows) where IconButton's bar-sized chip does not fit. M3E shape morph:
// round at rest, squarer while pressed.
Item {
    id: root

    property string icon: ""
    property color contentColor: Theme.surfaceVariantText
    readonly property alias hovered: hover.hovered
    readonly property alias pressed: tap.pressed

    signal clicked

    implicitWidth: 32
    implicitHeight: 32

    Rectangle {
        id: circle

        anchors.centerIn: parent
        width: 32
        height: 32
        radius: tap.pressed ? Theme.chipRadiusPressed : Theme.chipRadius
        color: "transparent"
        scale: tap.pressed ? 0.94 : 1

        Behavior on radius { SpringAnim { duration: Theme.durMorph } }

        Behavior on scale { SpringAnim { duration: Theme.durShort } }

        StateLayer {
            hovered: hover.hovered
            pressed: tap.pressed
            color: root.contentColor
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.contentColor
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: tap

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
