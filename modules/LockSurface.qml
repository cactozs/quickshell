pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../services"
import "../style"

// Lock screen content for one monitor: current wallpaper, a dim scrim and the
// password card. Every surface shares services/LockAuth.
Item {
    id: root

    required property string wallpaper

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Image {
        anchors.fill: parent
        source: root.wallpaper === "" ? "" : "file://" + root.wallpaper
        // A 6K source decodes to ~97 MB; bound it to the physical screen size.
        sourceSize.width: root.width * Screen.devicePixelRatio
        sourceSize.height: root.height * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: Theme.scrimOpacity
    }

    // Clicking anywhere puts the caret back into the field.
    MouseArea {
        anchors.fill: parent
        onClicked: password.forceActiveFocus()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        implicitHeight: content.implicitHeight + 64
        radius: Theme.shapeXXL
        color: Theme.popupSurface

        ColumnLayout {
            id: content

            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 10

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeDisplayLarge
                font.weight: Font.Light
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitleMedium
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                visible: Niri.currentLayout !== ""

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Theme.iconKeyboard
                    color: Theme.surfaceVariantText
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSize
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Niri.currentLayout.toUpperCase()
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    font.weight: Font.Medium
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                text: Quickshell.env("USER")
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitleLarge
                font.weight: Font.Medium
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.preferredHeight: 48
                radius: Theme.shapeFull
                color: Theme.surfaceContainerHighest
                border.width: password.activeFocus ? 2 : 0
                border.color: Theme.primary

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: password.text.length === 0
                    text: I18n.t("Введите пароль")
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                }

                TextInput {
                    id: password

                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    echoMode: TextInput.Password
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    // The singleton is the shared state; onTextEdited only fires
                    // on user input, so reset() clears the field without a loop.
                    text: LockAuth.password
                    onTextEdited: LockAuth.password = text
                    onAccepted: LockAuth.tryUnlock()
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                horizontalAlignment: Text.AlignHCenter
                visible: LockAuth.error !== ""
                text: LockAuth.error
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabelMedium
                wrapMode: Text.WordWrap
            }
        }
    }

    // The surface exists before the compositor maps it; give the field focus
    // once the window is actually there.
    Timer {
        interval: 50
        running: true
        onTriggered: password.forceActiveFocus()
    }
}
