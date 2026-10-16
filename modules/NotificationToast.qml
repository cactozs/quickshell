pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "../services"
import "../style"

// Toast stack for fresh notifications: right-aligned under the bar on the
// screen picked at arrival (Notifications.popupScreen). The window is sized
// to the Column, so everything around the cards is click-through.
PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.barHeight + 2 * Theme.barMargin
        right: Theme.barMargin
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Notifications.popupScreen === root.modelData.name && Notifications.popups.length > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: 360
    implicitHeight: column.implicitHeight

    Column {
        id: column

        width: parent.width
        spacing: 6

        Repeater {
            model: Notifications.popups

            delegate: Toast {}
        }
    }

    // One toast card. Hover pause/expiry live in the service
    // (Notifications.setPopupHover / popupExpiry), because the Repeater
    // rebuilds every card when the stack changes. Cards seen before skip the
    // entrance animation (Notifications.markAnimated) to avoid flicker.
    component Toast: Rectangle {
        id: toast

        required property var modelData

        readonly property Notification notification: modelData
        readonly property bool critical: notification.urgency === NotificationUrgency.Critical
        readonly property string iconSource: notification.image !== "" ? notification.image : notification.appIcon
        readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")

        width: column.width
        implicitHeight: layout.implicitHeight + 28
        height: implicitHeight
        radius: Theme.shapeLG
        color: Theme.surfaceContainerHigh

        opacity: 0

        transform: Translate {
            id: drift

            x: 24
        }

        Component.onCompleted: {
            if (Notifications.markAnimated(toast.notification))
                enterAnim.start();
            else {
                toast.opacity = 1;
                drift.x = 0;
            }
        }

        ParallelAnimation {
            id: enterAnim

            NumberAnimation {
                target: toast
                property: "opacity"
                to: 1
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }

            NumberAnimation {
                target: drift
                property: "x"
                to: 0
                duration: Theme.durMedium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        Connections {
            target: toast.notification

            function onClosed(): void {
                Notifications.removePopup(toast.notification);
            }
        }

        // Card click: default action when there is one, plain dismiss
        // otherwise. Buttons above draw over this area.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const action = Notifications.defaultAction(toast.notification);
                if (action)
                    action.invoke();
                else
                    toast.notification.dismiss();
            }
        }

        Column {
            id: layout

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 14
            }

            spacing: 8

            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    id: iconBox

                    width: 36
                    height: 36
                    radius: width / 2
                    color: Theme.surfaceContainerHighest

                    IconImage {
                        anchors.fill: parent
                        anchors.margins: 6
                        source: toast.iconSource
                        visible: toast.iconSource !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: toast.iconSource === ""
                        text: Theme.iconNotifications
                        color: toast.critical ? Theme.error : Theme.primary
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize
                    }
                }

                Column {
                    width: parent.width - iconBox.width - closeButton.width - 2 * 12
                    spacing: 2

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: toast.notification.appName
                        color: toast.critical ? Theme.error : Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelMedium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: toast.notification.summary
                        color: Theme.surfaceText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelLarge
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: toast.notification.body
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelMedium
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                MiniIconButton {
                    id: closeButton

                    icon: Theme.iconClose
                    onClicked: toast.notification.dismiss()
                }
            }

            Row {
                id: actionsRow

                visible: toast.buttons.length > 0
                height: visible ? implicitHeight : 0
                spacing: 4

                Repeater {
                    model: toast.buttons

                    delegate: ActionButton {
                        required property var modelData

                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
        }

        HoverHandler {
            id: cardHover

            onHoveredChanged: Notifications.setPopupHover(toast.notification, hovered)
        }
    }

    // M3 text button used for the notification's non-default actions.
    component ActionButton: Item {
        id: action

        property string text: ""
        readonly property bool hovered: actionHover.hovered
        readonly property bool pressed: actionTap.pressed

        signal clicked

        implicitWidth: label.implicitWidth + 24
        implicitHeight: 32

        Rectangle {
            anchors.fill: parent
            radius: Theme.shapeFull
            color: "transparent"

            StateLayer {
                hovered: action.hovered
                pressed: action.pressed
                color: Theme.primary
            }

            Text {
                id: label

                anchors.centerIn: parent
                text: action.text
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelLarge
                font.weight: Font.Medium
            }
        }

        HoverHandler {
            id: actionHover
        }

        MouseArea {
            id: actionTap

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }
}
