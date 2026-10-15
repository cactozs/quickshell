pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../services"
import "../style"

// Clipboard history launcher (cliphist): full-screen scrim plus a centered
// card, same visual language as the app launcher. Enter copies the selected
// entry back to the clipboard; Ctrl+P opens the actions menu (delete the
// selected entry or wipe the whole history).
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property int cardWidth: 560
    readonly property int cardPadding: 20
    readonly property int listMaxHeight: Math.floor(root.height * 0.5)
    readonly property int rowHeight: 48
    readonly property int rowSpacing: 2

    // ---- state -----------------------------------------------------------------

    // [{ id, line, preview, binary }], newest first (cliphist order).
    property var entries: []
    readonly property string query: input.text
    property int currentIndex: 0
    property bool menuOpen: false
    property int menuIndex: 0

    readonly property var results: {
        if (!root.visible)
            return [];

        const list = root.entries;
        const q = root.query.toLowerCase().trim();
        if (q === "")
            return list;

        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].preview.toLowerCase().indexOf(q) !== -1)
                out.push(list[i]);
        }
        return out;
    }

    // ---- cliphist ---------------------------------------------------------------

    function reload(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    function parseList(text: string): void {
        const out = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line === "")
                continue;

            const tab = line.indexOf("\t");
            if (tab <= 0)
                continue;

            const id = parseInt(line.slice(0, tab));
            if (isNaN(id))
                continue;

            // cliphist escapes newlines inside an entry as a literal "\n".
            const preview = line.slice(tab + 1).replace(/\\n/g, " ⏎ ");
            out.push({
                id: id,
                line: line,
                preview: preview,
                binary: preview.startsWith("[[ binary data")
            });
        }

        root.entries = out;
        root.clampIndex();
    }

    function clampIndex(): void {
        const count = root.results.length;
        root.currentIndex = count === 0 ? 0 : Math.max(0, Math.min(count - 1, root.currentIndex));
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseList(text)
        }
    }

    // cliphist modifies its database asynchronously; re-list a moment later.
    Timer {
        id: reloadDelay
        interval: 150
        onTriggered: root.reload()
    }

    // ---- actions ----------------------------------------------------------------

    function moveFocus(delta: int): void {
        const count = root.results.length;
        if (count === 0)
            return;
        root.currentIndex = Math.max(0, Math.min(count - 1, root.currentIndex + delta));
    }

    function copyEntry(index: int): void {
        const entry = root.results[index];
        if (!entry)
            return;

        ShellState.closeClipboard();
        // decode/delete take one `cliphist list` line on stdin; pass the line
        // as an argument so its text is never interpreted by the shell.
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$0\" | cliphist decode | wl-copy", entry.line]);
    }

    function deleteEntry(index: int): void {
        const entry = root.results[index];
        if (!entry)
            return;

        root.menuOpen = false;
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$0\" | cliphist delete", entry.line]);
        reloadDelay.restart();
    }

    function wipeHistory(): void {
        root.menuOpen = false;
        Quickshell.execDetached(["cliphist", "wipe"]);
        reloadDelay.restart();
    }

    function menuItemEnabled(index: int): bool {
        return index === 0 ? root.results.length > 0 : root.entries.length > 0;
    }

    function toggleMenu(): void {
        root.menuOpen = !root.menuOpen;
        if (root.menuOpen)
            root.menuIndex = root.menuItemEnabled(0) ? 0 : (root.menuItemEnabled(1) ? 1 : 0);
    }

    function menuMove(delta: int): void {
        for (let i = root.menuIndex + delta; i >= 0 && i <= 1; i += delta) {
            if (root.menuItemEnabled(i)) {
                root.menuIndex = i;
                return;
            }
        }
    }

    function activateMenu(): void {
        if (!root.menuItemEnabled(root.menuIndex))
            return;
        if (root.menuIndex === 0)
            root.deleteEntry(root.currentIndex);
        else
            root.wipeHistory();
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
    visible: ShellState.clipboardScreen === root.modelData.name

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:clipboard"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (root.visible) {
            input.text = "";
            root.currentIndex = 0;
            root.menuOpen = false;
            root.reload();
            focusKick.restart();
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
        opacity: root.visible ? 0.5 : 0

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

        onClicked: ShellState.closeClipboard()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width - 48)
        height: column.implicitHeight + 2 * root.cardPadding
        radius: Theme.shapeXL
        color: Theme.surfaceContainerHigh

        scale: root.visible ? 1 : 0.85
        opacity: root.visible ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
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

            // ---- search field ---------------------------------------------------

            Rectangle {
                id: searchBar

                width: parent.width
                implicitHeight: 48
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
                    font.pixelSize: Theme.iconSize

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
                    text: "Поиск в буфере обмена…"
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
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
                    font.pixelSize: Theme.fontSizeLabelLarge
                    selectByMouse: true
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText

                    focus: root.visible

                    onAccepted: {
                        if (root.menuOpen)
                            root.activateMenu();
                        else
                            root.copyEntry(root.currentIndex);
                    }

                    onTextChanged: root.currentIndex = 0

                    Keys.onEscapePressed: {
                        if (root.menuOpen)
                            root.menuOpen = false;
                        else
                            ShellState.closeClipboard();
                    }
                    Keys.onUpPressed: root.menuOpen ? root.menuMove(-1) : root.moveFocus(-1)
                    Keys.onDownPressed: root.menuOpen ? root.menuMove(1) : root.moveFocus(1)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                            root.toggleMenu();
                            event.accepted = true;
                        } else if (!root.menuOpen && event.key === Qt.Key_PageUp) {
                            root.moveFocus(-5);
                            event.accepted = true;
                        } else if (!root.menuOpen && event.key === Qt.Key_PageDown) {
                            root.moveFocus(5);
                            event.accepted = true;
                        } else if (!root.menuOpen && event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
                            root.moveFocus(1);
                            event.accepted = true;
                        } else if (root.menuOpen && event.text.length > 0
                                && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) {
                            // typing returns to the entry list; Enter is left
                            // to onAccepted so it activates the menu
                            root.menuOpen = false;
                        }
                    }
                }

                IconButton {
                    id: clearButton

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length > 0

                    round: true
                    icon: Theme.iconClose
                    hPadding: 9

                    onClicked: {
                        input.text = "";
                        input.forceActiveFocus();
                    }
                }
            }

            // ---- entries --------------------------------------------------------

            Item {
                id: resultsArea

                width: parent.width
                implicitHeight: root.results.length > 0
                    ? root.results.length * (root.rowHeight + root.rowSpacing) - root.rowSpacing
                    : 72
                height: Math.min(implicitHeight, root.listMaxHeight)

                ListView {
                    id: list

                    anchors.fill: parent
                    visible: root.results.length > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: root.rowSpacing
                    model: root.results
                    currentIndex: root.currentIndex
                    delegate: ClipItem {}

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: root.entries.length === 0 ? "Буфер обмена пуст" : "Ничего не найдено"
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                }

                // actions menu (Ctrl+P), floats above the entry list
                Rectangle {
                    id: menu

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 6
                    anchors.bottomMargin: 6

                    width: 240
                    height: menuColumn.implicitHeight + 12
                    radius: Theme.shapeMD
                    color: Theme.surfaceContainerHighest
                    transformOrigin: Item.BottomRight

                    visible: root.menuOpen
                    opacity: root.menuOpen ? 1 : 0
                    scale: root.menuOpen ? 1 : 0.9

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveEmphasizedDecelerate
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveEmphasizedDecelerate
                        }
                    }

                    Column {
                        id: menuColumn

                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        Repeater {
                            model: [
                                { label: "Удалить выбранную", icon: Theme.iconDelete, enabled: root.results.length > 0 },
                                { label: "Удалить всё", icon: Theme.iconDeleteForever, enabled: root.entries.length > 0 }
                            ]

                            delegate: MenuEntry {}
                        }
                    }
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
                    text: root.menuOpen
                        ? "↑↓ — выбор · Enter — применить · Esc — назад"
                        : "↑↓ — выбор · Enter — копировать · Ctrl+P — действия · Esc — закрыть"
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.query.length > 0
                    text: root.results.length + " из " + root.entries.length
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                }
            }
        }

    }

    // One clipboard entry; the icon distinguishes text from binary blobs.
    component ClipItem: Rectangle {
        id: item

        required property int index
        required property var modelData

        readonly property bool selected: root.currentIndex === item.index
        readonly property bool hovered: itemHover.hovered

        width: resultsArea.width
        height: root.rowHeight
        radius: Theme.shapeMD
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

        Rectangle {
            id: iconBox

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: width / 2
            color: Theme.surfaceContainerHighest

            Text {
                anchors.centerIn: parent
                text: item.modelData.binary ? Theme.iconImage : Theme.iconClipboard
                color: Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
            }
        }

        Text {
            anchors.left: iconBox.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: item.modelData.preview
            color: item.selected ? Theme.secondaryContainerText : Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            elide: Text.ElideRight
        }

        HoverHandler {
            id: itemHover

            onHoveredChanged: {
                // while the actions menu is open, hovering must not retarget
                // the selection that the menu actions refer to
                if (itemHover.hovered && !root.menuOpen)
                    root.currentIndex = item.index;
            }
        }

        MouseArea {
            id: itemTap

            anchors.fill: parent
            onClicked: {
                // a click outside of the open menu just dismisses it
                if (root.menuOpen)
                    root.menuOpen = false;
                else
                    root.copyEntry(item.index);
            }
        }
    }

    // One actions-menu row; destructive entries use the error palette.
    component MenuEntry: Rectangle {
        id: menuItem

        required property var modelData
        required property int index

        readonly property bool destructive: menuItem.index === 1
        readonly property bool highlighted: root.menuIndex === menuItem.index
        readonly property color fgColor: menuItem.highlighted && menuItem.modelData.enabled
            ? (menuItem.destructive ? Theme.errorContainerText : Theme.secondaryContainerText)
            : (menuItem.destructive && menuItem.modelData.enabled ? Theme.error : Theme.surfaceText)

        width: menuColumn.width
        height: 40
        radius: Theme.shapeSM
        color: menuItem.highlighted && menuItem.modelData.enabled
            ? (menuItem.destructive ? Theme.errorContainer : Theme.secondaryContainer)
            : "transparent"
        opacity: menuItem.modelData.enabled ? 1 : 0.45

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        StateLayer {
            hovered: menuHover.hovered && menuItem.modelData.enabled && !menuItem.highlighted
            pressed: menuTap.pressed
            color: menuItem.fgColor
        }

        Text {
            id: menuIcon

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: menuItem.modelData.icon
            color: menuItem.fgColor
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
        }

        Text {
            anchors.left: menuIcon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: menuItem.modelData.label
            color: menuItem.fgColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
        }

        HoverHandler {
            id: menuHover

            onHoveredChanged: {
                if (menuHover.hovered && menuItem.modelData.enabled)
                    root.menuIndex = menuItem.index;
            }
        }

        MouseArea {
            id: menuTap

            anchors.fill: parent
            enabled: menuItem.modelData.enabled
            onClicked: {
                root.menuIndex = menuItem.index;
                root.activateMenu();
            }
        }
    }
}
