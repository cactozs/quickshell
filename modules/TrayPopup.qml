pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// System tray popup: one full-screen overlay with a centered card listing the
// StatusNotifierItems. An item with a D-Bus menu swaps the card to that menu
// (QsMenuOpener, rendered in place); a nested entry pushes another level.
// Platform menus (QsMenuAnchor) cannot attach to a layer-shell surface, hence
// the manual renderer. Opened from the bar chip, `qs ipc call tray toggle`;
// Esc or a click outside closes it.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.trayScreen === root.modelData.name

    readonly property int cardWidth: 340
    readonly property int cardPadding: 16
    readonly property int rowHeight: 48
    readonly property int menuRowHeight: 40
    readonly property int rowSpacing: 2
    readonly property var items: SystemTray.items.values

    // Menu navigation: an empty stack shows the item list; the last entry is
    // the menu currently rendered.
    property var activeItem: null
    property var menuStack: []
    readonly property var activeMenu: root.menuStack.length > 0
        ? root.menuStack[root.menuStack.length - 1] : null
    readonly property var menuEntries: root.activeMenu !== null
        ? menuOpener.children.values : []

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: root.shown || card.opacity > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:tray"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Acrylic behind the card (New and Blur). Off as soon as it closes: a
    // compositor blur region cannot fade, so it would hang under the card.
    BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurRegion : null

    Item {
        id: blurAnchor
        anchors.fill: card
    }

    Region {
        id: blurRegion

        Region { item: blurAnchor; radius: card.radius }
    }

    // The region only lands on the commit after the frame that set it; kick
    // repaints while the card resizes so the blur can't trail behind it.
    BlurKick {
        id: blurKick

        region: blurRegion
    }

    BlurTarget { item: card; kicker: blurKick }

    QsMenuOpener {
        id: menuOpener

        menu: root.activeMenu
    }

    function openMenu(item: var): void {
        root.activeItem = item;
        root.menuStack = item !== null && item.hasMenu ? [item.menu] : [];
    }

    function pushMenu(entry: var): void {
        root.menuStack = [...root.menuStack, entry];
    }

    function back(): void {
        if (root.menuStack.length > 1)
            root.menuStack = root.menuStack.slice(0, -1);
        else
            root.openMenu(null);
    }

    // A lazily built window is born already open, so its onShownChanged never
    // fires; both paths call this.
    function openInit(): void {
        root.openMenu(null);
        focusKick.restart();
    }

    Component.onCompleted: {
        if (root.shown)
            root.openInit();
    }

    onShownChanged: {
        if (root.shown)
            root.openInit();
    }

    // An app can quit while its menu is open; drop the stale item.
    onItemsChanged: {
        if (root.activeItem !== null && !root.items.includes(root.activeItem))
            root.openMenu(null);
    }

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

        Behavior on opacity { Anim {} }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeTray()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                ShellState.closeTray();
            event.accepted = true;
        }
    }

    CardShadow { target: card }

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

        Behavior on scale { SpringAnim {} }

        Behavior on opacity { Anim {} }

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

            spacing: 8

            // ---- header -----------------------------------------------------

            Item {
                width: parent.width
                implicitHeight: Theme.barHeight

                IconButton {
                    anchors.left: parent.left
                    visible: root.activeItem !== null
                    round: true
                    icon: Theme.iconBack
                    containerColor: Theme.surfaceContainerHighest
                    contentColor: Theme.surfaceVariantText

                    onClicked: root.back()
                }

                Text {
                    anchors.left: root.activeItem !== null ? backSpacer.right : parent.left
                    anchors.leftMargin: 12
                    anchors.right: closeButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.activeItem !== null
                        ? (root.activeItem.title !== "" ? root.activeItem.title : root.activeItem.id)
                        : I18n.t("Трей")
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitleMedium
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Item {
                    id: backSpacer

                    width: 32
                    height: 1
                }

                IconButton {
                    id: closeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    round: true
                    icon: Theme.iconClose
                    containerColor: Theme.surfaceContainerHighest
                    contentColor: Theme.surfaceVariantText

                    onClicked: ShellState.closeTray()
                }
            }

            // ---- items or menu ----------------------------------------------

            Item {
                id: listArea

                width: parent.width
                height: root.activeItem !== null
                    ? (root.menuEntries.length > 0
                        ? Math.min(menuList.contentHeight, Math.floor(root.height * 0.5))
                        : 72)
                    : (root.items.length > 0
                        ? Math.min(itemList.contentHeight, Math.floor(root.height * 0.5))
                        : 72)

                Behavior on height { Anim { duration: Theme.durMedium } }

                ListView {
                    id: itemList

                    reuseItems: true

                    anchors.fill: parent
                    visible: root.activeItem === null && root.items.length > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: root.rowSpacing
                    model: root.items

                    delegate: TrayRow {}
                }

                ListView {
                    id: menuList

                    reuseItems: true

                    anchors.fill: parent
                    visible: root.activeItem !== null && root.menuEntries.length > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 1
                    model: root.menuEntries

                    delegate: TrayMenuEntry {}
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.activeItem !== null
                        ? root.menuEntries.length === 0
                        : root.items.length === 0
                    text: I18n.t("Нет приложений")
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                }
            }
        }
    }

    // One D-Bus menu entry, rendered in place: separator, check mark, icon,
    // text and a chevron for submenus.
    component TrayMenuEntry: Rectangle {
        id: menuRow

        required property var modelData
        required property int index

        readonly property var entry: menuRow.modelData
        readonly property bool hovered: menuHover.hovered
        readonly property bool actionable: !menuRow.entry.isSeparator && menuRow.entry.enabled

        width: listArea.width
        height: menuRow.entry.isSeparator ? 9 : root.menuRowHeight
        radius: Theme.shapeMD
        color: "transparent"

        StateLayer {
            hovered: menuRow.hovered && menuRow.actionable
            pressed: menuTap.pressed
            color: Theme.surfaceText
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: 1
            visible: menuRow.entry.isSeparator
            color: Theme.outline
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            visible: !menuRow.entry.isSeparator
                && menuRow.entry.checkState === Qt.Checked
            text: Theme.iconCheck
            color: Theme.surfaceText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSizeSmall
        }

        IconImage {
            id: entryIcon

            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            visible: !menuRow.entry.isSeparator && menuRow.entry.icon !== ""
            source: menuRow.entry.icon
        }

        Text {
            anchors.left: entryIcon.visible ? entryIcon.right : parent.left
            anchors.leftMargin: entryIcon.visible ? 8 : 34
            anchors.right: childIcon.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: !menuRow.entry.isSeparator
            text: menuRow.entry.text
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            elide: Text.ElideRight
            opacity: menuRow.entry.enabled ? 1 : Theme.disabledContent
        }

        Text {
            id: childIcon

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: !menuRow.entry.isSeparator && menuRow.entry.hasChildren
            text: Theme.iconChevronRight
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSizeSmall
        }

        MouseArea {
            id: menuTap

            anchors.fill: parent
            enabled: menuRow.actionable
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (menuRow.entry.hasChildren)
                    root.pushMenu(menuRow.entry);
                else {
                    menuRow.entry.triggered();
                    ShellState.closeTray();
                }
            }
        }

        HoverHandler {
            id: menuHover
        }
    }

    // One tray item: icon, title and a chevron when it exports a menu.
    component TrayRow: Rectangle {
        id: row

        required property var modelData
        required property int index

        readonly property var item: row.modelData
        readonly property bool hovered: rowHover.hovered

        width: listArea.width
        height: root.rowHeight
        radius: Theme.shapeLG
        color: "transparent"

        StateLayer {
            hovered: row.hovered
            pressed: rowTap.pressed
            color: Theme.surfaceText
        }

        IconImage {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            source: row.item.icon
        }

        Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: 12
            anchors.right: menuIcon.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.item.title !== "" ? row.item.title : row.item.id
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            elide: Text.ElideRight
        }

        Text {
            id: menuIcon

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: row.item.hasMenu
            text: Theme.iconChevronRight
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSizeSmall
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) {
                    row.item.secondaryActivate();
                    ShellState.closeTray();
                } else if (row.item.hasMenu) {
                    root.openMenu(row.item);
                } else {
                    row.item.activate();
                    ShellState.closeTray();
                }
            }

            onWheel: wheel => {
                const delta = wheel.angleDelta.y;
                if (delta !== 0)
                    row.item.scroll(delta > 0 ? 1 : -1, false);
            }
        }

        HoverHandler {
            id: rowHover
        }

    }

}
