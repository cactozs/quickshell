pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../services"
import "../style"

// OSD for volume/brightness changes: a pill near the bottom center with the
// status icon, a level bar and the percent. Click- and keyboard-transparent
// and mapped only while shown, like LayoutBadge.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property int bottomMargin: 96
    // M3E hero surface: taller tile, extra-extra-large corners.
    readonly property int pillHeight: 64

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    visible: Osd.shown || pill.opacity > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Empty input region: every click passes through to the window below.
    mask: Region {}

    // Acrylic behind the pill (New and Blur). Off as soon as it closes: a
    // compositor blur region cannot fade, so it would hang under the pill.
    BackgroundEffect.blurRegion: Theme.blur && Osd.shown ? blurRegion : null

    // Unscaled twin of the pill for the blur region: it only rebuilds on
    // x/y/w/h changes, so it must not see the entrance scale.
    Item {
        id: blurAnchor
        anchors.fill: pill
    }

    Region {
        id: blurRegion

        Region { item: blurAnchor; radius: pill.radius }
    }

    // The region only lands on the commit after the frame that set it; kick
    // repaints while the pill resizes so the blur can't trail behind it.
    BlurKick {
        id: blurKick

        region: blurRegion
    }

    BlurTarget { item: pill; kicker: blurKick }

    // Ambient shadow under the pill (New style only); follows the pill's
    // entrance fade/scale.
    CardShadow { target: pill }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomMargin

        implicitWidth: row.implicitWidth + 40
        implicitHeight: root.pillHeight
        width: implicitWidth
        height: implicitHeight

        radius: Theme.shapeXXL
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        opacity: Osd.shown ? 1 : 0
        scale: Osd.shown ? 1 : 0.85

        Behavior on opacity { Anim {} }

        // Expressive pop-in; on hide the same spring reads as a light shrink.
        Behavior on scale { SpringAnim {} }

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 14

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: Osd.icon
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSizeLarge

                Behavior on color { ColorAnim {} }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 160
                // Nothing keeps the meter as a precise line instead of the capsule.
                Layout.preferredHeight: Theme.nothing ? 4 : 12

                radius: Theme.nothing ? 2 : Theme.shapeFull
                color: Theme.surfaceContainerHighest

                Rectangle {
                    width: parent.width * Osd.value
                    height: parent.height
                    radius: parent.radius
                    color: Theme.sliderColor

                    Behavior on width { AnimEmph {} }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 44
                text: Math.round(Osd.value * 100) + "%"
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitleMedium
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight

                Behavior on color { ColorAnim {} }
            }
        }
    }
}
