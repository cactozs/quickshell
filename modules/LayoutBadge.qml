pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// macOS-style keyboard-layout HUD restyled for M3 Expressive: a segmented
// pill near the top of the screen. One shared highlight slides between the
// layout codes with a rubber stretch. Shown briefly after the active layout
// changes. Click- and keyboard-transparent, mapped only while shown.
PanelWindow {
    id: root

    required property ShellScreen modelData

    // How long the badge stays on screen after a switch.
    readonly property int showDuration: 1000
    // Distance from the top of the screen (the bar pill ends around 50 px).
    readonly property int topMargin: 72
    readonly property int pillHeight: 52

    // Short uppercase code for every configured layout, in switch order.
    readonly property var layouts: Niri.keyboardLayouts.names.map(
        name => Niri.layoutShortName(name).toUpperCase())

    property bool shown: false
    // Follows niri directly, so the highlight re-targets on rapid switches.
    property int activeIdx: Niri.keyboardLayouts.currentIdx

    // Live segment behind the highlight; Row.children tracks the Repeater.
    readonly property Item activeSeg: (root.activeIdx >= 0 && segments.children.length > root.activeIdx)
        ? segments.children[root.activeIdx] : null

    function show(): void {
        // When already visible only the highlight and the timer change, so
        // rapid switches slide without replaying the pop-in.
        root.shown = true;
        hideTimer.restart();
    }

    function hide(): void {
        root.shown = false;
    }

    // ---- panel window ----------------------------------------------------------

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Mapped only while the badge is on screen (including the exit fade).
    visible: root.shown || pill.opacity > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:layout"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Empty input region: every click passes through to the window below.
    mask: Region {}

    Connections {
        target: Niri

        function onLayoutSwitched(): void {
            root.show();
        }
    }

    Timer {
        id: hideTimer
        interval: root.showDuration
        onTriggered: root.hide()
    }

    // Acrylic behind the pill (New and Blur). Off as soon as it closes: a
    // compositor blur region cannot fade, so it would hang under the pill.
    BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurRegion : null

    // Unscaled twin of the pill for the blur region: it only rebuilds on
    // x/y/w/h changes, so it must not see the entrance scale/translate.
    Item {
        id: blurAnchor
        anchors.fill: pill
    }

    Region {
        id: blurRegion

        Region { item: blurAnchor; radius: pill.radius }
    }

    // Ambient shadow under the pill (New style only); follows the pill's
    // entrance fade/scale.
    RectangularShadow {
        anchors.fill: pill
        radius: pill.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: Theme.glass
        opacity: pill.opacity
        scale: pill.scale
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.topMargin

        implicitWidth: segments.implicitWidth + 8
        implicitHeight: root.pillHeight
        width: implicitWidth
        height: implicitHeight

        radius: Theme.shapeFull
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.85

        // Entrance drops from above while fading in.
        transform: Translate {
            y: root.shown ? 0 : -8

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durShort
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

        // Expressive pop-in; on hide the same spring reads as a light shrink.
        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        // Shared sliding highlight: x glides, width overshoots = stretch.
        Rectangle {
            id: slide

            x: segments.x + (root.activeSeg !== null ? root.activeSeg.x : 0)
            y: segments.y
            width: root.activeSeg !== null ? root.activeSeg.width : 0
            height: segments.height
            visible: root.activeSeg !== null

            radius: Theme.shapeFull
            color: Theme.secondaryContainer

            Behavior on x {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasizedDecelerate
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutBack
                    easing.overshoot: Theme.springOvershoot
                }
            }
        }

        Row {
            id: segments

            anchors.centerIn: parent

            Repeater {
                model: root.layouts

                // One layout segment: the code centers on the shared
                // highlight when it is the active layout.
                delegate: Item {
                    id: segment

                    required property int index
                    required property string modelData

                    implicitWidth: label.implicitWidth + 28
                    implicitHeight: root.pillHeight - 8
                    width: implicitWidth
                    height: implicitHeight

                    // 1 px rule between two neighbouring unselected segments,
                    // as in the M3 segmented button.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 16
                        color: Theme.outlineVariant
                        visible: opacity > 0
                        opacity: segment.index > 0
                            && segment.index !== root.activeIdx
                            && segment.index - 1 !== root.activeIdx ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveEmphasized
                            }
                        }
                    }

                    Text {
                        id: label

                        anchors.centerIn: parent
                        text: segment.modelData
                        color: segment.index === root.activeIdx
                            ? Theme.secondaryContainerText : Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitleLarge
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
        }
    }
}
