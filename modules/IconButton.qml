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
    // Icon glyph family; override for glyphs outside Material Symbols.
    property string iconFamily: Theme.iconFont
    property string label: ""
    property bool round: false
    // Glyph only, for the vertical rail where a chip has no room for its text.
    property bool compact: false
    // Text only, for the rail: a value like "US" or "65%" is what the chip is for.
    property bool labelOnly: false
    property color containerColor: Theme.surfaceContainerHigh
    property color contentColor: Theme.surfaceText
    property color iconColor: root.contentColor
    property color labelColor: root.contentColor
    property int hPadding: 12

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: clickArea.pressed

    signal clicked(int button)
    signal wheeled(int delta)

    implicitWidth: root.round ? chip.implicitHeight : chip.implicitWidth
    implicitHeight: Theme.barHeight

    scale: clickArea.pressed ? 0.97 : 1

    Behavior on scale { SpringAnim { duration: Theme.durShort } }

    Rectangle {
        id: chip

        anchors.centerIn: parent

        implicitWidth: content.implicitWidth + 2 * root.hPadding
        implicitHeight: root.round ? Theme.iconButtonSize : Theme.chipHeight
        // Round buttons are square by construction; hPadding only widens chips.
        width: root.round ? implicitHeight : implicitWidth
        height: implicitHeight

        // M3E shape morph: full pill at rest; the press pulls the corners
        // inward (round button -> extra-large-increased, chip -> medium).
        // Under "new" a chip rests at chipRadius instead of a pill.
        radius: clickArea.pressed
            ? (root.round ? Theme.shapeLGI : Theme.chipRadiusPressed)
            : (root.round ? Theme.shapeFull : Theme.chipRadius)
        color: root.containerColor

        Behavior on radius { SpringAnim { duration: Theme.durMorph } }

        Behavior on color { ColorAnim { duration: Theme.durMedium } }

        StateLayer {
            hovered: hover.hovered
            pressed: clickArea.pressed
            color: root.contentColor
        }

        GlassEdge {
            visible: Theme.old
            sunken: clickArea.pressed
        }

        RowLayout {
            id: content

            anchors.centerIn: parent
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: text !== "" && !root.labelOnly
                text: root.icon
                color: root.iconColor
                font.family: root.iconFamily
                font.pixelSize: Theme.iconSize

                Behavior on color { ColorAnim {} }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: text !== "" && !root.compact
                text: root.label
                color: root.labelColor
                font.family: Theme.fontFamily
                // The rail's value chips sit in a 46–48 px plate; one step
                // down keeps "100%" inside it.
                font.pixelSize: root.labelOnly ? Theme.fontSizeLabelMedium : Theme.fontSizeLabelLarge
                font.weight: Font.Medium

                Behavior on color { ColorAnim {} }
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
        cursorShape: Qt.PointingHandCursor

        // Pending touchpad scroll, accumulated into discrete steps.
        property real wheelAccum: 0

        onClicked: mouse => root.clicked(mouse.button)

        // Wheel handling lives in the MouseArea rather than a sibling
        // WheelHandler so the two cannot race for the same events.
        // Mouse wheels arrive as discrete notches (±120 angleDelta) and make
        // one step each; touchpads arrive as pixelDelta streams and are
        // accumulated into a step per ~60 px of scrolling.
        onWheel: wheel => {
            if (wheel.angleDelta.y !== 0) {
                wheelAccum = 0;
                root.wheeled(wheel.angleDelta.y > 0 ? 1 : -1);
            } else if (wheel.pixelDelta.y !== 0) {
                wheelAccum += wheel.pixelDelta.y;
                if (Math.abs(wheelAccum) >= 60) {
                    root.wheeled(wheelAccum > 0 ? 1 : -1);
                    wheelAccum = 0;
                }
            }
        }
    }
}
