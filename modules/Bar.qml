pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// M3 Expressive bar: three floating islands (surfaceContainer sides, raised
// clock hero) hosting the niri workspaces, window title, clock and status chips.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    // Under "new" the surface grows around the islands so the warm glow has
    // room to render; the band mask keeps that extra area click-through. Under
    // "m3" these collapse to the old numbers and the surface is just the bar.
    readonly property int bandTop: Theme.glass ? Theme.barMargin : 0
    readonly property int glowInset: Theme.glass ? Theme.cardShadowBlur + Theme.cardShadowOffset : 0

    margins {
        top: Theme.glass ? 0 : Theme.barMargin
        left: Theme.barMargin
        right: Theme.barMargin
    }

    // Bar bottom sits at barMargin + barHeight; windows start one barMargin
    // below it. Quickshell adds `margins` to this value on top of it.
    exclusiveZone: Theme.barHeight + Theme.barMargin
    implicitHeight: root.bandTop + Theme.barHeight + root.glowInset
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar"

    // Only the bar band takes input; the glow strip below it stays click-through.
    mask: Region {
        x: 0
        y: root.bandTop
        width: root.width
        height: Theme.barHeight
    }

    // Any image dropped on the bar band becomes the wallpaper. Declared under
    // the islands so it never affects their click handling.
    WallpaperDropArea {
        x: 0
        y: root.bandTop
        width: root.width
        height: Theme.barHeight
    }

    // Acrylic behind the three islands (New style only).
    BackgroundEffect.blurRegion: Theme.glass ? blurRegion : null

    // Unscaled twins of the islands for the blur region: it only rebuilds on
    // x/y/w/h changes, so it must not see the islands' entrance translate.
    Item {
        id: leftAnchor
        x: leftIsland.x
        y: leftIsland.y
        width: leftIsland.width
        height: leftIsland.height
    }

    Item {
        id: centerAnchor
        x: centerIsland.x
        y: centerIsland.y
        width: centerIsland.width
        height: centerIsland.height
    }

    Item {
        id: rightAnchor
        x: rightIsland.x
        y: rightIsland.y
        width: rightIsland.width
        height: rightIsland.height
    }

    Region {
        id: blurRegion

        Region { item: leftAnchor; radius: leftIsland.radius }
        Region { item: centerAnchor; radius: centerIsland.radius }
        Region { item: rightAnchor; radius: rightIsland.radius }
    }

    readonly property bool shown: !ShellState.barHidden

    // Mod+P (niri bind) through the `bar` IPC target hides the bar; unmapping also
    // releases the exclusive zone, so windows reclaim the space. The window stays
    // mapped while the fade-out plays.
    visible: root.shown || islands.opacity > 0.001

    Item {
        id: islands

        anchors.fill: parent
        opacity: root.shown ? 1 : 0

        transform: Translate {
            y: root.shown ? 0 : -Theme.barHeight

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        // left island: workspaces + focused window title
        RectangularShadow {
            anchors.fill: leftIsland
            radius: leftIsland.radius
            blur: Theme.cardShadowBlur
            offset.y: Theme.cardShadowOffset
            color: Theme.cardShadow
            visible: Theme.glass
        }

        Rectangle {
            id: leftIsland

            anchors.left: parent.left
            anchors.leftMargin: root.glowInset
            anchors.top: parent.top
            anchors.topMargin: root.bandTop
            width: Math.min(leftRow.implicitWidth + 2 * Theme.barPadding, Math.floor(root.width * 0.3))
            height: Theme.barHeight
            radius: Theme.barRadius
            color: Theme.surfaceContainer
            border.width: Theme.hairlineWidth
            border.color: Theme.hairline
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durLong
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }

            Row {
                id: leftRow

                anchors.left: parent.left
                anchors.leftMargin: Theme.barPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Workspaces {
                    screenName: root.modelData.name
                }

                WindowTitle {
                    maxWidth: Math.floor(root.width * 0.18)
                }
            }
        }

        // center island: clock hero, raised one tonal step over the sides
        RectangularShadow {
            anchors.fill: centerIsland
            radius: centerIsland.radius
            blur: Theme.cardShadowBlur
            offset.y: Theme.cardShadowOffset
            color: Theme.cardShadow
            visible: Theme.glass
        }

        Rectangle {
            id: centerIsland

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.bandTop
            width: centerRow.implicitWidth + 2 * Theme.barPadding
            height: Theme.barHeight
            radius: Theme.barRadius
            color: Theme.surfaceContainerHigh
            border.width: Theme.hairlineWidth
            border.color: Theme.hairline

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durLong
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }

            Row {
                id: centerRow

                anchors.centerIn: parent
                spacing: 4

                KeyboardLayout {}
                DateClock {}
                TimeClock {
                    screenName: root.modelData.name
                }
            }
        }

        // right island: status cluster + notification + power FAB
        RectangularShadow {
            anchors.fill: rightIsland
            radius: rightIsland.radius
            blur: Theme.cardShadowBlur
            offset.y: Theme.cardShadowOffset
            color: Theme.cardShadow
            visible: Theme.glass
        }

        Rectangle {
            id: rightIsland

            anchors.right: parent.right
            anchors.rightMargin: root.glowInset
            anchors.top: parent.top
            anchors.topMargin: root.bandTop
            width: rightRow.implicitWidth + 2 * Theme.barPadding
            height: Theme.barHeight
            radius: Theme.barRadius
            color: Theme.surfaceContainer
            border.width: Theme.hairlineWidth
            border.color: Theme.hairline

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durLong
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }

            Row {
                id: rightRow

                anchors.right: parent.right
                anchors.rightMargin: Theme.barPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Backlight {}
                SystemStats {
                    screenName: root.modelData.name
                }
                Volume {}
                Battery {}

                NotificationBell {
                    screenName: root.modelData.name
                }

                PowerButton {
                    screenName: root.modelData.name
                }
            }
        }
    }
}
