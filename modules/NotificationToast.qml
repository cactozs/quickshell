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

    // The stack grows out of the bar's corner, like the popup cards.
    anchors {
        top: !Theme.popupBottom
        bottom: Theme.popupBottom
        left: Theme.popupLeft
        right: !Theme.popupLeft
    }

    margins {
        top: Theme.popupTopMargin
        bottom: Theme.popupBottomMargin
        left: Theme.popupLeftMargin
        right: Theme.popupRightMargin
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // The service drops the last popup once the exit animation has played
    // (leaveTimer) and the surface follows; gating on column.implicitHeight
    // here would deadlock — an unmapped window is never polished, so the
    // positioner never measures its cards and the height stays 0.
    visible: Notifications.popupScreen === root.modelData.name
        && Notifications.popups.length > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Acrylic behind the toast stack (New style only). The cards slide in with
    // a translate; this stand-in doesn't, so the region stays on the final
    // rect. Sized off the column because a positioner's own height stays 0.
    Item {
        id: blurAnchor

        width: column.width
        height: column.implicitHeight
    }

    BackgroundEffect.blurRegion: Theme.blur ? blurRegion : null

    Region {
        id: blurRegion

        Region { item: blurAnchor; radius: Theme.shapeXL }
    }

    // The region only lands on the commit after the frame that set it; kick
    // repaints while the stack resizes so the blur can't trail behind it.
    BlurKick {
        id: blurKick

        region: blurRegion
    }

    Connections {
        target: blurAnchor

        function onWidthChanged(): void {
            blurKick.kick();
        }

        function onHeightChanged(): void {
            blurKick.kick();
        }
    }

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

        // Captured while the object is guaranteed alive; the stack hands this
        // to the service when the notification closes.
        readonly property int notifId: {
            try {
                return toast.notification.id;
            } catch (e) {
                return -1;
            }
        }

        // Display fields are snapshotted at creation: the server frees the
        // notification object once it closes (the history watcher drops the
        // last reference) while the card lives on to play its exit animation.
        property string appName: ""
        property string summary: ""
        property string body: ""
        property string iconSource: ""
        property bool critical: false
        property var buttons: []

        width: column.width
        implicitHeight: layout.implicitHeight + 32
        height: implicitHeight * collapse
        radius: Theme.shapeXL
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}
        clip: true

        // Exit-animation progress: 1 at rest, 0 once the card has collapsed.
        property real collapse: 1

        readonly property bool leaving: {
            try {
                return Notifications.leavingIds[toast.notification.id] === true;
            } catch (e) {
                // A freed object can only mean a card that is already exiting.
                return true;
            }
        }

        opacity: 0

        transform: Translate {
            id: drift

            x: 24
        }

        Component.onCompleted: {
            toast.snapContent();

            if (toast.leaving) {
                // Rebuilt mid-exit (the stack re-creates every card on each
                // change): skip straight to the collapsed state.
                toast.collapse = 0;
            } else if (Notifications.markAnimated(toast.notification)) {
                enterAnim.start();
            } else {
                toast.opacity = 1;
                toast.scale = 1;
                drift.x = 0;
            }
        }

        // Copy what the card shows while the object is still readable, so the
        // exit animation renders even after the server frees it.
        function snapContent(): void {
            try {
                const notif = toast.notification;
                toast.appName = notif.appName;
                toast.summary = notif.summary;
                toast.body = notif.body;
                toast.iconSource = Notifications.pickIcon(notif.image, notif.appIcon, notif.desktopEntry);
                toast.critical = notif.urgency === NotificationUrgency.Critical;
                toast.buttons = notif.actions.filter(a => a.identifier !== "default");
            } catch (e) {
                // Rebuilt after the object was freed: snapshots stay empty.
            }
        }

        onLeavingChanged: {
            if (toast.leaving) {
                enterAnim.stop();
                exitAnim.start();
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
                target: toast
                property: "scale"
                from: 0.95
                to: 1
                duration: Theme.durMedium
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
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

        // Exit: fade + collapse, so the cards below flow up instead of
        // jumping once the toast is dropped from the stack.
        ParallelAnimation {
            id: exitAnim

            NumberAnimation {
                target: toast
                property: "opacity"
                to: 0
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedAccelerate
            }

            NumberAnimation {
                target: toast
                property: "collapse"
                to: 0
                duration: Theme.durMedium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedAccelerate
            }

            NumberAnimation {
                target: drift
                property: "x"
                to: 24
                duration: Theme.durMedium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedAccelerate
            }
        }

        Connections {
            target: toast.notification

            function onClosed(): void {
                Notifications.removePopupById(toast.notifId);
            }
        }

        // Card click: default action when there is one, plain dismiss
        // otherwise. Buttons above draw over this area. Disabled while the
        // card is already on its way out.
        MouseArea {
            anchors.fill: parent
            enabled: !toast.leaving
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
                margins: 16
            }

            spacing: 8

            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    id: iconBox

                    width: 40
                    height: 40
                    radius: Theme.shapeFull
                    color: Theme.surfaceContainerHighest

                    IconImage {
                        id: iconImage

                        anchors.fill: parent
                        anchors.margins: 6
                        source: toast.iconSource
                        // Only a loaded image draws; a failed source would
                        // otherwise paint a broken frame over the glyph.
                        visible: toast.iconSource !== "" && status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !iconImage.visible
                        text: Theme.iconNotifications
                        color: toast.critical ? Theme.error : Theme.primary
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSizeMedium
                    }
                }

                Column {
                    width: parent.width - iconBox.width - closeButton.width - 2 * 12
                    spacing: 2

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: toast.appName
                        color: toast.critical ? Theme.error : Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelMedium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: toast.summary
                        color: Theme.surfaceText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitleMedium
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: toast.body
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

                    enabled: !toast.leaving
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

        implicitWidth: label.implicitWidth + 28
        implicitHeight: 40

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
