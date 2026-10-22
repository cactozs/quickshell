pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// Wallpaper manager: full-screen scrim plus a centered card with a grid of
// previews from ~/Pictures/Wallpapers, folder chips and a name search. Enter
// or a click applies the highlighted wallpaper through the awww shim (matugen
// recolors the whole shell) and closes; Ctrl+R / "Случайные" applies a random
// one and stays open. Opened by Mod+L (niri) or the "Обои" button in the
// settings menu.
PanelWindow {
    id: root

    required property ShellScreen modelData

    // `shown` is the semantic state; the window stays mapped while the close
    // fade plays out (see `visible` below), like the clipboard launcher.
    readonly property bool shown: ShellState.wallpaperScreen === root.modelData.name

    readonly property int cardWidth: 880
    readonly property int cardPadding: 20
    readonly property int cardHeight: Math.min(root.height - 96, 700)

    // Tile geometry; four preview columns fill the card exactly.
    readonly property int tileCellWidth: 210
    readonly property int tileCellHeight: 150
    // ↓/↑ move the selection a row.
    readonly property int focusStep: Math.max(1, Math.floor(grid.width / root.tileCellWidth))

    // ---- state -----------------------------------------------------------------

    readonly property string query: input.text
    // "" = every folder; starOnly shows the favorites instead.
    property string folderFilter: ""
    property bool starOnly: false
    property int currentIndex: 0
    // Current wallpaper from `awww query` ("currently displaying: image: <path>").
    property string currentPath: ""
    // Jump to the current wallpaper once entries and currentPath have arrived;
    // any navigation cancels the jump.
    property bool autoScroll: true

    readonly property var folders: {
        const out = [];
        const entries = Wallpapers.entries;
        for (let i = 0; i < entries.length; i++) {
            if (out.indexOf(entries[i].folder) === -1)
                out.push(entries[i].folder);
        }
        return out;
    }

    readonly property var chipModel: {
        const chips = [
            { label: I18n.t("Все"), folder: "", star: false },
            { label: "★", folder: "", star: true }
        ];
        const list = root.folders;
        for (let i = 0; i < list.length; i++)
            chips.push({ label: list[i], folder: list[i], star: false });
        return chips;
    }

    readonly property var results: {
        // slice(): the sort below must not reorder the shared Wallpapers.entries.
        let list = Wallpapers.entries.slice();
        if (root.starOnly)
            list = list.filter(entry => Wallpapers.isFavorite(entry.path));
        else if (root.folderFilter !== "")
            list = list.filter(entry => entry.folder === root.folderFilter);

        const q = root.query.toLowerCase().trim();
        if (q !== "")
            list = list.filter(entry => entry.name.toLowerCase().indexOf(q) !== -1
                || entry.folder.toLowerCase().indexOf(q) !== -1);

        // Favorites pinned first; stable sort keeps the folder/name order.
        if (!root.starOnly)
            list.sort((a, b) => (Wallpapers.isFavorite(b.path) ? 1 : 0)
                - (Wallpapers.isFavorite(a.path) ? 1 : 0));
        return list;
    }

    onResultsChanged: root.tryScrollToCurrent()

    onCurrentPathChanged: {
        if (root.shown)
            root.tryScrollToCurrent();
    }

    // ---- actions ----------------------------------------------------------------

    function clampIndex(): void {
        const count = root.results.length;
        root.currentIndex = count === 0 ? 0 : Math.max(0, Math.min(count - 1, root.currentIndex));
    }

    function moveFocus(delta: int): void {
        const count = root.results.length;
        if (count === 0)
            return;
        root.autoScroll = false;
        root.currentIndex = Math.max(0, Math.min(count - 1, root.currentIndex + delta));
    }

    function activate(index: int): void {
        const entry = root.results[index];
        if (!entry)
            return;

        root.currentPath = entry.path;
        Wallpapers.apply(entry.path);
        ShellState.closeWallpaper();
    }

    function applyRandom(): void {
        const path = Wallpapers.randomPath();
        if (path === "")
            return;

        root.currentPath = path;
        root.autoScroll = false;
        Wallpapers.apply(path);
    }

    function toggleFavorite(index: int): void {
        const entry = root.results[index];
        if (!entry)
            return;

        Wallpapers.toggleFavorite(entry.path);
        // Filtering may drop the row; keep the selection on the same file.
        for (let i = 0; i < root.results.length; i++) {
            if (root.results[i].path === entry.path) {
                root.currentIndex = i;
                break;
            }
        }
        root.clampIndex();
    }

    function selectChip(chip: var): void {
        root.starOnly = chip.star;
        root.folderFilter = chip.folder;
        root.currentIndex = 0;
        root.autoScroll = false;
    }

    // Hop to the current wallpaper in the grid, once.
    function tryScrollToCurrent(): void {
        if (!root.autoScroll || root.currentPath === "")
            return;

        for (let i = 0; i < root.results.length; i++) {
            if (root.results[i].path === root.currentPath) {
                root.currentIndex = i;
                grid.positionViewAtIndex(i, GridView.Contain);
                root.autoScroll = false;
                return;
            }
        }
    }

    function queryCurrent(): void {
        if (!queryProc.running)
            queryProc.running = true;
    }

    function parseCurrent(text: string): void {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const at = lines[i].indexOf("image: ");
            if (at !== -1) {
                root.currentPath = lines[i].slice(at + 7).trim();
                return;
            }
        }
    }

    Process {
        id: queryProc

        command: ["awww", "query"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseCurrent(text)
        }
    }

    // ---- panel window -----------------------------------------------------------

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
    WlrLayershell.namespace: "quickshell:wallpaper"
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

    // What opening the manager does. A lazily built window (LazyOverlay) is
    // born already open, so its onShownChanged never fires; both paths call this.
    function openInit(): void {
        input.text = "";
        root.folderFilter = "";
        root.starOnly = false;
        root.currentIndex = 0;
        root.autoScroll = true;
        chipsRow.contentX = 0;
        Wallpapers.reload();
        root.queryCurrent();
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

    // Layer surfaces take a moment to gain keyboard focus; make sure the
    // search field ends up active either way.
    Timer {
        id: focusKick
        interval: 50
        onTriggered: input.forceActiveFocus()
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

    // click outside the card dismisses the manager
    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.closeWallpaper()
    }

    // Ambient shadow under the card (New style only); follows the card's
    // entrance fade/scale.
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
        height: root.cardHeight
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

        // Swallow clicks on the card background so they don't reach the
        // dismiss area underneath.
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

            spacing: 12

            // ---- header ---------------------------------------------------------

            Item {
                id: titleRow

                width: parent.width
                height: Math.max(title.implicitHeight, randomButton.implicitHeight)

                Text {
                    id: title

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Обои")
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitleLarge
                    font.weight: Font.Medium
                }

                IconButton {
                    id: randomButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    icon: Theme.iconShuffle
                    label: I18n.t("Случайные")
                    containerColor: Theme.secondaryContainer
                    contentColor: Theme.secondaryContainerText

                    onClicked: root.applyRandom()
                }
            }

            // ---- folder chips ---------------------------------------------------

            ListView {
                id: chipsRow

                width: parent.width
                height: Theme.chipHeight
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.chipModel
                delegate: Chip {}
            }

            // ---- search field ---------------------------------------------------

            Rectangle {
                id: searchBar

                width: parent.width
                implicitHeight: 56
                height: implicitHeight
                // Nothing keeps the field rectangular instead of the M3 pill.
                radius: Theme.nothing ? Theme.shapeMD : Theme.shapeFull
                color: Theme.surfaceContainerHighest

                Text {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.iconSearch
                    color: input.activeFocus ? Theme.primary : Theme.surfaceVariantText
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSizeMedium

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveEmphasized
                        }
                    }
                }

                Text {
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: clearButton.visible ? clearButton.left : parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Поиск обоев…")
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitleMedium
                    elide: Text.ElideRight
                    visible: input.text.length === 0
                }

                TextInput {
                    id: input

                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: clearButton.visible ? clearButton.left : parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitleMedium
                    selectByMouse: true
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText

                    focus: root.shown

                    onAccepted: root.activate(root.currentIndex)

                    onTextChanged: {
                        root.currentIndex = 0;
                        root.autoScroll = false;
                    }

                    Keys.onEscapePressed: ShellState.closeWallpaper()
                    Keys.onUpPressed: root.moveFocus(-root.focusStep)
                    Keys.onDownPressed: root.moveFocus(root.focusStep)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageUp) {
                            root.moveFocus(-5);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown) {
                            root.moveFocus(5);
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_R) {
                            root.applyRandom();
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                            root.toggleFavorite(root.currentIndex);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left) {
                            root.moveFocus(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            root.moveFocus(1);
                            event.accepted = true;
                        }
                    }
                }

                IconButton {
                    id: clearButton

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length > 0

                    round: true
                    icon: Theme.iconClose

                    onClicked: {
                        input.text = "";
                        input.forceActiveFocus();
                    }
                }
            }

            // ---- preview grid ---------------------------------------------------

            Item {
                id: gridArea

                width: parent.width
                height: root.cardHeight - 2 * root.cardPadding
                    - titleRow.height - chipsRow.height - searchBar.implicitHeight - footer.implicitHeight
                    - 4 * column.spacing

                GridView {
                    id: grid

                    anchors.fill: parent
                    visible: root.results.length > 0
                    clip: true
                    cellWidth: root.tileCellWidth
                    cellHeight: root.tileCellHeight
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.results
                    currentIndex: root.currentIndex
                    delegate: WallpaperTile {}

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, GridView.Contain);
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: Wallpapers.entries.length === 0
                        ? I18n.t("В ~/Pictures/Wallpapers нет изображений")
                        : I18n.t("Ничего не найдено")
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                }
            }

            // ---- footer ---------------------------------------------------------

            Item {
                id: footer

                width: parent.width
                implicitHeight: hint.implicitHeight

                Text {
                    id: hint

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("↑↓←→ — выбор · Enter — применить · Ctrl+F — в избранное · Ctrl+R — случайные · Esc — закрыть")
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                }
            }
        }
    }

    // One wallpaper in the grid: preview with the file name underneath; the
    // current wallpaper keeps a primary border, favorites a star badge.
    component WallpaperTile: Item {
        id: tile

        required property int index
        required property var modelData

        readonly property bool selected: root.currentIndex === tile.index
        readonly property bool hovered: tileHover.hovered
        readonly property bool favorite: Wallpapers.isFavorite(tile.modelData.path)
        readonly property bool isCurrent: root.currentPath === tile.modelData.path

        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
            id: plate

            x: 6
            y: 6
            width: parent.width - 12
            height: 112
            radius: Theme.shapeLG
            color: Theme.surfaceContainerHighest
            border.width: tile.isCurrent ? 3 : Theme.hairlineWidth
            border.color: tile.isCurrent ? Theme.primary : Theme.hairline
            clip: true

            Image {
                anchors.fill: parent
                // 720px preview from the cache (Wallpapers.thumbs), the original
                // until one exists. sourceSize keeps it crisp at 2x the plate.
                source: "file://" + Wallpapers.thumbFor(tile.modelData.path)
                sourceSize.width: 2 * plate.width
                sourceSize.height: 2 * plate.height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            StateLayer {
                hovered: tile.hovered && !tile.selected
                pressed: tileTap.pressed
                color: Theme.surfaceText
            }
        }

        MouseArea {
            id: tileTap

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate(tile.index)
        }

        // Backdrop keeps the star readable on any image; unfavorited stars
        // only appear while the tile is hovered.
        Rectangle {
            id: starBadge

            anchors.right: plate.right
            anchors.top: plate.top
            anchors.margins: 10
            width: 28
            height: 28
            radius: Theme.shapeFull
            color: Theme.surface
            opacity: 0.9
            visible: tile.favorite || tile.hovered

            Text {
                anchors.centerIn: parent
                text: Theme.iconStar
                color: tile.favorite ? Theme.primary : Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleFavorite(tile.index)
            }
        }

        Rectangle {
            id: label

            anchors.top: plate.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(labelText.implicitWidth + 16, tile.width - 12)
            height: 22
            radius: Theme.shapeFull
            color: tile.selected ? Theme.secondaryContainer : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }

            Text {
                id: labelText

                anchors.centerIn: parent
                width: Math.min(implicitWidth, tile.width - 28)
                horizontalAlignment: Text.AlignHCenter
                text: tile.modelData.name
                color: tile.selected ? Theme.secondaryContainerText : Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
                elide: Text.ElideMiddle
            }
        }

        HoverHandler {
            id: tileHover

            onHoveredChanged: {
                if (tileHover.hovered) {
                    root.currentIndex = tile.index;
                    root.autoScroll = false;
                }
            }
        }
    }

    // One filter chip: "Все", the favorites or a wallpaper folder.
    component Chip: Rectangle {
        id: chip

        required property var modelData

        readonly property bool selected: chip.modelData.star
            ? root.starOnly
            : (!root.starOnly && root.folderFilter === chip.modelData.folder)

        width: chipLabel.implicitWidth + 24
        height: Theme.chipHeight
        radius: Theme.shapeFull
        color: chip.selected ? Theme.secondaryContainer : "transparent"
        border.width: chip.selected ? 0 : 1
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        StateLayer {
            hovered: chipHover.hovered
            pressed: chipTap.pressed
            color: chip.selected ? Theme.secondaryContainerText : Theme.surfaceText
        }

        Text {
            id: chipLabel

            anchors.centerIn: parent
            text: chip.modelData.label
            color: chip.selected ? Theme.secondaryContainerText : Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelMedium
            font.weight: chip.selected ? Font.Medium : Font.Normal

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }
        }

        HoverHandler {
            id: chipHover
        }

        MouseArea {
            id: chipTap

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.selectChip(chip.modelData)
        }
    }
}
