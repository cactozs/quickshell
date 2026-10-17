pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../style"

// Settings menu: a centered card over a full-screen scrim, unlike the bar's
// docked panels. Opened from the "Настройки" tile in the quick settings;
// Esc or a click outside dismisses it. Contents are still a placeholder.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.settingsScreen === root.modelData.name

    readonly property int cardWidth: 560
    readonly property int cardPadding: 20

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Fullscreen modal: ignore the bar's exclusive zone so the scrim covers
    // the whole output (Ignore and exclusiveZone are mutually exclusive).
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: root.shown || card.opacity > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:settings"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (root.shown)
            focusKick.restart();
    }

    // Layer surfaces take a moment to gain keyboard focus; make sure the key
    // catcher ends up active either way.
    Timer {
        id: focusKick
        interval: 50
        onTriggered: keyCatcher.forceActiveFocus()
    }

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Theme.scrim
        opacity: root.shown ? Theme.scrimOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }
    }

    // click outside the card dismisses the menu
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeSettings()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                ShellState.closeSettings();
            event.accepted = true;
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width - 48)
        height: column.implicitHeight + 2 * root.cardPadding
        radius: Theme.shapeXL
        color: Theme.surfaceContainerHigh

        scale: root.shown ? 1 : 0.9
        opacity: root.shown ? 1 : 0

        // M3E card entrance: springy scale under a faster fade.
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        // Swallow clicks on the card so they don't reach the dismiss area.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.cardPadding
            }

            spacing: 16

            Text {
                width: parent.width
                text: "Настройки"
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitleLarge
                font.weight: Font.Medium
            }

            // placeholder: sections will replace this
            Rectangle {
                width: parent.width
                height: 160
                radius: Theme.shapeLG
                color: Theme.surfaceContainerHighest

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Theme.iconSettings
                        color: Theme.surfaceVariantText
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSizeLarge
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Пока пусто"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelLarge
                    }
                }
            }
        }
    }
}
