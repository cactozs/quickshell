pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../style"

// macOS-style keyboard-layout HUD restyled for M3 Expressive: a segmented
// pill near the top of the screen listing every configured layout, with the
// targeted one highlighted on a lighter container. Shown briefly after the
// active layout changes. The overlay is fully click- and keyboard-transparent
// and only mapped while the badge is shown.
PanelWindow {
    id: root

    required property ShellScreen modelData

    // How long the badge stays on screen after a switch.
    readonly property int showDuration: 1000
    // Distance from the top of the screen (the bar ends around 46 px).
    readonly property int topMargin: 72
    readonly property int pillHeight: 52

    // Short uppercase code for every configured layout, in switch order.
    readonly property var layouts: Niri.keyboardLayouts.names.map(
        name => Niri.layoutShortName(name).toUpperCase())

    property bool shown: false
    // Follows niri directly, so the highlight re-targets on rapid switches.
    property int activeIdx: Niri.keyboardLayouts.currentIdx

    function show(): void {
        // When already visible only the highlight and the timer change, so
        // rapid switches swap without replaying the pop-in.
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

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.85

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
                duration: Theme.durMedium
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        Row {
            id: segments

            anchors.centerIn: parent

            Repeater {
                model: root.layouts

                // One layout segment: the code on a rounded highlight that
                // lights up (lighter container) when it is the active layout.
                delegate: Item {
                    id: segment

                    required property int index
                    required property string modelData

                    implicitWidth: label.implicitWidth + 28
                    implicitHeight: root.pillHeight - 8

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeFull
                        color: segment.index === root.activeIdx
                            ? Theme.surfaceContainerHighest : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveEmphasized
                            }
                        }
                    }

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
                            ? Theme.surfaceText : Theme.surfaceVariantText
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
