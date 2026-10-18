pragma ComponentBehavior: Bound

import QtQuick

import "../style"

// Calculator row: shown above the app results while the query parses as
// arithmetic. Launcher keeps it at index -1, so it is selected as soon as it
// appears and Enter dismisses the launcher instead of launching an app.
Rectangle {
    id: calcItem

    required property string result
    required property string expression
    property bool selected: false

    signal activated
    signal hovered

    color: calcItem.selected ? Theme.secondaryContainer : "transparent"
    radius: Theme.shapeLG

    Behavior on color {
        ColorAnimation {
            duration: Theme.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEmphasized
        }
    }

    StateLayer {
        hovered: hoverHandler.hovered && !calcItem.selected
        pressed: tap.pressed
        color: calcItem.selected ? Theme.secondaryContainerText : Theme.surfaceText
    }

    Rectangle {
        id: plate

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: Theme.shapeFull
        color: calcItem.selected ? Theme.secondaryContainerText : Theme.primaryContainer

        Text {
            anchors.centerIn: parent
            text: Theme.iconCalculate
            color: calcItem.selected ? Theme.secondaryContainer : Theme.primary
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSizeMedium
        }
    }

    Column {
        anchors.left: plate.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: calcItem.result
            color: calcItem.selected ? Theme.secondaryContainerText : Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: calcItem.expression
            color: calcItem.selected ? Theme.secondaryContainerText : Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelMedium
            elide: Text.ElideRight
        }
    }

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
            if (hoverHandler.hovered)
                calcItem.hovered();
        }
    }

    MouseArea {
        id: tap

        anchors.fill: parent
        onClicked: calcItem.activated()
    }
}
