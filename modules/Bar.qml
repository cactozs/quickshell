pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// M3 Expressive bar. Three layouts (the "Стиль панели" setting): "islands" —
// three floating islands hosting the niri workspaces, window title, clock and
// status chips; "island" — the same clusters on one floating plate; "panel" —
// that plate flush to the screen walls. The clusters are the same Rectangles in
// every layout, only their background changes (see `barPlate`).
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    // Under "new" the surface grows downwards around the islands so the shadow
    // has room to render; the band mask keeps that extra area click-through.
    // Left and right there is no such room on purpose: the islands keep only
    // barMargin to the screen edge (like under "m3"), and what the shadow would
    // paint past the edge is clipped, exactly as it already is above them.
    // Under "m3" both numbers collapse to the old ones.
    readonly property int bandTop: root.flushPanel ? 0 : (Theme.glass ? Theme.barMargin : 0)
    readonly property int shadowInset: Theme.glass && !root.flushPanel
        ? Theme.cardShadowBlur + Theme.cardShadowOffset : 0

    // The plate is measured against the window, which already carries the
    // `margins` inset: 0 on both sides of a flush panel, barMargin otherwise.
    readonly property bool islandsMode: ShellState.panelStyle === "islands"
    readonly property bool flushPanel: ShellState.panelStyle === "panel"
    // A "fit" plate holds the centred clock with equal room on both sides (three
    // barPaddings of gap per side), so an off-centre side cannot push a cluster
    // under it. Capped at the window.
    readonly property int plateWidth: ShellState.panelWidth === "fit"
        ? Math.min(2 * Math.max(leftRow.implicitWidth, rightRow.implicitWidth)
            + centerRow.implicitWidth + 6 * Theme.barPadding, root.width)
        : root.width
    readonly property int plateX: Math.round((root.width - root.plateWidth) / 2)

    // The left island may use all the room up to the centered clock island.
    // A percentage cap cannot hold a growing workspace list: everything past
    // it is silently clipped, and niri creates workspaces on demand. The chips
    // compact themselves inside this width (and, at the physical limit, shift
    // to keep the active one visible); the island itself never crosses the
    // clock.
    readonly property int leftIslandMaxWidth: Math.max(0,
        Math.floor((root.width - centerIsland.width) / 2) - 2 * Theme.barPadding)
    readonly property int leftContentMaxWidth: Math.max(0,
        root.leftIslandMaxWidth - 2 * Theme.barPadding)

    margins {
        top: root.flushPanel ? 0 : (Theme.glass ? 0 : Theme.barMargin)
        left: root.flushPanel ? 0 : Theme.barMargin
        right: root.flushPanel ? 0 : Theme.barMargin
    }

    // Bar bottom sits at barMargin + barHeight; windows start one barMargin
    // below it. Quickshell adds `margins` to this value on top of it.
    exclusiveZone: Theme.barHeight + Theme.barMargin
    implicitHeight: root.bandTop + Theme.barHeight + root.shadowInset
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar"

    // Only the bar band takes input; the shadow strip below it stays click-through.
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

    // Acrylic behind the three islands (New and Blur). Off as soon as the
    // bar hides: a compositor blur region cannot fade, so it would hang.
    BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurRegion : null

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

    // Zero-sized while the islands are shown, so the union below is exactly the
    // three islands in that layout and exactly the plate in the other two.
    Item {
        id: plateAnchor
        x: barPlate.x
        y: barPlate.y
        width: root.islandsMode ? 0 : barPlate.width
        height: root.islandsMode ? 0 : barPlate.height
    }

    Region {
        id: blurRegion

        Region { item: leftAnchor; radius: leftIsland.radius }
        Region { item: centerAnchor; radius: centerIsland.radius }
        Region { item: rightAnchor; radius: rightIsland.radius }
        Region { item: plateAnchor; radius: barPlate.radius }
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

        // Single plate behind the clusters ("island" and "panel"). Hidden while
        // the three islands carry their own surfaces; the island rectangles then
        // turn into transparent content slots (see their color/radius below).
        RectangularShadow {
            anchors.fill: barPlate
            radius: barPlate.radius
            blur: Theme.cardShadowBlur
            offset.y: Theme.cardShadowOffset
            color: Theme.cardShadow
            // A flush panel has no room for a shadow: its top edge is clipped.
            visible: Theme.glass && !root.islandsMode && !root.flushPanel
        }

        Rectangle {
            id: barPlate

            visible: !root.islandsMode
            x: root.plateX
            y: root.bandTop
            width: root.plateWidth
            height: Theme.barHeight
            radius: root.flushPanel ? 0 : Theme.barRadius
            color: Theme.surfaceContainer
            border.width: Theme.hairlineWidth
            border.color: Theme.hairline

            GlassEdge {}
        }

        // left island: workspaces + focused window title
        RectangularShadow {
            anchors.fill: leftIsland
            radius: leftIsland.radius
            blur: Theme.cardShadowBlur
            offset.y: Theme.cardShadowOffset
            color: Theme.cardShadow
            visible: Theme.glass && root.islandsMode
        }

        Rectangle {
            id: leftIsland

            anchors.left: parent.left
            anchors.leftMargin: root.islandsMode ? 0 : root.plateX
            anchors.top: parent.top
            anchors.topMargin: root.bandTop
            width: Math.min(leftRow.implicitWidth + 2 * Theme.barPadding, root.leftIslandMaxWidth)
            height: Theme.barHeight
            radius: root.islandsMode ? Theme.barRadius : 0
            color: root.islandsMode ? Theme.surfaceContainer : "transparent"
            border.width: root.islandsMode ? Theme.hairlineWidth : 0
            border.color: Theme.hairline

            GlassEdge {
                visible: root.islandsMode
            }

            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Theme.dur(100)
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
                    id: workspacesItem

                    screenName: root.modelData.name
                    // The row gap is reserved twice: once here, and once by
                    // the title width below, so the two never overrun the
                    // island even when the title is hidden.
                    maxWidth: Math.max(0, root.leftContentMaxWidth - leftRow.spacing)
                }

                WindowTitle {
                    // The old 18% cap only shrinks the title; workspaces get
                    // the first claim on the room, and a sliver of title is
                    // not worth keeping (see WindowTitle's visible rule).
                    maxWidth: Math.max(0, Math.min(Math.floor(root.width * 0.18),
                        root.leftContentMaxWidth - workspacesItem.width - leftRow.spacing))
                }
            }
        }

        // center island: clock hero, same surface as the sides
        RectangularShadow {
            anchors.fill: centerIsland
            radius: centerIsland.radius
            blur: Theme.cardShadowBlur
            offset.y: Theme.cardShadowOffset
            color: Theme.cardShadow
            visible: Theme.glass && root.islandsMode
        }

        Rectangle {
            id: centerIsland

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.bandTop
            width: centerRow.implicitWidth + 2 * Theme.barPadding
            height: Theme.barHeight
            radius: root.islandsMode ? Theme.barRadius : 0
            color: root.islandsMode ? Theme.surfaceContainer : "transparent"
            border.width: root.islandsMode ? Theme.hairlineWidth : 0
            border.color: Theme.hairline

            GlassEdge {
                visible: root.islandsMode
            }

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
                DateClock {
                    screenName: root.modelData.name
                }
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
            visible: Theme.glass && root.islandsMode
        }

        Rectangle {
            id: rightIsland

            anchors.right: parent.right
            anchors.rightMargin: root.islandsMode ? 0 : root.plateX
            anchors.top: parent.top
            anchors.topMargin: root.bandTop
            width: rightRow.implicitWidth + 2 * Theme.barPadding
            height: Theme.barHeight
            radius: root.islandsMode ? Theme.barRadius : 0
            color: root.islandsMode ? Theme.surfaceContainer : "transparent"
            border.width: root.islandsMode ? Theme.hairlineWidth : 0
            border.color: Theme.hairline

            GlassEdge {
                visible: root.islandsMode
            }

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

                Tray {
                    screenName: root.modelData.name
                }

                NotificationBell {
                    screenName: root.modelData.name
                }

                PetButton {
                    screenName: root.modelData.name
                    visible: ShellState.petEnabled
                }

                PowerButton {
                    screenName: root.modelData.name
                }
            }
        }
    }
}
