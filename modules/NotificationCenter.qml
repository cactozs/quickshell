pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// Notification center: the history (open and closed entries) in a card under
// the bar. Opened from the bell chip, Mod+N or `qs ipc call center toggle`;
// Esc or a click outside closes it. Opening marks everything seen.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.notificationScreen === root.modelData.name

    readonly property int cardWidth: 380
    readonly property int cardPadding: 16
    readonly property int rowPadding: 10
    readonly property int rowSpacing: 2
    readonly property int maxListHeight: Math.floor(root.height * 0.55)

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
    WlrLayershell.namespace: "quickshell:center"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Acrylic behind the card (New and Blur). Off as soon as it closes: a
    // compositor blur region cannot fade, so it would hang under the card.
    BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurRegion : null

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

    // What opening the center does. A lazily built window (LazyOverlay) is born
    // already open, so its onShownChanged never fires; both paths call this.
    function openInit(): void {
        Notifications.markAllSeen();
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

    // Arrivals while the center is open are seen immediately.
    Connections {
        target: Notifications

        function onHistoryChanged(): void {
            if (root.shown)
                Notifications.markAllSeen();
        }
    }

    // Layer surfaces take a moment to gain keyboard focus; make sure the key
    // catcher ends up active either way.
    Timer {
        id: focusKick
        interval: 50
        onTriggered: keyCatcher.forceActiveFocus()
    }

    // click outside the card dismisses the center
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeNotificationCenter()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                ShellState.closeNotificationCenter();
            event.accepted = true;
        }
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

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.barHeight + 2 * Theme.barMargin
        anchors.rightMargin: Theme.barMargin

        width: root.cardWidth
        height: column.implicitHeight + 2 * root.cardPadding
        radius: Theme.shapeXL
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        scale: root.shown ? 1 : 0.92
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

            spacing: 8

            // ---- header -----------------------------------------------------

            Item {
                width: parent.width
                implicitHeight: Theme.barHeight

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Уведомления")
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitleMedium
                    font.weight: Font.Medium
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconButton {
                        round: true
                        icon: Notifications.dnd ? Theme.iconNotificationsOff : Theme.iconNotifications
                        containerColor: Notifications.dnd ? Theme.primaryContainer : Theme.surfaceContainerHighest
                        contentColor: Notifications.dnd ? Theme.primaryContainerText : Theme.surfaceVariantText

                        onClicked: Notifications.toggleDnd()
                    }

                    IconButton {
                        round: true
                        icon: Theme.iconDeleteForever
                        containerColor: Theme.surfaceContainerHighest
                        contentColor: Theme.surfaceVariantText
                        opacity: Notifications.history.length > 0 ? 1 : 0.4

                        onClicked: Notifications.clearAll()
                    }

                    IconButton {
                        round: true
                        icon: Theme.iconClose
                        containerColor: Theme.surfaceContainerHighest
                        contentColor: Theme.surfaceVariantText

                        onClicked: ShellState.closeNotificationCenter()
                    }
                }
            }

            // ---- history ----------------------------------------------------

            Item {
                id: listArea

                width: parent.width
                // The delegates' real heights: history.length * rowHeight can
                // drift from the rows (font/style change, longer text) and the
                // card then clipped the last one.
                height: Notifications.history.length > 0
                    ? Math.min(list.contentHeight, root.maxListHeight)
                    : 72

                // Arrivals and dismissals resize the list; animate the height
                // so the card grows and shrinks smoothly.
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
                    visible: Notifications.history.length > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: root.rowSpacing
                    model: Notifications.history

                    delegate: HistoryRow {}
                }

                Text {
                    anchors.centerIn: parent
                    visible: Notifications.history.length === 0
                    text: I18n.t("Нет уведомлений")
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                }
            }
        }
    }

    // One history entry: icon, app + time, summary, body, dismiss. Entries
    // the app has already closed (entry.live === null) stay readable but
    // take no actions.
    component HistoryRow: Rectangle {
        id: row

        required property var modelData

        readonly property var entry: modelData
        readonly property bool actionable: entry.live !== null && Notifications.defaultAction(entry.live) !== null
        readonly property string iconSource: entry.image !== "" ? entry.image : entry.appIcon
        readonly property bool hovered: rowHover.hovered

        width: listArea.width
        height: textColumn.implicitHeight + 2 * root.rowPadding
        radius: Theme.shapeLG
        color: "transparent"

        StateLayer {
            hovered: row.hovered
            pressed: rowTap.pressed
            color: Theme.surfaceText
        }

        Rectangle {
            id: iconBox

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: Theme.shapeFull
            color: Theme.surfaceContainerHighest

            IconImage {
                anchors.fill: parent
                anchors.margins: 6
                source: row.iconSource
                visible: row.iconSource !== ""
            }

            Text {
                anchors.centerIn: parent
                visible: row.iconSource === ""
                text: Theme.iconNotifications
                color: Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSizeMedium
            }
        }

        Column {
            id: textColumn

            anchors.left: iconBox.right
            anchors.leftMargin: 12
            anchors.right: muteButton.visible ? muteButton.left : dismissButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: {
                    const time = Notifications.arrivalText(row.entry);
                    if (time === "")
                        return row.entry.appName;
                    return row.entry.appName === "" ? time : row.entry.appName + " · " + time;
                }
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: row.entry.summary
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitleMedium
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: row.entry.body
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            cursorShape: row.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Notifications.activate(row.entry)
        }

        MiniIconButton {
            id: muteButton

            anchors.right: dismissButton.left
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            visible: row.entry.appName !== ""
            icon: Notifications.isMuted(row.entry.appName)
                ? Theme.iconNotificationsOff
                : Theme.iconNotifications
            contentColor: Notifications.isMuted(row.entry.appName)
                ? Theme.primary
                : Theme.surfaceVariantText

            onClicked: Notifications.toggleMuteApp(row.entry.appName)

            Tip {
                target: muteButton
                text: I18n.t("Замьютить приложение")
                shown: muteButton.hovered
            }
        }

        MiniIconButton {
            id: dismissButton

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            icon: Theme.iconClose

            onClicked: Notifications.remove(row.entry)
        }

        HoverHandler {
            id: rowHover
        }
    }
}
