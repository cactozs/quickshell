pragma ComponentBehavior: Bound

import QtQuick
import "../style"

// Compact circular icon control for dense surfaces (notification cards and
// history rows), where IconButton's bar-sized chip does not fit.
Item {
    id: root

    property string icon: ""
    property color contentColor: Theme.surfaceVariantText
    readonly property alias hovered: hover.hovered
    readonly property alias pressed: tap.pressed

    signal clicked

    implicitWidth: 28
    implicitHeight: 28

    Rectangle {
        id: circle

        anchors.centerIn: parent
        width: 26
        height: 26
        radius: width / 2
        color: "transparent"

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
            font.pixelSize: Theme.iconSizeSmall
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
