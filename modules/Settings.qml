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
// Esc or a click outside dismisses it. Five tabs — appearance (style pack,
// blur source, theme, colors, font, ambient), interface (language, launcher
// view, wallpaper shortcut), apps (which desktop color targets are written),
// system (muted apps, power profile) and Custom (the hand-built pack's knobs and
// palette). The card always opens on the first tab and animates its height
// between pages.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.settingsScreen === root.modelData.name

    // 0 = Оформление, 1 = Интерфейс, 2 = Приложения, 3 = Система,
    // 4 = Custom. Reset on every open so the menu is predictable; the window
    // itself outlives a close by 20 s.
    property int tabIndex: 0

    // Role being edited in the palette picker ("" = closed). The picker only
    // reports a value, so cancel needs no rollback.
    property string pickerRole: ""

    // Wide enough for the style segments next to their label.
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

    // Acrylic behind the card (New and Blur). Off as soon as it closes: a
    // compositor blur region cannot fade, so it would hang under the card.
    BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurRegion : null

    // The region is the plate's rect about the same centre, entrance scale
    // included. It never reaches past the plate either: the animated height on
    // the way up, the destination on the way down, so a late region update can
    // only leave a mismatch under the acrylic.
    Region {
        id: blurRegion

        Region {
            x: Math.round(card.x + card.width * (1 - card.scale) / 2)
            y: Math.round(card.y + (card.height - card.blurHeight * card.scale) / 2)
            width: Math.round(card.width * card.scale)
            height: Math.round(card.blurHeight * card.scale)
            radius: Math.round(card.radius * card.scale)
        }
    }

    // The region only lands on the commit after the frame that set it; kick
    // repaints while the card morphs so the blur can't trail behind it.
    BlurKick {
        id: blurKick

        region: blurRegion
    }

    // A lazily built window (LazyOverlay) is born already open, where
    // onShownChanged never fires, so the focus kick runs on creation as well.
    Component.onCompleted: {
        if (root.shown)
            focusKick.restart();
    }

    onShownChanged: {
        root.pickerRole = "";
        if (root.shown) {
            root.tabIndex = 0;
            focusKick.restart();
        }
    }

    onTabIndexChanged: root.pickerRole = ""

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
            if (event.key === Qt.Key_Escape) {
                if (root.pickerRole !== "")
                    root.pickerRole = "";
                else
                    ShellState.closeSettings();
            } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                && (event.modifiers & Qt.ControlModifier)) {
                const back = event.key === Qt.Key_Backtab
                    || (event.modifiers & Qt.ShiftModifier);
                root.tabIndex = (root.tabIndex + (back ? -1 : 1) + tabs.count) % tabs.count;
            }
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
        transformOrigin: Item.Center
    }

    Rectangle {
        id: card

        // The height the card is heading for, without the morph. The blur region is
        // built from this and from the animated height; see blurRegion.
        readonly property real targetHeight: column.implicitHeight + 2 * root.cardPadding
        readonly property real blurHeight: Math.min(height, targetHeight)

        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width - 48)
        height: targetHeight
        radius: Theme.shapeXL
        // The pages are laid out for the final height at once, so without this
        // the taller page draws outside the still-growing plate.
        clip: true
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        // About the centre: growing from the top-left corner slid the plate ~30x40
        // px up-left during the entrance.
        transformOrigin: Item.Center
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

        // Each tab has its own height; the card follows with the M3 container
        // timing while the pages clip their own overflow.
        onHeightChanged: blurKick.kick()
        onScaleChanged: blurKick.kick()

        Behavior on height {
            NumberAnimation {
                duration: Theme.durPop
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
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

            // ---- tabs -----------------------------------------------------------

            Item {
                id: tabBar

                width: parent.width
                height: 44

                readonly property real cellWidth: width / tabs.count

                Repeater {
                    id: tabs

                    model: [I18n.t("Оформление"), I18n.t("Интерфейс"), I18n.t("Приложения"),
                        I18n.t("Система"), I18n.t("Custom")]

                    delegate: Item {
                        id: tabItem

                        required property int index
                        required property string modelData

                        x: index * tabBar.cellWidth
                        width: tabBar.cellWidth
                        height: tabBar.height

                        readonly property bool selected: root.tabIndex === index

                        Rectangle {
                            anchors.centerIn: parent
                            width: tabLabel.implicitWidth + 32
                            height: 32
                            radius: Theme.nothing || Theme.glass ? Theme.shapeMD : Theme.shapeFull
                            color: "transparent"

                            StateLayer {
                                hovered: tabHover.hovered
                                pressed: tabTap.pressed
                                color: tabItem.selected ? Theme.primary : Theme.surfaceText
                            }

                            Text {
                                id: tabLabel

                                anchors.centerIn: parent
                                text: tabItem.modelData
                                color: tabItem.selected ? Theme.primary : Theme.surfaceVariantText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabelLarge
                                font.weight: tabItem.selected ? Font.Medium : Font.Normal

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.durShort
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Theme.curveEmphasized
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tabTap

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tabIndex = tabItem.index
                        }

                        HoverHandler {
                            id: tabHover
                        }
                    }
                }

                // Hairline under the bar plus the sliding primary indicator.
                Rectangle {
                    width: parent.width
                    height: 1
                    anchors.bottom: parent.bottom
                    color: Theme.outlineVariant
                }

                Rectangle {
                    width: tabBar.cellWidth - 48
                    height: 3
                    x: root.tabIndex * tabBar.cellWidth + 24
                    anchors.bottom: parent.bottom
                    radius: Theme.shapeXS
                    color: Theme.primary

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.durPop
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveEmphasized
                        }
                    }
                }
            }

            // ---- pages ----------------------------------------------------------

            // Only the active page is reachable; the others sit at a 12 px
            // offset and fade out. The container clips so a shorter tab never
            // shows the tail of the previous one while the card resizes.
            Item {
                id: pages

                width: parent.width
                clip: true
                height: [pageLook, pageInterface, pageApps, pageSystem, pageCustom][root.tabIndex].implicitHeight

                SettingsPage {
                    id: pageLook

                    active: root.tabIndex === 0
                    pageIndex: 0

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

                        SettingSegment {
                            label: "Old"
                            selected: ShellState.styleMode === "old"
                            onClicked: ShellState.setStyleMode("old")
                        }

                        SettingSegment {
                            label: "Custom"
                            selected: ShellState.styleMode === "custom"
                            onClicked: ShellState.setStyleMode("custom")
                        }
                    }

                    // ---- bar position ---------------------------------------------------

                    SettingRow {
                        label: I18n.t("Расположение панели")

                        SettingSegment {
                            label: I18n.t("Сверху")
                            selected: ShellState.barPosition === "top"
                            onClicked: ShellState.setBarPosition("top")
                        }

                        SettingSegment {
                            label: I18n.t("Слева")
                            selected: ShellState.barPosition === "left"
                            onClicked: ShellState.setBarPosition("left")
                        }

                        SettingSegment {
                            label: I18n.t("Снизу")
                            selected: ShellState.barPosition === "bottom"
                            onClicked: ShellState.setBarPosition("bottom")
                        }

                        SettingSegment {
                            label: I18n.t("Справа")
                            selected: ShellState.barPosition === "right"
                            onClicked: ShellState.setBarPosition("right")
                        }
                    }

                    // ---- panel style ----------------------------------------------------

                    SettingRow {
                        label: I18n.t("Стиль панели")

                        SettingSegment {
                            label: I18n.t("Островки")
                            selected: ShellState.panelStyle === "islands"
                            onClicked: ShellState.setPanelStyle("islands")
                        }

                        SettingSegment {
                            label: I18n.t("Остров")
                            selected: ShellState.panelStyle === "island"
                            onClicked: ShellState.setPanelStyle("island")
                        }

                        SettingSegment {
                            label: I18n.t("Панель")
                            selected: ShellState.panelStyle === "panel"
                            onClicked: ShellState.setPanelStyle("panel")
                        }
                    }

                    // ---- plate width ----------------------------------------------------

                    // Only the single-plate layouts have a length to choose: the
                    // islands are three fixed plates. A side rail measures it
                    // along its height, a top/bottom bar along its width.
                    SettingRow {
                        id: plateWidthRow

                        readonly property bool rail: ShellState.barPosition === "left"
                            || ShellState.barPosition === "right"

                        label: rail ? I18n.t("Длина панели") : I18n.t("Ширина панели")
                        visible: ShellState.panelStyle !== "islands"

                        SettingSegment {
                            label: plateWidthRow.rail
                                ? I18n.t("Во всю длину") : I18n.t("Во всю ширину")
                            selected: ShellState.panelWidth === "full"
                            onClicked: ShellState.setPanelWidth("full")
                        }

                        SettingSegment {
                            label: I18n.t("По содержимому")
                            selected: ShellState.panelWidth === "fit"
                            onClicked: ShellState.setPanelWidth("fit")
                        }
                    }

                    // ---- blur source ----------------------------------------------------

                    // Only the blur styles have anything to blur, so the row is hidden
                    // under M3 Inspired, Nothing and Old: their surfaces are opaque and
                    // no window requests a background effect (the niri rule stays inert
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

                    // ---- motion ---------------------------------------------------------

                    // Two settings: the shell's own durations (style/Theme.qml)
                    // and the compositor's animations, which are written into the
                    // generated niri file.
                    SettingRow {
                        label: I18n.t("Анимации")

                        SettingSegment {
                            label: I18n.t("Выключены")
                            selected: ShellState.animationMode === "off"
                            onClicked: ShellState.setAnimationMode("off")
                        }

                        SettingSegment {
                            label: I18n.t("Обычные")
                            selected: ShellState.animationMode === "normal"
                            onClicked: ShellState.setAnimationMode("normal")
                        }

                        SettingSegment {
                            label: I18n.t("Медленные")
                            selected: ShellState.animationMode === "slow"
                            onClicked: ShellState.setAnimationMode("slow")
                        }
                    }

                    // Only reaches niri while the Niri target in the "Приложения"
                    // tab is on: it lives in that same generated file.
                    SettingRow {
                        label: I18n.t("Анимации niri")

                        SettingSegment {
                            label: I18n.t("Выключены")
                            selected: ShellState.niriAnimation === "off"
                            onClicked: ShellState.setNiriAnimation("off")
                        }

                        SettingSegment {
                            label: I18n.t("Обычные")
                            selected: ShellState.niriAnimation === "normal"
                            onClicked: ShellState.setNiriAnimation("normal")
                        }

                        SettingSegment {
                            label: I18n.t("Медленные")
                            selected: ShellState.niriAnimation === "slow"
                            onClicked: ShellState.setNiriAnimation("slow")
                        }
                    }

                    // ---- window rounding ------------------------------------------------

                    // niri window rule written into the generated file. The slider
                    // starts untouched (windows keep the user's own radius); the
                    // first drag takes over. Only reaches niri while the Niri target
                    // in "Приложения" is on.
                    SettingRow {
                        label: I18n.t("Скругление окон")

                        QsSlider {
                            id: radiusSlider

                            // Item width follows implicitWidth; the SettingRow
                            // layout skips zero-width children.
                            implicitWidth: 180

                            // Live while dragging, committed once: writing the adapter
                            // on every pixel would rewrite shell-state.json each move.
                            property real dragValue: -1
                            value: radiusSlider.dragValue >= 0
                                ? radiusSlider.dragValue
                                : (ShellState.windowRadius < 0 ? 10 : ShellState.windowRadius) / 24

                            onMoved: v => radiusSlider.dragValue = v
                            onCommitted: v => {
                                radiusSlider.dragValue = -1;
                                ShellState.setWindowRadius(Math.round(v * 24));
                            }
                        }

                        // Fixed-width box so the number's digits do not shift the
                        // slider mid-drag.
                        Item {
                            implicitWidth: 32
                            implicitHeight: 40

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(radiusSlider.value * 24)
                                color: Theme.surfaceText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabelLarge
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // ---- theme mode -----------------------------------------------------

                    SettingRow {
                        label: I18n.t("Тема")
                        // Custom has one palette for both modes: its surface
                        // decides the light system derivations, so a mode picker
                        // would lie.
                        visible: !Theme.custom

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
                        // The custom palette owns every role, so the scheme below
                        // would have nothing left to color.
                        visible: !Theme.custom

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

                        SettingSegment {
                            label: "Old"
                            selected: ShellState.fontMode === "old"
                            onClicked: ShellState.setFontMode("old")
                        }
                    }

                    // ---- ambient --------------------------------------------------------

                    SettingRow {
                        label: "Ambient"

                        SettingSegment {
                            label: I18n.t("Выключен")
                            selected: ShellState.ambient === "off"
                            onClicked: ShellState.setAmbient("off")
                        }

                        SettingSegment {
                            label: "X-mas"
                            selected: ShellState.ambient === "xmas"
                            onClicked: ShellState.setAmbient("xmas")
                        }
                    }

                }

                SettingsPage {
                    id: pageInterface

                    active: root.tabIndex === 1
                    pageIndex: 1

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

                    // ---- desktop pet ----------------------------------------------------

                    SettingRow {
                        label: I18n.t("Питомец")

                        SettingSegment {
                            label: I18n.t("Выключен")
                            selected: !ShellState.petEnabled
                            onClicked: ShellState.setPetEnabled(false)
                        }

                        SettingSegment {
                            label: I18n.t("Включён")
                            selected: ShellState.petEnabled
                            onClicked: ShellState.setPetEnabled(true)
                        }
                    }
                }

                SettingsPage {
                    id: pageApps

                    active: root.tabIndex === 2
                    pageIndex: 2

                    // ---- desktop color targets ------------------------------------------

                    // One group: which files services/SystemTheme.qml writes at all.
                    // A chip that is off leaves its file untouched, so the app keeps
                    // the colors it last got until it is switched back on.
                    SettingRow {
                        label: I18n.t("Цвета в приложениях")

                        SettingSegment {
                            label: "GTK"
                            selected: ShellState.themeAppEnabled("gtk")
                            onClicked: ShellState.setThemeApp("gtk", !selected)
                        }

                        SettingSegment {
                            label: "Qt"
                            selected: ShellState.themeAppEnabled("qt")
                            onClicked: ShellState.setThemeApp("qt", !selected)
                        }

                        SettingSegment {
                            label: "Ghostty"
                            selected: ShellState.themeAppEnabled("ghostty")
                            onClicked: ShellState.setThemeApp("ghostty", !selected)
                        }

                        SettingSegment {
                            label: "Niri"
                            selected: ShellState.themeAppEnabled("niri")
                            onClicked: ShellState.setThemeApp("niri", !selected)
                        }
                    }
                }

                SettingsPage {
                    id: pageSystem

                    active: root.tabIndex === 3
                    pageIndex: 3

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
                }

                // ---- custom style page ----------------------------------------------

                // The pack itself is one mode in the style row above; this page
                // owns its knobs and the one M3 palette. The controls stay usable
                // on other packs (they edit stored values), but the hint says the
                // shell only wears them as Custom.
                SettingsPage {
                    id: pageCustom

                    active: root.tabIndex === 4
                    pageIndex: 4

                    SettingRow {
                        label: I18n.t("Стиль")

                        SettingSegment {
                            label: "Custom"
                            selected: Theme.custom
                            onClicked: ShellState.setStyleMode("custom")
                        }
                    }

                    Text {
                        width: parent.width
                        visible: !Theme.custom
                        text: I18n.t("Настройки применяются в стиле Custom")
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBodySmall
                        wrapMode: Text.WordWrap
                    }

                    // The palette and the knobs do not fit one screen with the
                    // settings card, so this page scrolls inside a fixed viewport.
                    Flickable {
                        id: customScroll

                        width: parent.width
                        height: Math.min(customColumn.implicitHeight, Math.max(280, root.height - 300))
                        contentWidth: width
                        contentHeight: customColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: customColumn

                            width: customScroll.width
                            spacing: 16

                            // ---- shape ------------------------------------------

                            SettingRow {
                                label: I18n.t("Скругление")

                                IntSlider {
                                    id: shapeSlider

                                    minimum: 0
                                    maximum: 32
                                    current: ShellState.customRadius
                                    onChangedValue: value => ShellState.setCustomRadius(value)
                                }

                                Item {
                                    implicitWidth: 32
                                    implicitHeight: 40

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shapeSlider.shown
                                        color: Theme.surfaceText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabelLarge
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            SettingRow {
                                label: I18n.t("Радиус панели")

                                IntSlider {
                                    id: barSlider

                                    minimum: 0
                                    maximum: 24
                                    current: ShellState.customBarRadius
                                    onChangedValue: value => ShellState.setCustomBarRadius(value)
                                }

                                Item {
                                    implicitWidth: 32
                                    implicitHeight: 40

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barSlider.shown
                                        color: Theme.surfaceText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabelLarge
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            SettingRow {
                                label: I18n.t("Радиус чипов")

                                IntSlider {
                                    id: chipSlider

                                    minimum: 0
                                    maximum: 24
                                    current: ShellState.customChipRadius
                                    onChangedValue: value => ShellState.setCustomChipRadius(value)
                                }

                                Item {
                                    implicitWidth: 32
                                    implicitHeight: 40

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: chipSlider.shown
                                        color: Theme.surfaceText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabelLarge
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            // ---- dressing ---------------------------------------

                            SettingRow {
                                label: I18n.t("Акрил")

                                SettingSegment {
                                    label: I18n.t("Вкл")
                                    selected: ShellState.customAcrylic
                                    onClicked: ShellState.setCustomAcrylic(true)
                                }

                                SettingSegment {
                                    label: I18n.t("Выкл")
                                    selected: !ShellState.customAcrylic
                                    onClicked: ShellState.setCustomAcrylic(false)
                                }
                            }

                            SettingRow {
                                label: I18n.t("Прозрачность")
                                visible: ShellState.customAcrylic

                                IntSlider {
                                    id: opacitySlider

                                    minimum: 40
                                    maximum: 100
                                    current: ShellState.customOpacity
                                    onChangedValue: value => ShellState.setCustomOpacity(value)
                                }

                                Item {
                                    implicitWidth: 32
                                    implicitHeight: 40

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: opacitySlider.shown
                                        color: Theme.surfaceText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabelLarge
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            SettingRow {
                                label: I18n.t("Сила тени")

                                IntSlider {
                                    id: shadowSlider

                                    minimum: 0
                                    maximum: 100
                                    current: ShellState.customShadow
                                    onChangedValue: value => ShellState.setCustomShadow(value)
                                }

                                Item {
                                    implicitWidth: 32
                                    implicitHeight: 40

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shadowSlider.shown
                                        color: Theme.surfaceText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabelLarge
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            SettingRow {
                                label: I18n.t("Размытие тени")

                                IntSlider {
                                    id: shadowBlurSlider

                                    minimum: 0
                                    maximum: 64
                                    current: ShellState.customShadowBlur
                                    onChangedValue: value => ShellState.setCustomShadowBlur(value)
                                }

                                Item {
                                    implicitWidth: 32
                                    implicitHeight: 40

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shadowBlurSlider.shown
                                        color: Theme.surfaceText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabelLarge
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            SettingRow {
                                label: I18n.t("Смещение тени")

                                IntSlider {
                                    id: shadowOffsetSlider

                                    minimum: -16
                                    maximum: 16
                                    current: ShellState.customShadowOffset
                                    onChangedValue: value => ShellState.setCustomShadowOffset(value)
                                }

                                Item {
                                    implicitWidth: 32
                                    implicitHeight: 40

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shadowOffsetSlider.shown
                                        color: Theme.surfaceText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabelLarge
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            SettingRow {
                                label: I18n.t("Контур")

                                SettingSegment {
                                    label: I18n.t("Вкл")
                                    selected: ShellState.customBorder
                                    onClicked: ShellState.setCustomBorder(true)
                                }

                                SettingSegment {
                                    label: I18n.t("Выкл")
                                    selected: !ShellState.customBorder
                                    onClicked: ShellState.setCustomBorder(false)
                                }
                            }

                            SettingRow {
                                label: I18n.t("Бевелы")

                                SettingSegment {
                                    label: I18n.t("Вкл")
                                    selected: ShellState.customBevel
                                    onClicked: ShellState.setCustomBevel(true)
                                }

                                SettingSegment {
                                    label: I18n.t("Выкл")
                                    selected: !ShellState.customBevel
                                    onClicked: ShellState.setCustomBevel(false)
                                }
                            }

                            // ---- palette ----------------------------------------

                            Text {
                                width: parent.width
                                text: I18n.t("Палитра")
                                color: Theme.surfaceText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBodyLarge
                                font.weight: Font.Medium
                            }

                            Repeater {
                                model: [
                                    {
                                        "title": I18n.t("Акценты"),
                                        "roles": [
                                            "primary", "on_primary", "primary_container", "on_primary_container",
                                            "secondary", "on_secondary", "secondary_container", "on_secondary_container",
                                            "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
                                            "error", "on_error", "error_container", "on_error_container"
                                        ]
                                    },
                                    {
                                        "title": I18n.t("Поверхности"),
                                        "roles": [
                                            "surface", "on_surface", "surface_variant", "on_surface_variant",
                                            "surface_dim", "surface_bright", "surface_container_lowest",
                                            "surface_container_low", "surface_container", "surface_container_high",
                                            "surface_container_highest"
                                        ]
                                    },
                                    {
                                        "title": I18n.t("Контур и инверсия"),
                                        "roles": [
                                            "outline", "outline_variant", "inverse_surface", "inverse_on_surface",
                                            "inverse_primary", "scrim", "shadow", "surface_tint"
                                        ]
                                    },
                                    {
                                        "title": I18n.t("Фиксированные акценты"),
                                        "roles": [
                                            "primary_fixed", "primary_fixed_dim", "on_primary_fixed",
                                            "on_primary_fixed_variant", "secondary_fixed", "secondary_fixed_dim",
                                            "on_secondary_fixed", "on_secondary_fixed_variant", "tertiary_fixed",
                                            "tertiary_fixed_dim", "on_tertiary_fixed", "on_tertiary_fixed_variant"
                                        ]
                                    }
                                ]

                                delegate: Column {
                                    id: paletteGroup

                                    required property var modelData

                                    width: customColumn.width
                                    spacing: 8

                                    Text {
                                        text: paletteGroup.modelData.title
                                        color: Theme.surfaceVariantText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabelMedium
                                    }

                                    Grid {
                                        id: paletteGrid

                                        width: parent.width
                                        columns: 2
                                        columnSpacing: 8
                                        rowSpacing: 6

                                        Repeater {
                                            model: paletteGroup.modelData.roles

                                            delegate: Rectangle {
                                                id: roleRow

                                                required property string modelData

                                                width: (paletteGrid.width - paletteGrid.columnSpacing) / paletteGrid.columns
                                                height: 32
                                                radius: Theme.shapeSM
                                                color: roleHover.hovered ? Theme.surfaceContainerHighest : "transparent"
                                                border.width: Theme.hairlineWidth
                                                border.color: Theme.hairline

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Math.max(0, parent.width - 56)
                                                    text: roleRow.modelData.replace(/_/g, " ")
                                                    color: Theme.surfaceText
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeBodySmall
                                                    elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 32
                                                    height: 20
                                                    radius: Theme.shapeXS
                                                    color: Theme.customPalette[roleRow.modelData]
                                                    border.width: 1
                                                    border.color: Theme.outlineVariant
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.pickerRole = roleRow.modelData
                                                }

                                                HoverHandler {
                                                    id: roleHover
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            SettingRow {
                                label: I18n.t("Сброс")

                                SettingSegment {
                                    label: I18n.t("Палитру")
                                    onClicked: ShellState.resetCustomPalette()
                                }

                                SettingSegment {
                                    label: I18n.t("Всё")
                                    onClicked: ShellState.resetCustom()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Palette picker, dimmed card behind it. It only reports on "Готово",
        // so Cancel and a click on the scrim need no rollback.
        Rectangle {
            anchors.fill: parent
            z: 10
            color: Theme.scrim
            opacity: 0.35
            visible: root.pickerRole !== ""

            MouseArea {
                anchors.fill: parent
                onClicked: root.pickerRole = ""
            }
        }

        ColorPicker {
            anchors.centerIn: parent
            z: 11
            visible: root.pickerRole !== ""
            role: root.pickerRole
            initialColor: root.pickerRole !== "" ? Theme.customPalette[root.pickerRole] : "transparent"

            onAccepted: value => {
                ShellState.setCustomColor(root.pickerRole, value);
                root.pickerRole = "";
            }

            onResetRequested: {
                ShellState.resetCustomColor(root.pickerRole);
                root.pickerRole = "";
            }

            onCancelled: root.pickerRole = ""
        }
    }

    // One tab page. Pages sit on top of each other and slide 12 px against the
    // switch direction; invisible ones drop out of hit testing.
    component SettingsPage: Column {
        id: page

        property bool active: false
        property int pageIndex: 0

        width: pages.width
        spacing: 16
        x: page.active ? 0 : (page.pageIndex < root.tabIndex ? -12 : 12)
        opacity: page.active ? 1 : 0
        visible: page.opacity > 0.001

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durPop
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: Theme.durPop
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
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

        // A Flow packs every line from its left edge, so a wrapped last line
        // starts under the first segment instead of sitting flush right; this
        // breaks the same children into lines itself, spreads them evenly over
        // those lines and right-aligns each one.
        Item {
            id: options

            // Reruns the layout when a segment resizes (font, language) or a
            // row is hidden; the reads inside the binding are what Qt tracks.
            readonly property string layoutKey: {
                const sizes = [width];
                for (let i = 0; i < children.length; ++i) {
                    const child = children[i];
                    sizes.push(child.width, child.height, child.visible);
                }
                return sizes.join(":");
            }

            width: Math.max(0, row.width - rowLabel.width - 8)
            height: layoutHeight
            x: row.width - width
            anchors.verticalCenter: parent.verticalCenter

            property real layoutHeight: 0

            onLayoutKeyChanged: options.relayout()
            onChildrenChanged: Qt.callLater(options.relayout)

            function relayout(): void {
                const gap = 8;
                const items = [];
                for (let i = 0; i < children.length; ++i) {
                    const child = children[i];
                    if (child.visible && child.width > 0)
                        items.push(child);
                }
                const count = items.length;
                if (count === 0) {
                    options.layoutHeight = 0;
                    return;
                }

                const span = (a, b) => {
                    let w = gap * (b - a - 1);
                    for (let i = a; i < b; ++i)
                        w += items[i].width;
                    return w;
                };

                // Fewest lines the row can take, then keep that count and pick
                // the breaks with the least slack: 5 + 1 becomes 3 + 3.
                let lines = 1;
                let used = 0;
                for (let i = 0; i < count; ++i) {
                    if (used > 0 && used + gap + items[i].width > width) {
                        ++lines;
                        used = 0;
                    }
                    used += (used > 0 ? gap : 0) + items[i].width;
                }

                const cost = [];
                const start = [];
                for (let l = 0; l <= lines; ++l) {
                    cost.push(new Array(count + 1).fill(Infinity));
                    start.push(new Array(count + 1).fill(0));
                }
                cost[0][0] = 0;
                for (let l = 1; l <= lines; ++l) {
                    for (let j = 1; j <= count; ++j) {
                        for (let i = l - 1; i < j; ++i) {
                            if (cost[l - 1][i] === Infinity)
                                continue;
                            const w = span(i, j);
                            // Overflow just means this start is too early; a
                            // lone item wider than the block still takes a line.
                            if (w > width && j - i > 1)
                                continue;
                            const c = cost[l - 1][i] + (width - w) * (width - w);
                            if (c < cost[l][j]) {
                                cost[l][j] = c;
                                start[l][j] = i;
                            }
                        }
                    }
                }

                const breaks = [count];
                for (let l = lines, j = count; l > 0; --l) {
                    j = start[l][j];
                    breaks.unshift(j);
                }

                let y = 0;
                for (let l = 0; l < lines; ++l) {
                    const first = breaks[l];
                    const last = breaks[l + 1];
                    let total = 0;
                    let lineHeight = 0;
                    for (let i = first; i < last; ++i) {
                        total += items[i].width + (i > first ? gap : 0);
                        lineHeight = Math.max(lineHeight, items[i].height);
                    }
                    let x = width - total;
                    for (let i = first; i < last; ++i) {
                        items[i].x = x;
                        items[i].y = y;
                        x += items[i].width + gap;
                    }
                    y += lineHeight + gap;
                }
                options.layoutHeight = Math.max(0, y - gap);
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

        GlassEdge {
            visible: Theme.old
            sunken: seg.selected
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
