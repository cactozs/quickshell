pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
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

        opacity: Osd.shown ? 1 : 0
        scale: Osd.shown ? 1 : 0.85

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
                easing.overshoot: Theme.springOvershoot
            }
        }

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

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasized
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 160
                Layout.preferredHeight: 12

                radius: Theme.shapeFull
                color: Theme.surfaceContainerHighest

                Rectangle {
                    width: parent.width * Osd.value
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveEmphasized
                        }
                    }
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
