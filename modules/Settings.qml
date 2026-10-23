pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// Settings menu: a centered card over a full-screen scrim, unlike the bar's
// docked panels. Opened from the "Настройки" tile in the quick settings;
// Esc or a click outside dismisses it. Nine sections: the UI language, the
// launcher view, the shell-wide style pack, the blur source (hidden while
// nothing blurs), the theme mode, the color scheme, the font, the system
// power profile and the wallpaper manager shortcut.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.settingsScreen === root.modelData.name

    // Wide enough for the five style segments next to their label.
    readonly property int cardWidth: 620
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
                text: I18n.t("Настройки")
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitleLarge
                font.weight: Font.Medium
            }

            // ---- language -------------------------------------------------------

            // Native names on purpose: they need no translation and stay
            // readable whichever language is picked.
            SettingRow {
                label: I18n.t("Язык")

                SettingSegment {
                    label: "Русский"
                    selected: ShellState.language === "ru"
                    onClicked: ShellState.setLanguage("ru")
                }

                SettingSegment {
                    label: "English"
                    selected: ShellState.language === "en"
                    onClicked: ShellState.setLanguage("en")
                }

                SettingSegment {
                    label: "Deutsch"
                    selected: ShellState.language === "de"
                    onClicked: ShellState.setLanguage("de")
                }
            }

            // ---- launcher view --------------------------------------------------

            SettingRow {
                label: I18n.t("Вид лончера")

                SettingSegment {
                    label: I18n.t("Классический")
                    selected: !ShellState.launcherFullscreen
                    onClicked: ShellState.setLauncherFullscreen(false)
                }

                SettingSegment {
                    label: I18n.t("Полноэкранный")
                    selected: ShellState.launcherFullscreen
                    onClicked: ShellState.setLauncherFullscreen(true)
                }
            }

            // ---- style pack -----------------------------------------------------

            SettingRow {
                label: I18n.t("Стиль")

                SettingSegment {
                    label: "M3 Inspired"
                    selected: ShellState.styleMode === "m3"
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

                SettingSegment {
                    label: "Nothing"
                    selected: ShellState.styleMode === "nothing"
                    onClicked: ShellState.setStyleMode("nothing")
                }

                SettingSegment {
                    label: "New Nothing"
                    selected: ShellState.styleMode === "newNothing"
                    onClicked: ShellState.setStyleMode("newNothing")
                }
            }

            // ---- blur source ----------------------------------------------------

            // Only the blur styles have anything to blur, so the row is hidden
            // under M3 Inspired and Nothing: their surfaces are opaque and no
            // window requests a background effect (the niri rule stays inert
            // by itself). Theme.blur is exactly that set.
            SettingRow {
                label: I18n.t("Блюр")
                visible: Theme.blur

                SettingSegment {
                    label: I18n.t("Обои")
                    selected: ShellState.blurSource === "wallpaper"
                    onClicked: ShellState.setBlurSource("wallpaper")
                }

                SettingSegment {
                    label: I18n.t("Окна")
                    selected: ShellState.blurSource === "window"
                    onClicked: ShellState.setBlurSource("window")
                }
            }

            // ---- theme mode -----------------------------------------------------

            SettingRow {
                label: I18n.t("Тема")

                SettingSegment {
                    label: I18n.t("Тёмная")
                    selected: !Theme.light
                    onClicked: ShellState.setThemeMode("dark")
                }

                SettingSegment {
                    label: I18n.t("Светлая")
                    selected: Theme.light
                    onClicked: ShellState.setThemeMode("light")
                }
            }

            // ---- color scheme ---------------------------------------------------

            SettingRow {
                label: I18n.t("Цвета")

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

            // ---- font -----------------------------------------------------------

            SettingRow {
                label: I18n.t("Шрифт")

                SettingSegment {
                    label: "Material"
                    selected: ShellState.fontMode === "material"
                    onClicked: ShellState.setFontMode("material")
                }

                SettingSegment {
                    label: "Monospace"
                    selected: ShellState.fontMode === "mono"
                    onClicked: ShellState.setFontMode("mono")
                }
            }

            // ---- power profile --------------------------------------------------

            // Straight from power-profiles-daemon: it is the source of truth,
            // so there is no shell-side copy to persist. The performance
            // segment is hidden when the daemon reports no such profile.
            SettingRow {
                label: I18n.t("Профиль питания")

                SettingSegment {
                    label: I18n.t("Экономия")
                    selected: PowerProfiles.profile === PowerProfile.PowerSaver
                    onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
                }

                SettingSegment {
                    label: I18n.t("Баланс")
                    selected: PowerProfiles.profile === PowerProfile.Balanced
                    onClicked: PowerProfiles.profile = PowerProfile.Balanced
                }

                SettingSegment {
                    label: I18n.t("Производительность")
                    visible: PowerProfiles.hasPerformanceProfile
                    selected: PowerProfiles.profile === PowerProfile.Performance
                    onClicked: PowerProfiles.profile = PowerProfile.Performance
                }
            }

            // ---- muted notification apps ---------------------------------------

            SettingRow {
                label: I18n.t("Уведомления")
                visible: Notifications.mutedApps.length > 0

                Repeater {
                    model: Notifications.mutedApps

                    delegate: SettingSegment {
                        required property string modelData

                        label: modelData
                        selected: true
                        onClicked: Notifications.toggleMuteApp(modelData)
                    }
                }

                SettingSegment {
                    label: I18n.t("Вернуть все")
                    onClicked: Notifications.unmuteAll()
                }
            }

            // ---- wallpaper ------------------------------------------------------

            SettingRow {
                label: I18n.t("Обои")

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

    // One settings row. The label wraps instead of being squeezed under the
    // first segment, and the segments flow onto more lines when they run out of
    // room. A RowLayout cannot do this: it shrank the label past its text width
    // and reported a recursive rearrange once the label wrapped.
    component SettingRow: Item {
        id: row

        property string label: ""
        default property alias content: options.data

        // Width the segments need on one line. A Flow always packs from its own
        // left edge, so right-aligning them means giving it exactly this width
        // and letting it grow to the full gap only when it has to wrap.
        readonly property real optionsWidth: {
            let width = 0;
            let count = 0;
            for (let i = 0; i < options.children.length; ++i) {
                const child = options.children[i];
                if (!child.visible || child.width === 0)
                    continue;
                width += child.implicitWidth;
                ++count;
            }
            return width + Math.max(0, count - 1) * options.spacing;
        }

        width: parent.width
        height: Math.max(rowLabel.height, options.height)

        Text {
            id: rowLabel

            width: Math.min(implicitWidth, row.width * 0.45)
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBodyLarge
            wrapMode: Text.WordWrap
        }

        Flow {
            id: options

            width: Math.min(Math.max(0, row.width - rowLabel.width - 8), row.optionsWidth)
            x: row.width - width
            anchors.verticalCenter: parent.verticalCenter

            spacing: 8
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
        // Nothing and New square the segment off instead of the M3 pill.
        radius: Theme.nothing || Theme.glass ? Theme.shapeMD : Theme.shapeFull
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
