pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../style"

// M3 chip-shaped icon control: tonal container, state layer and the
// expressive press morph (corners spring between md and sm; a round
// control visibly squares off while pressed).
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool round: false
    property color containerColor: Theme.surfaceContainerHigh
    property color contentColor: Theme.surfaceText
    property color iconColor: root.contentColor
    property color labelColor: root.contentColor
    property int hPadding: 10

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: clickArea.pressed

    signal clicked(int button)
    signal wheeled(int delta)

    implicitWidth: root.round ? chip.implicitHeight : chip.implicitWidth
    implicitHeight: Theme.barHeight

    scale: clickArea.pressed ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Easing.OutBack
            easing.overshoot: 1.4
        }
    }

    Rectangle {
        id: chip

        anchors.centerIn: parent

        implicitWidth: content.implicitWidth + 2 * root.hPadding
        implicitHeight: root.round ? Theme.iconButtonSize : Theme.chipHeight
        width: implicitWidth
        height: implicitHeight

        radius: clickArea.pressed
            ? (root.round ? Theme.shapeLG : Theme.shapeSM)
            : (root.round ? height / 2 : Theme.shapeMD)
        color: root.containerColor

        Behavior on radius {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durMedium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        StateLayer {
            hovered: hover.hovered
            pressed: clickArea.pressed
            color: root.contentColor
        }

        RowLayout {
            id: content

            anchors.centerIn: parent
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: text !== ""
                text: root.icon
                color: root.iconColor
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasized
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: text !== ""
                text: root.label
                color: root.labelColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelLarge
                font.weight: Font.Medium

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasized
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: clickArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => root.clicked(mouse.button)
    }

    WheelHandler {
        acceptedModifiers: Qt.NoModifier

        onWheel: event => root.wheeled(event.angleDelta.y)
    }
}
