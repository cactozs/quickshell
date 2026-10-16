pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
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
    readonly property int cardPadding: 12
    readonly property int rowHeight: 62
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

    onShownChanged: {
        if (root.shown) {
            Notifications.markAllSeen();
            focusKick.restart();
        }
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

        scale: root.shown ? 1 : 0.95
        opacity: root.shown ? 1 : 0

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
                implicitHeight: Theme.iconButtonSize

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Уведомления"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
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
                implicitHeight: Notifications.history.length > 0
                    ? Notifications.history.length * (root.rowHeight + root.rowSpacing) - root.rowSpacing
                    : 72
                height: Math.min(implicitHeight, root.maxListHeight)

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
                    text: "Нет уведомлений"
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
        height: root.rowHeight
        radius: Theme.shapeMD
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
            width: 36
            height: 36
            radius: width / 2
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
                font.pixelSize: Theme.iconSize
            }
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 12
            anchors.right: dismissButton.left
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
            }

            Text {
                width: parent.width
                text: row.entry.summary
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelLarge
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: row.entry.body
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            cursorShape: row.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Notifications.activate(row.entry)
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
