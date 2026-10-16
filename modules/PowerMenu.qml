pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../services"
import "../style"

// M3 Expressive power menu (replaces wlogout): a full-screen scrim plus a
// centered card of six tonal actions. Opened from the bar's power button,
// dismissed by Esc, a shortcut letter, or a click on the scrim.
PanelWindow {
    id: root

    required property ShellScreen modelData

    // ---- configuration ---------------------------------------------------------

    readonly property int columns: 3

    // wlogout-style letters: s = shutdown, r = reboot, e = exit, h = hibernate,
    // l = lock, u = suspend (cУspend, as in wlogout's default layout).
    readonly property var actions: [
        {
            icon: Theme.iconPower,
            label: "Выключение",
            shortcut: Qt.Key_S,
            keys: ["s", "ы"],
            command: ["systemctl", "poweroff"],
            container: Theme.errorContainer,
            content: Theme.errorContainerText
        },
        {
            icon: Theme.iconRestart,
            label: "Перезагрузка",
            shortcut: Qt.Key_R,
            keys: ["r", "к"],
            command: ["systemctl", "reboot"],
            container: Theme.primaryContainer,
            content: Theme.primaryContainerText
        },
        {
            icon: Theme.iconLogout,
            label: "Выход",
            shortcut: Qt.Key_E,
            keys: ["e", "у"],
            command: ["niri", "msg", "action", "quit", "--skip-confirmation"],
            container: Theme.secondaryContainer,
            content: Theme.secondaryContainerText
        },
        {
            icon: Theme.iconHibernate,
            label: "Гибернация",
            shortcut: Qt.Key_H,
            keys: ["h", "р"],
            command: ["systemctl", "hibernate"],
            container: Theme.tertiaryContainer,
            content: Theme.tertiaryContainerText
        },
        {
            icon: Theme.iconLock,
            label: "Блокировка",
            shortcut: Qt.Key_L,
            keys: ["l", "д"],
            command: ["hyprlock"],
            container: Theme.surfaceContainerHighest,
            content: Theme.surfaceText
        },
        {
            icon: Theme.iconSuspend,
            label: "Сон",
            shortcut: Qt.Key_U,
            keys: ["u", "г"],
            command: ["systemctl", "suspend"],
            container: Theme.primary,
            content: Theme.primaryText
        }
    ]

    // `shown` is the semantic state; the window stays mapped while the close
    // fade plays out (see `visible` below), like LayoutBadge.
    readonly property bool shown: ShellState.powerMenuScreen === root.modelData.name

    property int currentIndex: 0

    // Lock is focused on open: a stray Enter right after summoning the menu
    // must not power the machine off.
    readonly property int defaultIndex: root.actions.findIndex(a => a.icon === Theme.iconLock)

    function moveFocus(delta: int): void {
        const n = root.actions.length;
        root.currentIndex = ((root.currentIndex + delta) % n + n) % n;
    }

    function activate(index: int): void {
        ShellState.closePowerMenu();
        Quickshell.execDetached(root.actions[index].command);
    }

    // ---- panel window ----------------------------------------------------------

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
    WlrLayershell.namespace: "quickshell:power"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (root.shown) {
            root.currentIndex = root.defaultIndex;
            focusKick.restart();
        }
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
        opacity: root.shown ? 0.5 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }
    }

    // click outside the card dismisses the menu
    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.closePowerMenu()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                ShellState.closePowerMenu();
                break;
            case Qt.Key_Left:
                root.moveFocus(-1);
                break;
            case Qt.Key_Right:
                root.moveFocus(1);
                break;
            case Qt.Key_Up:
                root.moveFocus(-root.columns);
                break;
            case Qt.Key_Down:
                root.moveFocus(root.columns);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.activate(root.currentIndex);
                break;
            default: {
                // In a cyrillic layout the letter arrives as Qt.Key_Cyrillic_*,
                // so also match event.text against the action's `keys`.
                const ch = event.text.toLowerCase();
                for (let i = 0; i < root.actions.length; i++) {
                    if (event.key === root.actions[i].shortcut
                            || (ch.length === 1 && root.actions[i].keys.includes(ch))) {
                        root.activate(i);
                        break;
                    }
                }
            }
            }
            event.accepted = true;
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        implicitWidth: grid.implicitWidth + 48
        implicitHeight: grid.implicitHeight + 48
        width: implicitWidth
        height: implicitHeight

        radius: Theme.shapeXL
        color: Theme.surfaceContainerHigh

        scale: root.shown ? 1 : 0.85
        opacity: root.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durLong
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        Grid {
            id: grid

            anchors.centerIn: parent
            columns: root.columns
            spacing: 12

            Repeater {
                model: root.actions

                PowerAction {
                    focused: root.currentIndex === index

                    onHoverRequested: root.currentIndex = index
                    onActivated: root.activate(index)
                }
            }
        }
    }

    // Large tonal action tile: icon over a caption, state layer + focus ring.
    component PowerAction: Rectangle {
        id: action

        required property int index
        required property var modelData

        property bool focused: false
        readonly property bool hovered: hoverHandler.hovered
        readonly property bool pressed: tapArea.pressed

        signal activated
        signal hoverRequested

        implicitWidth: 104
        implicitHeight: 104
        radius: Theme.shapeXL
        color: action.modelData.container

        scale: action.pressed ? 0.94 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
        }

        StateLayer {
            hovered: action.hovered
            pressed: action.pressed
            color: action.modelData.content
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: action.modelData.content
            opacity: action.focused ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: action.modelData.icon
                color: action.modelData.content
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSizeLarge
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: action.modelData.label
                    color: action.modelData.content
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                    font.weight: Font.Medium
                }

                // Physical (latin) shortcut letter, from the wlogout-style `keys`.
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: action.modelData.keys[0].toUpperCase()
                    color: action.modelData.content
                    opacity: 0.55
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                    font.weight: Font.Medium
                }
            }
        }

        HoverHandler {
            id: hoverHandler

            onHoveredChanged: {
                if (hoverHandler.hovered)
                    action.hoverRequested();
            }
        }

        MouseArea {
            id: tapArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton

            onClicked: action.activated()
        }
    }
}
