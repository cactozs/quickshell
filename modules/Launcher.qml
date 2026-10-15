pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "../services"
import "../style"

// M3 Expressive application launcher (replaces `wofi --show drun`): a
// full-screen scrim plus a centered search card. Opened from the bar's
// launcher button; dismissed by Esc, by a click on the scrim, or by
// launching an app.
PanelWindow {
    id: root

    required property ShellScreen modelData

    // Apps with Terminal=true in their desktop entry run through this.
    readonly property var terminalCommand: ["alacritty", "-e"]

    // Geometry: card fixed-width while it fits, result list capped so the
    // card never covers the whole screen.
    readonly property int cardWidth: 560
    readonly property int cardPadding: 20
    readonly property int listMaxHeight: Math.floor(root.height * 0.5)
    readonly property int rowHeight: 52
    readonly property int rowSpacing: 2

    // ---- state -----------------------------------------------------------------

    readonly property var allEntries: DesktopEntries.applications.values
    readonly property string query: input.text
    property int currentIndex: 0

    // All entries alphabetically while the query is empty, otherwise scored
    // matches. Only the visible instance bothers computing anything.
    readonly property var results: {
        if (!root.visible)
            return [];

        const entries = root.allEntries;
        const q = root.query.toLowerCase().trim();
        if (q === "")
            return entries.slice().sort((a, b) => a.name.localeCompare(b.name));

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

        ShellState.closeLauncher();
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: root.terminalCommand.concat(entry.command),
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
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
    visible: ShellState.launcherScreen === root.modelData.name

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:launcher"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (root.visible) {
            input.text = "";
            root.currentIndex = 0;
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
                duration: Theme.durMedium
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
                    text: "Поиск приложений…"
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

                    onAccepted: root.activate(root.currentIndex)
                    onTextChanged: root.currentIndex = 0

                    Keys.onEscapePressed: ShellState.closeLauncher()
                    Keys.onUpPressed: root.moveFocus(-1)
                    Keys.onDownPressed: root.moveFocus(1)
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

            // ---- results --------------------------------------------------------

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
                    delegate: ResultItem {}

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain);
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
                    text: "↑↓ — выбор · Enter — запуск · Esc — закрыть"
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

        Item {
            id: iconBox

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.surfaceContainerHighest
                visible: iconImage.status !== Image.Ready

                Text {
                    anchors.centerIn: parent
                    text: (item.modelData.name || "?").charAt(0).toUpperCase()
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    font.weight: Font.Medium
                }
            }

            IconImage {
                id: iconImage

                anchors.fill: parent
                anchors.margins: 2
                source: item.modelData.icon !== "" ? Quickshell.iconPath(item.modelData.icon, "") : ""
            }
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
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
}
