pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// M3 Expressive bar, docked to any screen edge ("Расположение панели"):
// "top"/"bottom" keep the horizontal strip, "left"/"right" turn it into a
// vertical rail. Three layouts (the "Стиль панели" setting): "islands" —
// three floating islands hosting the niri workspaces, window title, clock and
// status chips; "island" — the same clusters on one floating plate; "panel" —
// that plate flush to the screen walls. The clusters are the same Rectangles
// in every layout and position, only their background and axis change (see
// `barPlate`).
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    readonly property string edge: ShellState.barPosition
    readonly property bool vertical: root.edge === "left" || root.edge === "right"
    // "bottom"/"right" dock to the far edge; the band and the shadow room
    // swap to the near side.
    readonly property bool flipped: root.edge === "bottom" || root.edge === "right"
    // The bar's extent across its axis: height when horizontal, width when
    // vertical.
    readonly property int thickness: root.vertical ? Theme.barThickness : Theme.barHeight
    // Rail chips stretch to the content width, so the Grid's single column is
    // centered on the plate instead of hugging its left edge.
    readonly property int railContentWidth: Theme.barThickness - 2 * Theme.barPadding

    anchors {
        top: root.vertical || !root.flipped
        bottom: root.vertical || root.flipped
        left: !root.vertical || !root.flipped
        right: !root.vertical || root.flipped
    }

    readonly property bool islandsMode: ShellState.panelStyle === "islands"
    readonly property bool flushPanel: ShellState.panelStyle === "panel"

    // Under "new" the surface grows inwards around the islands so the shadow
    // has room to render; the band mask keeps that extra area click-through.
    // The side margins keep barMargin to the screen edge; only the docked edge
    // drops it when the plate already carries the gap (glass).
    readonly property int band: root.flushPanel ? 0 : (Theme.glass ? Theme.barMargin : 0)
    readonly property int shadowInset: Theme.glass && !root.flushPanel
        ? Theme.cardShadowBlur + Theme.cardShadowOffset : 0
    readonly property int edgeMargin: root.flushPanel ? 0 : (Theme.glass ? 0 : Theme.barMargin)
    readonly property int crossMargin: root.flushPanel ? 0 : Theme.barMargin
    // Window origin of the plate along the cross axis: the band and the shadow
    // room sit on the inner side, which swaps with the edge.
    readonly property int plateOffset: root.flipped ? root.shadowInset : root.band
    readonly property int shadowSign: root.flipped ? -1 : 1

    // The length of the single plate along the bar axis; "fit" hugs the
    // content. The islands are three fixed plates and ignore it. A side rail
    // measures the same clusters along its height.
    readonly property int clusterLeft: root.vertical
        ? leftRow.implicitHeight : leftRow.implicitWidth
    readonly property int clusterCenter: root.vertical
        ? centerRow.implicitHeight : centerRow.implicitWidth
    readonly property int clusterRight: root.vertical
        ? rightRow.implicitHeight : rightRow.implicitWidth

    // The left island may use all the room up to the centered clock island.
    // A percentage cap cannot hold a growing workspace list: everything past
    // it is silently clipped, and niri creates workspaces on demand. The chips
    // compact themselves inside this width (and, at the physical limit, shift
    // to keep the active one visible); the island itself never crosses the
    // clock. The rail caps the same room along its height.
    readonly property int leftIslandMaxWidth: Math.max(0,
        Math.floor((root.width - centerIsland.width) / 2) - 2 * Theme.barPadding)
    readonly property int leftContentMaxWidth: Math.max(0,
        root.leftIslandMaxWidth - 2 * Theme.barPadding)
    readonly property int topIslandMaxHeight: Math.max(0,
        Math.floor((root.height - centerIsland.height) / 2) - 2 * Theme.barPadding)
    readonly property int topContentMaxHeight: Math.max(0,
        root.topIslandMaxHeight - 2 * Theme.barPadding)

    readonly property int span: root.vertical ? root.height : root.width
    readonly property int plateLength: ShellState.panelWidth === "fit"
        ? Math.min(2 * Math.max(root.clusterLeft, root.clusterRight)
            + root.clusterCenter + 6 * Theme.barPadding, root.span)
        : root.span
    readonly property int platePos: Math.round((root.span - root.plateLength) / 2)
    // In islands mode the three plates spread over the window; otherwise the
    // outer two sit at the ends of the single plate.
    readonly property int plateStart: root.islandsMode ? 0 : root.platePos
    readonly property int plateEnd: root.islandsMode ? root.span : root.platePos + root.plateLength

    // A full-length flush plate reaches the screen ends and stays square; a
    // docked edge is square too, and only the inner corners round.
    // Rectangle caps a corner at half of the plate's shorter side, while the
    // blur Region normalizes a lone pill corner against the whole edge. Cap it
    // once here, or the blur rounds to the full bar height and the plate to half.
    readonly property real plateRadiusLimit: Math.min(barPlate.width, barPlate.height) / 2
    readonly property int dockedRadius: root.flushPanel ? 0
        : Math.min(Theme.barRadius, root.plateRadiusLimit)
    readonly property int innerRadius: root.flushPanel
        && ShellState.panelWidth === "full" ? 0
        : Math.min(Theme.barRadius, root.plateRadiusLimit)

    margins {
        top: root.edge === "top" ? root.edgeMargin : root.crossMargin
        bottom: root.edge === "bottom" ? root.edgeMargin : root.crossMargin
        left: root.edge === "left" ? root.edgeMargin : root.crossMargin
        right: root.edge === "right" ? root.edgeMargin : root.crossMargin
    }

    // The bar's docked edge sits at barMargin + thickness; windows start one
    // barMargin away. Quickshell adds `margins` to this value on top of it.
    exclusiveZone: root.thickness + Theme.barMargin
    implicitHeight: root.vertical ? 0 : root.band + Theme.barHeight + root.shadowInset
    implicitWidth: root.vertical ? root.band + Theme.barThickness + root.shadowInset : 0
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar"

    // Only the bar band takes input; the shadow strip stays click-through.
    mask: Region {
        x: root.vertical ? root.plateOffset : 0
        y: root.vertical ? 0 : root.plateOffset
        width: root.vertical ? root.thickness : root.width
        height: root.vertical ? root.height : root.thickness
    }

    // Any image dropped on the bar band becomes the wallpaper. Declared under
    // the islands so it never affects their click handling.
    WallpaperDropArea {
        x: root.vertical ? root.plateOffset : 0
        y: root.vertical ? 0 : root.plateOffset
        width: root.vertical ? root.thickness : root.width
        height: root.vertical ? root.height : root.thickness
    }

    // Acrylic behind the three islands (New and Blur). Off as soon as the
    // bar hides: a compositor blur region cannot fade, so it would hang.
    BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurRegion : null

    // Unscaled twins of the islands for the blur region: it only rebuilds on
    // x/y/w/h changes, so it must not see the islands' entrance translate.
    // Zero-sized outside "islands": their square corners would otherwise cut
    // the single plate's rounded blur back to a rectangle.
    Item {
        id: leftAnchor
        x: leftIsland.x
        y: leftIsland.y
        width: root.islandsMode ? leftIsland.width : 0
        height: root.islandsMode ? leftIsland.height : 0
    }

    Item {
        id: centerAnchor
        x: centerIsland.x
        y: centerIsland.y
        width: root.islandsMode ? centerIsland.width : 0
        height: root.islandsMode ? centerIsland.height : 0
    }

    Item {
        id: rightAnchor
        x: rightIsland.x
        y: rightIsland.y
        width: root.islandsMode ? rightIsland.width : 0
        height: root.islandsMode ? rightIsland.height : 0
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
        Region {
            item: plateAnchor
            radius: barPlate.radius
            topLeftRadius: barPlate.topLeftRadius
            topRightRadius: barPlate.topRightRadius
            bottomLeftRadius: barPlate.bottomLeftRadius
            bottomRightRadius: barPlate.bottomRightRadius
        }
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
            x: root.vertical ? (root.shown ? 0 : (root.flipped ? root.thickness : -root.thickness)) : 0
            y: root.vertical ? 0 : (root.shown ? 0 : (root.flipped ? root.thickness : -root.thickness))

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }
            }

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
            offset.x: root.vertical ? root.shadowSign * Theme.cardShadowOffset : 0
            offset.y: root.vertical ? 0 : root.shadowSign * Theme.cardShadowOffset
            color: Theme.cardShadow
            // A flush panel has no room for a shadow: its docked edge is clipped.
            visible: Theme.glass && !root.islandsMode && !root.flushPanel
        }

        Rectangle {
            id: barPlate

            visible: !root.islandsMode
            x: root.vertical ? root.plateOffset : root.platePos
            y: root.vertical ? root.platePos : root.plateOffset
            width: root.vertical ? root.thickness : root.plateLength
            height: root.vertical ? root.plateLength : Theme.barHeight
            radius: Theme.barRadius
            topLeftRadius: root.edge === "left" || root.edge === "top"
                ? root.dockedRadius : root.innerRadius
            topRightRadius: root.edge === "right" || root.edge === "top"
                ? root.dockedRadius : root.innerRadius
            bottomLeftRadius: root.edge === "left" || root.edge === "bottom"
                ? root.dockedRadius : root.innerRadius
            bottomRightRadius: root.edge === "right" || root.edge === "bottom"
                ? root.dockedRadius : root.innerRadius
            color: Theme.surfaceContainer
            border.width: Theme.hairlineWidth
            border.color: Theme.hairline

            GlassEdge {}
        }

        // first island: workspaces + focused window title (the marquee has no
        // room in a rail, so the title is left out there)
        RectangularShadow {
            anchors.fill: leftIsland
            radius: leftIsland.radius
            blur: Theme.cardShadowBlur
            offset.x: root.vertical ? root.shadowSign * Theme.cardShadowOffset : 0
            offset.y: root.vertical ? 0 : root.shadowSign * Theme.cardShadowOffset
            color: Theme.cardShadow
            visible: Theme.glass && root.islandsMode
        }

        Rectangle {
            id: leftIsland

            x: root.vertical ? root.plateOffset : root.plateStart
            y: root.vertical ? root.plateStart : root.plateOffset
            width: root.vertical ? root.thickness
                : Math.min(leftRow.implicitWidth + 2 * Theme.barPadding, root.leftIslandMaxWidth)
            height: root.vertical
                ? Math.min(leftRow.implicitHeight + 2 * Theme.barPadding, root.topIslandMaxHeight)
                : Theme.barHeight
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

            Behavior on height {
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

            Grid {
                id: leftRow

                x: root.vertical
                    ? Math.round((parent.width - width) / 2) : Theme.barPadding
                y: root.vertical
                    ? Theme.barPadding : Math.round((parent.height - height) / 2)
                // A Grid is the one positioner that turns from a row into a
                // column: one row while horizontal, a single column in a rail.
                columns: root.vertical ? 1 : 1000000
                spacing: 2

                Workspaces {
                    id: workspacesItem

                    screenName: root.modelData.name
                    vertical: root.vertical
                    maxWidth: root.vertical
                        ? root.thickness - 2 * Theme.barPadding
                        : Math.max(0, root.leftContentMaxWidth - leftRow.spacing)
                    maxHeight: root.vertical ? root.topContentMaxHeight : 1e9
                }

                WindowTitle {
                    // The old 18% cap only shrinks the title; workspaces get
                    // the first claim on the room, and a sliver of title is
                    // not worth keeping (see WindowTitle's visible rule).
                    maxWidth: root.vertical ? 0
                        : Math.max(0, Math.min(Math.floor(root.width * 0.18),
                            root.leftContentMaxWidth - workspacesItem.width - leftRow.spacing))
                }
            }
        }

        // center island: clock hero, same surface as the sides
        RectangularShadow {
            anchors.fill: centerIsland
            radius: centerIsland.radius
            blur: Theme.cardShadowBlur
            offset.x: root.vertical ? root.shadowSign * Theme.cardShadowOffset : 0
            offset.y: root.vertical ? 0 : root.shadowSign * Theme.cardShadowOffset
            color: Theme.cardShadow
            visible: Theme.glass && root.islandsMode
        }

        Rectangle {
            id: centerIsland

            x: root.vertical
                ? root.plateOffset : Math.round((root.width - width) / 2)
            y: root.vertical
                ? Math.round((root.height - height) / 2) : root.plateOffset
            width: root.vertical
                ? root.thickness : centerRow.implicitWidth + 2 * Theme.barPadding
            height: root.vertical
                ? centerRow.implicitHeight + 2 * Theme.barPadding : Theme.barHeight
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

            Grid {
                id: centerRow

                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                columns: root.vertical ? 1 : 1000000
                spacing: 4

                KeyboardLayout {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    labelOnly: root.vertical
                    hPadding: root.vertical ? 4 : 12
                }
                DateClock {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    screenName: root.modelData.name
                    compact: root.vertical
                }
                TimeClock {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    screenName: root.modelData.name
                    compact: root.vertical
                }
            }
        }

        // last island: status cluster + notification + power FAB
        RectangularShadow {
            anchors.fill: rightIsland
            radius: rightIsland.radius
            blur: Theme.cardShadowBlur
            offset.x: root.vertical ? root.shadowSign * Theme.cardShadowOffset : 0
            offset.y: root.vertical ? 0 : root.shadowSign * Theme.cardShadowOffset
            color: Theme.cardShadow
            visible: Theme.glass && root.islandsMode
        }

        Rectangle {
            id: rightIsland

            x: root.vertical ? root.plateOffset : root.plateEnd - width
            y: root.vertical ? root.plateEnd - height : root.plateOffset
            width: root.vertical
                ? root.thickness : rightRow.implicitWidth + 2 * Theme.barPadding
            height: root.vertical
                ? rightRow.implicitHeight + 2 * Theme.barPadding : Theme.barHeight
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

            Grid {
                id: rightRow

                x: root.vertical
                    ? Math.round((parent.width - width) / 2)
                    : parent.width - width - Theme.barPadding
                y: root.vertical
                    ? Theme.barPadding : Math.round((parent.height - height) / 2)
                columns: root.vertical ? 1 : 1000000
                spacing: 4

                // The rail shows the values themselves: the layout code, the
                // brightness and the volume percentage.
                Backlight {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    labelOnly: root.vertical
                    hPadding: root.vertical ? 4 : 12
                }
                SystemStats {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    screenName: root.modelData.name
                    compact: root.vertical
                    round: root.vertical
                }
                Volume {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    labelOnly: root.vertical
                    hPadding: root.vertical ? 4 : 12
                }
                Battery {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    compact: root.vertical
                    round: root.vertical
                }

                Tray {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    screenName: root.modelData.name
                }

                NotificationBell {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    screenName: root.modelData.name
                }

                PetButton {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    screenName: root.modelData.name
                    visible: ShellState.petEnabled
                }

                PowerButton {
                    width: root.vertical ? root.railContentWidth : implicitWidth
                    screenName: root.modelData.name
                }
            }
        }
    }
}
