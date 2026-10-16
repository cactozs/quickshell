pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// Bar chip: notification bell with an unread badge. Left click opens the
// notification center on this screen, middle click toggles do-not-disturb.
IconButton {
    id: root

    property string screenName: ""

    round: true
    icon: Notifications.dnd ? Theme.iconNotificationsOff : Theme.iconNotifications
    containerColor: Notifications.dnd ? Theme.primaryContainer : Theme.surfaceContainerHigh
    contentColor: Notifications.dnd ? Theme.primaryContainerText : Theme.surfaceText

    onClicked: button => {
        if (button === Qt.MiddleButton)
            Notifications.toggleDnd();
        else
            ShellState.toggleNotificationCenter(root.screenName);
    }

    Rectangle {
        id: badge

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2
        anchors.rightMargin: 2

        visible: Notifications.unreadCount > 0
        width: Math.max(16, badgeLabel.implicitWidth + 8)
        height: 16
        radius: height / 2
        color: Theme.error

        Text {
            id: badgeLabel

            anchors.centerIn: parent
            text: Notifications.unreadCount > 9 ? "9+" : String(Notifications.unreadCount)
            color: Theme.errorText
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }
}
