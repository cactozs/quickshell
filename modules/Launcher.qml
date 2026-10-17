pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// M3 Expressive application launcher (replaces `wofi --show drun`): a
// full-screen scrim plus a centered search card. Opened by a niri keybind
// through `qs ipc call launcher toggleOn <output>`; dismissed by Esc, by a
// click on the scrim, or by launching an app. With
// ShellState.launcherFullscreen the card fills the output and the results
// become a Launchpad-style icon grid.
PanelWindow {
    id: root

    required property ShellScreen modelData

    // `shown` is the semantic state; the window stays mapped while the close
    // fade plays out (see `visible` below), like LayoutBadge.
    readonly property bool shown: ShellState.launcherScreen === root.modelData.name

    // Apps with Terminal=true in their desktop entry run through this.
    readonly property var terminalCommand: ["alacritty", "-e"]

    readonly property bool fullscreen: ShellState.launcherFullscreen

    // Geometry: card fixed-width while it fits, result list capped so the
    // card never covers the whole screen -- `fullscreen` ignores both.
    readonly property int cardWidth: 560
    readonly property int cardPadding: 20
    readonly property int listMaxHeight: Math.floor(root.height * 0.5)
    readonly property int rowHeight: 56
    readonly property int rowSpacing: 2

    // Grid cell size and the ↓/↑ step (one item in the list, one grid row).
    readonly property int tileCellWidth: 148
    readonly property int tileCellHeight: 124
    readonly property int focusStep: root.fullscreen ? Math.max(1, Math.floor(grid.width / root.tileCellWidth)) : 1

    // ---- state -----------------------------------------------------------------

    readonly property var allEntries: DesktopEntries.applications.values
    readonly property string query: input.text
    property int currentIndex: 0

    // Most-launched first while the query is empty (favorites pinned on
    // top, alphabetical on ties), scored matches otherwise. Only the
    // visible instance bothers computing
    readonly property var results: {
        if (!root.visible)
            return [];

        const entries = root.allEntries;
        const q = root.query.toLowerCase().trim();
        if (q === "")
            // Hand-arranged apps first, in that order; the rest favorites
            // first, then most launched, alphabetical on ties.
            return entries.slice().sort((a, b) => {
                const ra = AppUsage.orderIndex(a);
                const rb = AppUsage.orderIndex(b);
                if (ra !== -1 || rb !== -1) {
                    if (ra === -1)
                        return 1;
                    if (rb === -1)
                        return -1;
                    return ra - rb;
                }
                return ((AppUsage.isFavorite(b) ? 1 : 0) - (AppUsage.isFavorite(a) ? 1 : 0)) || (AppUsage.launchCount(b) - AppUsage.launchCount(a)) || a.name.localeCompare(b.name);
            });

        const scored = [];
        for (let i = 0; i < entries.length; i++) {
            const score = root.scoreEntry(entries[i], q);
            if (score > 0)
                scored.push({ entry: entries[i], score: score });
        }
        scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return scored.map(match => match.entry);
    }

    // ---- matching ---------------------------------------------------------------

    // Match quality of query `q` (lowercase) inside lowercase `text`:
    // 0 = no match, higher is better. Exact > prefix > word start >
    // substring > subsequence.
    function matchQuality(text: string, q: string): int {
        if (q === "")
            return 1;
        if (text === q)
            return 100;
        if (text.startsWith(q))
            return 80;

        const at = text.indexOf(q);
        if (at > 0) {
            const prev = text.charAt(at - 1);
            if (" -_.,:;()[]/".indexOf(prev) !== -1)
                return 60;
            return 40;
        }

        // Subsequence: every query char must appear in order; tight runs win.
        let pos = 0;
        let gaps = 0;
        for (let i = 0; i < q.length; i++) {
            const found = text.indexOf(q.charAt(i), pos);
            if (found === -1)
                return 0;
            gaps += found - pos;
            pos = found + 1;
        }
        return Math.max(1, 20 - gaps);
    }

    // Weighted per-field score. Lower-weight fields require a stronger match
    // so a comment hit can't outrank a name hit.
    function fieldScore(text: string, q: string, weight: int, minQuality: int): int {
        const quality = root.matchQuality((text ?? "").toLowerCase(), q);
        return quality >= minQuality ? quality * weight : 0;
    }

    function scoreEntry(entry: DesktopEntry, q: string): int {
        let score = root.fieldScore(entry.name, q, 3, 1);
        score = Math.max(score, root.fieldScore(entry.genericName, q, 2, 20));
        score = Math.max(score, root.fieldScore(entry.id, q, 1, 40));
        score = Math.max(score, root.fieldScore(entry.comment, q, 1, 40));

        const keywords = entry.keywords;
        for (let i = 0; i < keywords.length; i++)
            score = Math.max(score, root.fieldScore(keywords[i], q, 2, 20));

        if (score > 0)
            score += Math.max(0, 20 - entry.name.length); // short names first
        if (score > 0 && AppUsage.isFavorite(entry))
            score += 1000; // favorites stay on top among matches
        return score;
    }

    // ---- actions ----------------------------------------------------------------

    function moveFocus(delta: int): void {
        const count = root.results.length;
        if (count === 0)
            return;
        root.currentIndex = Math.max(0, Math.min(count - 1, root.currentIndex + delta));
    }

    function activate(index: int): void {
        const entry = root.results[index];
        if (!entry)
            return;

        AppUsage.recordLaunch(entry);
        ShellState.closeLauncher();
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: root.terminalCommand.concat(entry.command),
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    function toggleFavorite(index: int): void {
        const entry = root.results[index];
        if (!entry)
            return;

        const key = AppUsage.launchKey(entry);
        AppUsage.toggleFavorite(entry);
        // Re-sorting moves the row; keep the selection on the same app.
        for (let i = 0; i < root.results.length; i++) {
            if (AppUsage.launchKey(root.results[i]) === key) {
                root.currentIndex = i;
                break;
            }
        }
    }

    // ---- hand-made grid order ---------------------------------------------------

    // Drag state: index of the tile under the pointer, -1 = none. Reordering is
    // the fullscreen grid's, and only while the query is empty.
    property int dragIndex: -1
    property int dropIndex: -1
    property point dragPos: Qt.point(0, 0)

    readonly property bool canArrange: root.fullscreen && root.query === "" && root.results.length > 1

    // Hit test: uniform cells, so the row/column come straight from the point.
    // `gridPoint` is in grid viewport coordinates, the ghost sits on the window
    // content item -- hence the mapping (root is a window, not an item).
    function trackDrag(gridPoint: point): void {
        root.dragPos = grid.mapToItem(dragGhost.parent, gridPoint.x, gridPoint.y);
        const col = Math.floor(gridPoint.x / root.tileCellWidth);
        const row = Math.floor((gridPoint.y + grid.contentY) / root.tileCellHeight);
        const index = row * root.focusStep + col;
        root.dropIndex = Math.max(0, Math.min(root.results.length - 1, index));
    }

    function resetDrag(): void {
        root.dragIndex = -1;
        root.dropIndex = -1;
    }

    // Drop: the dragged app takes the target's place and the rest shift. The
    // first drop freezes the whole visible order, so a moved app stays where it
    // was put instead of jumping back to the top of the derived sort.
    function moveTile(from: int, to: int): void {
        if (from < 0 || to < 0 || from === to) {
            root.resetDrag();
            return;
        }

        const keys = root.results.map(entry => AppUsage.launchKey(entry));
        keys.splice(to, 0, keys.splice(from, 1)[0]);
        AppUsage.setOrder(keys);
        root.currentIndex = to;
        root.resetDrag();
    }

    // ---- panel window -----------------------------------------------------------

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
    WlrLayershell.namespace: "quickshell:launcher"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Acrylic behind the search card (New style only). The fullscreen grid is
    // opaque, so it gets no blur region.
    BackgroundEffect.blurRegion: Theme.glass && !root.fullscreen ? blurRegion : null

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

    onShownChanged: {
        if (root.shown) {
            input.text = "";
            root.currentIndex = 0;
            focusKick.restart();
        } else {
            root.resetDrag();
        }
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

    // click outside the card dismisses the launcher
    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.closeLauncher()
    }

    // Ambient shadow under the card (New style only); the fullscreen grid
    // fills the output, so it stays shadowless.
    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: Theme.glass && !root.fullscreen
        opacity: card.opacity
        scale: card.scale
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: root.fullscreen ? root.width : Math.min(root.cardWidth, root.width - 48)
        height: root.fullscreen ? root.height : column.implicitHeight + 2 * root.cardPadding
        radius: root.fullscreen ? 0 : Theme.shapeXL
        // The fullscreen grid must stay opaque, so it skips the acrylic tone.
        color: root.fullscreen && Theme.glass ? Theme.surface : Theme.surfaceContainerHigh
        border.width: root.fullscreen ? 0 : Theme.hairlineWidth
        border.color: Theme.hairline

        // Inner 1px rim: the glass edge. No-op under m3 and on the fullscreen grid.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.width: Theme.hairlineWidth
            border.color: Theme.cardRim
            visible: !root.fullscreen
            z: 1
        }

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
        // dismiss area underneath. In fullscreen the card covers the screen,
        // so empty space around the tiles dismisses instead.
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.fullscreen)
                    ShellState.closeLauncher();
            }
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

            // ---- search field ---------------------------------------------------

            Rectangle {
                id: searchBar

                width: parent.width
                implicitHeight: 56
                height: implicitHeight
                radius: Theme.shapeFull
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
                    text: "Поиск приложений…"
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
                    onTextChanged: root.currentIndex = 0

                    Keys.onEscapePressed: ShellState.closeLauncher()
                    Keys.onUpPressed: root.moveFocus(-root.focusStep)
                    Keys.onDownPressed: root.moveFocus(root.focusStep)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageUp) {
                            root.moveFocus(-5);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown) {
                            root.moveFocus(5);
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
                            root.moveFocus(1);
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
                            root.moveFocus(-1);
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                            root.toggleFavorite(root.currentIndex);
                            event.accepted = true;
                        } else if (root.fullscreen && event.key === Qt.Key_Left) {
                            root.moveFocus(-1);
                            event.accepted = true;
                        } else if (root.fullscreen && event.key === Qt.Key_Right) {
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

            // ---- results --------------------------------------------------------

            Item {
                id: resultsArea

                width: parent.width
                implicitHeight: root.results.length > 0
                    ? root.results.length * (root.rowHeight + root.rowSpacing) - root.rowSpacing
                    : 72
                // Classic: capped list. Fullscreen: everything the card has
                // left below the search field and the footer.
                height: root.fullscreen
                    ? Math.max(0, root.height - 2 * root.cardPadding - searchBar.implicitHeight - footer.implicitHeight - 2 * column.spacing)
                    : Math.min(implicitHeight, root.listMaxHeight)

                // Re-scoring on each keystroke changes the row count; animate
                // the height so the card flows instead of jumping.
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasizedDecelerate
                    }
                }

                ListView {
                    id: list

                    anchors.fill: parent
                    visible: !root.fullscreen && root.results.length > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: root.rowSpacing
                    model: root.results
                    currentIndex: root.currentIndex
                    delegate: ResultItem {}

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    // Wheel moves the selection rather than scrolling, so
                    // Enter can never fire on an off-screen row.
                    WheelHandler {
                        onWheel: event => {
                            if (event.angleDelta.y === 0)
                                return;
                            root.moveFocus(event.angleDelta.y > 0 ? -1 : 1);
                            event.accepted = true;
                        }
                    }
                }

                // Fullscreen icon grid, Launchpad-style: icon over the name.
                // Scrolls natively; ↓/↑ move the selection a row, ←/→ a tile.
                GridView {
                    id: grid

                    anchors.fill: parent
                    visible: root.fullscreen && root.results.length > 0
                    clip: true
                    cellWidth: root.tileCellWidth
                    cellHeight: root.tileCellHeight
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.results
                    currentIndex: root.currentIndex
                    delegate: ResultTile {}

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, GridView.Contain);
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: "Ничего не найдено"
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
                    text: root.fullscreen
                        ? "↑↓←→ — выбор · Enter — запуск · тянуть иконку — порядок · Ctrl+F — в избранное · Esc — закрыть"
                        : "↑↓ — выбор · Enter — запуск · Ctrl+F — в избранное · Esc — закрыть"
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.query.length > 0
                    text: root.results.length + " из " + root.allEntries.length
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                }
            }
        }
    }

    // Follows the pointer while a tile is dragged. Sits outside the card so the
    // grid's clip can't cut it off, and takes no input of its own.
    Item {
        id: dragGhost

        readonly property var entry: root.dragIndex >= 0 ? root.results[root.dragIndex] : null

        visible: root.dragIndex >= 0
        z: 2
        width: 96
        height: 72 + 6 + ghostLabel.implicitHeight
        x: root.dragPos.x - width / 2
        y: root.dragPos.y - height / 2
        opacity: 0.95

        Rectangle {
            id: ghostPlate

            width: 96
            height: 72
            radius: Theme.shapeLGI
            color: Theme.secondaryContainer

            AppIcon {
                anchors.centerIn: parent
                entry: dragGhost.entry
                size: 56
            }
        }

        Text {
            id: ghostLabel

            anchors.top: ghostPlate.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: dragGhost.entry?.name ?? ""
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelMedium
            elide: Text.ElideRight
        }
    }

    // Application icon with the initial-letter fallback; the list row and the
    // grid tile both use it.
    component AppIcon: Item {
        id: iconBox

        required property DesktopEntry entry
        property int size: 40

        implicitWidth: size
        implicitHeight: size

        Rectangle {
            anchors.fill: parent
            radius: Theme.shapeFull
            color: Theme.surfaceContainerHighest
            visible: iconImage.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: (iconBox.entry?.name || "?").charAt(0).toUpperCase()
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(iconBox.size * 0.35)
                font.weight: Font.Medium
            }
        }

        IconImage {
            id: iconImage

            anchors.fill: parent
            anchors.margins: 2
            source: {
                const icon = iconBox.entry?.icon ?? "";
                return icon !== "" ? Quickshell.iconPath(icon, "") : "";
            }
        }
    }

    // One application row: icon (or initial fallback), name, description;
    // tonal container while selected, state layer on hover.
    component ResultItem: Rectangle {
        id: item

        required property int index
        required property DesktopEntry modelData

        readonly property bool selected: root.currentIndex === item.index
        readonly property bool hovered: itemHover.hovered

        width: resultsArea.width
        height: root.rowHeight
        radius: Theme.shapeLG
        color: item.selected ? Theme.secondaryContainer : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        StateLayer {
            hovered: item.hovered && !item.selected
            pressed: itemTap.pressed
            color: item.selected ? Theme.secondaryContainerText : Theme.surfaceText
        }

        AppIcon {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            entry: item.modelData
        }

        Column {
            anchors.left: rowIcon.right
            anchors.leftMargin: 12
            anchors.right: favStar.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: item.modelData.name || item.modelData.id
                color: item.selected ? Theme.secondaryContainerText : Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelLarge
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: item.modelData.comment || item.modelData.genericName
                color: item.selected ? Theme.secondaryContainerText : Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
                elide: Text.ElideRight
            }
        }

        Text {
            id: favStar

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: AppUsage.isFavorite(item.modelData)
            text: Theme.iconStar
            color: item.selected ? Theme.secondaryContainerText : Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSizeSmall
        }

        HoverHandler {
            id: itemHover

            onHoveredChanged: {
                if (itemHover.hovered)
                    root.currentIndex = item.index;
            }
        }

        MouseArea {
            id: itemTap

            anchors.fill: parent
            onClicked: root.activate(item.index)
        }
    }

    // One app in the fullscreen grid: icon plate with the name underneath.
    component ResultTile: Item {
        id: tile

        required property int index
        required property DesktopEntry modelData

        readonly property bool selected: root.currentIndex === tile.index
        readonly property bool hovered: tileHover.hovered
        readonly property bool dragging: root.dragIndex === tile.index
        readonly property bool dropTarget: root.dragIndex >= 0 && root.dropIndex === tile.index && !tile.dragging

        width: grid.cellWidth
        height: grid.cellHeight
        opacity: tile.dragging ? 0.3 : 1

        Rectangle {
            id: plate

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6
            width: 96
            height: 72
            radius: Theme.shapeLGI
            color: tile.selected ? Theme.secondaryContainer : "transparent"
            border.width: tile.dropTarget ? 2 : 0
            border.color: Theme.primary

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }

            StateLayer {
                hovered: tile.hovered && !tile.selected
                pressed: tileTap.pressed
                color: tile.selected ? Theme.secondaryContainerText : Theme.surfaceText
            }

            AppIcon {
                anchors.centerIn: parent
                entry: tile.modelData
                size: 56
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                visible: AppUsage.isFavorite(tile.modelData)
                text: Theme.iconStar
                color: Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSizeSmall
            }
        }

        Text {
            anchors.top: plate.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            text: tile.modelData.name || tile.modelData.id
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelMedium
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }

        HoverHandler {
            id: tileHover

            onHoveredChanged: {
                if (tileHover.hovered)
                    root.currentIndex = tile.index;
            }
        }

        MouseArea {
            id: tileTap

            anchors.fill: parent
            // Press-and-move rearranges; the grid must not steal the grab for
            // a flick (wheel and drags on empty space still scroll).
            preventStealing: true
            cursorShape: tileTap.dragActive ? Qt.DraggingHandCursor : Qt.PointingHandCursor

            property bool dragActive: false
            property bool dropped: false
            property point grabPoint

            onPressed: mouse => {
                tileTap.grabPoint = Qt.point(mouse.x, mouse.y);
            }

            onPositionChanged: mouse => {
                // Only a held button rearranges; a plain hover must not.
                if (!tileTap.pressed || !root.canArrange)
                    return;
                if (!tileTap.dragActive) {
                    if (Math.abs(mouse.x - tileTap.grabPoint.x) < 8 && Math.abs(mouse.y - tileTap.grabPoint.y) < 8)
                        return;
                    tileTap.dragActive = true;
                    root.dragIndex = tile.index;
                }
                root.trackDrag(tileTap.mapToItem(grid, mouse.x, mouse.y));
            }

            onReleased: {
                if (tileTap.dragActive) {
                    tileTap.dragActive = false;
                    tileTap.dropped = true;
                    root.moveTile(root.dragIndex, root.dropIndex);
                }
            }

            onCanceled: {
                if (tileTap.dragActive) {
                    tileTap.dragActive = false;
                    root.resetDrag();
                }
            }

            onClicked: {
                if (tileTap.dropped) {
                    tileTap.dropped = false;
                    return;
                }
                root.activate(tile.index);
            }
        }
    }
}
