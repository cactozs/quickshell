pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../services"
import "../style"

// Settings menu: a centered card over a full-screen scrim, unlike the bar's
// docked panels. Opened from the "Настройки" tile in the quick settings;
// Esc or a click outside dismisses it. Five sections: the launcher view, the
// shell-wide style pack, the blur source (hidden while nothing blurs), the
// color scheme and the wallpaper manager shortcut.
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

    // Acrylic behind the card (New and Blur).
    BackgroundEffect.blurRegion: Theme.blur ? blurRegion : null

    // Unscaled twin of the card for the blur region: it only rebuilds on
    // x/y/w/h changes, so it must not see the entrance scale.
    Item {
        id: blurAnchor
        anchors.fill: card
    }

    Region {
        id: blurRegion

        Region { item: blurAnchor; radius: card.radius }
    }

    // A lazily built window (LazyOverlay) is born already open, where
    // onShownChanged never fires, so the focus kick runs on creation as well.
    Component.onCompleted: {
        if (root.shown)
            focusKick.restart();
    }

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

    // Ambient shadow under the card (New style only). Follows the card's
    // entrance fade/scale, since it is a sibling and not a child.
    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: Theme.glass
        opacity: card.opacity
        scale: card.scale
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width - 48)
        height: column.implicitHeight + 2 * root.cardPadding
        radius: Theme.shapeXL
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

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

            // ---- launcher view --------------------------------------------------

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Вид лончера"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBodyLarge
                }

                SettingSegment {
                    label: "Классический"
                    selected: !ShellState.launcherFullscreen
                    onClicked: ShellState.setLauncherFullscreen(false)
                }

                SettingSegment {
                    label: "Полноэкранный"
                    selected: ShellState.launcherFullscreen
                    onClicked: ShellState.setLauncherFullscreen(true)
                }
            }

            // ---- style pack -----------------------------------------------------

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Стиль"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBodyLarge
                }

                SettingSegment {
                    label: "M3 Inspired"
                    selected: ShellState.styleMode !== "new" && ShellState.styleMode !== "blur"
                    onClicked: ShellState.setStyleMode("m3")
                }

                SettingSegment {
                    label: "M3 Blur"
                    selected: ShellState.styleMode === "blur"
                    onClicked: ShellState.setStyleMode("blur")
                }

                SettingSegment {
                    label: "New"
                    selected: ShellState.styleMode === "new"
                    onClicked: ShellState.setStyleMode("new")
                }
            }

            // ---- blur source ----------------------------------------------------

            // Only the blur styles have anything to blur, so the row is hidden
            // under M3 Inspired: its surfaces are opaque and no window requests
            // a background effect (the niri rule stays inert by itself).
            RowLayout {
                width: parent.width
                spacing: 8
                visible: ShellState.styleMode !== "m3"

                Text {
                    Layout.fillWidth: true
                    text: "Блюр"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBodyLarge
                }

                SettingSegment {
                    label: "Обои"
                    selected: ShellState.blurSource === "wallpaper"
                    onClicked: ShellState.setBlurSource("wallpaper")
                }

                SettingSegment {
                    label: "Окна"
                    selected: ShellState.blurSource === "window"
                    onClicked: ShellState.setBlurSource("window")
                }
            }

            // ---- theme mode -----------------------------------------------------

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Тема"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBodyLarge
                }

                SettingSegment {
                    label: "Тёмная"
                    selected: !Theme.light
                    onClicked: ShellState.setThemeMode("dark")
                }

                SettingSegment {
                    label: "Светлая"
                    selected: Theme.light
                    onClicked: ShellState.setThemeMode("light")
                }
            }

            // ---- color scheme ---------------------------------------------------

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Цвета"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBodyLarge
                }

                SettingSegment {
                    label: "Matugen"
                    selected: ShellState.colorScheme === "matugen"
                    onClicked: ShellState.setColorScheme("matugen")
                }

                SettingSegment {
                    label: "OLED"
                    selected: ShellState.colorScheme === "oled"
                    onClicked: ShellState.setColorScheme("oled")
                }

                SettingSegment {
                    label: "Gruvbox"
                    selected: ShellState.colorScheme === "gruvbox"
                    onClicked: ShellState.setColorScheme("gruvbox")
                }
            }

            // ---- wallpaper ------------------------------------------------------

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Обои"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBodyLarge
                }

                IconButton {
                    round: true
                    icon: Theme.iconOrnament
                    iconFamily: Theme.nerdFont

                    onClicked: {
                        ShellState.closeSettings();
                        ShellState.toggleWallpaper(root.modelData.name);
                    }
                }
            }
        }
    }

    // One segment of a two-option selector: tonal when picked, outlined when not.
    component SettingSegment: Rectangle {
        id: seg

        property string label: ""
        property bool selected: false

        signal clicked

        implicitWidth: segLabel.implicitWidth + 32
        implicitHeight: 40
        radius: Theme.shapeFull
        color: seg.selected ? Theme.secondaryContainer : "transparent"
        border.width: seg.selected ? 0 : 1
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        StateLayer {
            hovered: segHover.hovered
            pressed: segTap.pressed
            color: seg.selected ? Theme.secondaryContainerText : Theme.surfaceText
        }

        Text {
            id: segLabel

            anchors.centerIn: parent
            text: seg.label
            color: seg.selected ? Theme.secondaryContainerText : Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            font.weight: seg.selected ? Font.Medium : Font.Normal

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }
        }

        MouseArea {
            id: segTap

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: seg.clicked()
        }

        HoverHandler {
            id: segHover
        }
    }
}
