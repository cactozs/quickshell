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

        // Fades in/out with arrivals and seen marks; stays mapped while the
        // fade-out plays.
        visible: opacity > 0.001
        opacity: Notifications.unreadCount > 0 ? 1 : 0
        width: Math.max(16, badgeLabel.implicitWidth + 8)
        height: 16
        radius: Theme.shapeFull
        color: Theme.error

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        // Springy bump on every unread-count change, like the workspace pill.
        SequentialAnimation {
            id: pop

            NumberAnimation {
                target: badge
                property: "scale"
                to: 1.18
                duration: Theme.durPop
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }

            NumberAnimation {
                target: badge
                property: "scale"
                to: 1
                duration: Theme.durSettle
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        Connections {
            target: Notifications

            function onUnreadCountChanged(): void {
                if (Notifications.unreadCount > 0)
                    pop.restart();
            }
        }

        Text {
            id: badgeLabel

            anchors.centerIn: parent
            text: Notifications.unreadCount > 9 ? "9+" : String(Notifications.unreadCount)
            color: Theme.errorText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelSmall
            font.weight: Font.Medium
        }
    }
}
