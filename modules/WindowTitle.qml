pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"
import "../style"

// Focused niri window: app icon + title, muted until hovered.
// Long titles scroll like a marquee on hover inside a fixed viewport, so the
// bar island never stretches. Window switches get a quick fade.
Item {
    id: root

    required property int maxWidth

    property var win: Niri.focusedWindow
    property int winId: win?.id ?? -1
    property string appId: win?.app_id ?? ""
    property string title: win?.title ?? ""

    readonly property string iconName: {
        if (appId === "") return "";
        const entry = DesktopEntries.applications.values.find(e => e.appId === appId);
        return entry?.icon ?? appId;
    }

    readonly property real textStartX: 8 + (icon.visible ? icon.width + 6 : 0)
    readonly property real viewportWidth: Math.max(0, root.width - textStartX - 4)
    readonly property bool needsScroll: measurer.implicitWidth > root.viewportWidth + 1
    readonly property bool scrolling: hover.hovered && root.needsScroll && root.win !== null
        && Theme.motion > 0

    property real scrollX: 0
    property real scrollDist: 0
    property bool ready: false

    // The bar hands the title whatever the workspace chips leave. Half an
    // icon plus a couple of glyphs is not worth the row gap, so below this
    // the chip disappears instead of squeezing to zero.
    readonly property int minUsefulWidth: 48

    height: Theme.barHeight
    visible: root.win !== null && root.maxWidth >= root.minUsefulWidth
    implicitWidth: !visible ? 0 : 8 + (icon.visible ? icon.width + 6 : 0) + measurer.implicitWidth + 4
    width: Math.min(implicitWidth, maxWidth)

    Behavior on width { Anim { duration: Theme.dur(100) } }

    // Quick fade on window switch only (title edits scroll, they don't fade).
    SequentialAnimation {
        id: swap

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0.25
            duration: Theme.dur(40)
            easing.type: Easing.Linear
        }

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: Theme.dur(80)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEmphasized
        }
    }

    // Marquee: pause, glide left, pause, glide back. Loops while hovered.
    // Driven imperatively from onScrollingChanged; the distance is snapshotted
    // at start so mid-run resizes apply on the next loop, not mid-glide.
    SequentialAnimation {
        id: marquee

        loops: Animation.Infinite

        PauseAnimation {
            duration: Theme.dur(250)
        }

        NumberAnimation {
            target: root
            property: "scrollX"
            from: 0
            to: -root.scrollDist
            duration: Theme.dur(Math.min(2000, Math.max(300, root.scrollDist * 12)))
            easing.type: Easing.Linear
        }

        PauseAnimation {
            duration: Theme.dur(250)
        }

        NumberAnimation {
            target: root
            property: "scrollX"
            to: 0
            duration: Theme.dur(160)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEmphasizedDecelerate
        }
    }

    function startMarquee(): void {
        root.scrollDist = Math.max(0, measurer.implicitWidth - root.viewportWidth);
        root.scrollX = 0;
        marquee.start();
    }

    function stopMarquee(): void {
        marquee.stop();
        root.scrollX = 0;
    }

    onScrollingChanged: {
        if (root.scrolling)
            root.startMarquee();
        else
            root.stopMarquee();
    }
    onTitleChanged: {
        if (root.scrolling)
            root.startMarquee();
        else
            root.scrollX = 0;
    }
    onWinIdChanged: {
        if (root.ready)
            swap.restart();
        if (root.scrolling)
            root.startMarquee();
        else
            root.scrollX = 0;
    }

    Component.onCompleted: root.ready = true

    IconImage {
        id: icon

        x: 8
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Theme.iconSize
        source: root.iconName !== "" ? Quickshell.iconPath(root.iconName) : ""
        visible: source.toString() !== ""
    }

    Item {
        id: viewport

        x: root.textStartX
        anchors.verticalCenter: parent.verticalCenter
        width: root.viewportWidth
        height: parent.height
        clip: true

        Text {
            id: titleText

            anchors.verticalCenter: parent.verticalCenter
            x: root.scrolling ? root.scrollX : 0
            width: root.scrolling ? implicitWidth : parent.width
            text: root.title
            elide: root.scrolling ? Text.ElideNone : Text.ElideRight
            color: hover.hovered ? Theme.surfaceText : Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            font.weight: Font.Medium

            Behavior on color { ColorAnim {} }
        }
    }

    // Hidden twin measuring the full title width. titleText switches width
    // and elide mode while scrolling, so only this unconstrained copy can
    // be trusted for the cut-off check and the scroll distance.
    Text {
        id: measurer

        visible: false
        text: root.title
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabelLarge
        font.weight: Font.Medium
    }

    HoverHandler {
        id: hover
    }

    Tip {
        target: root
        text: root.title
        // Only when the title is actually cut off.
        shown: hover.hovered && root.needsScroll
    }
}
