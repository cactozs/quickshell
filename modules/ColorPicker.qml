pragma ComponentBehavior: Bound

import QtQuick
import "../services"
import "../style"
import "color.js" as Color

// HSV picker for the Custom palette. It only edits a local HSV value and
// reports it on "Готово": Settings writes the palette, so dragging the square
// never rewrites shell-state.json or the system theme files. Cancel, Esc and a
// click on the scrim all leave the palette untouched.
Item {
    id: root

    property string role: ""
    property color initialColor: "transparent"

    signal accepted(color value)
    signal resetRequested
    signal cancelled

    implicitWidth: 352
    implicitHeight: 340

    property real hue: 0
    property real saturation: 0
    property real brightness: 0

    function adopt(value: color): void {
        const hsv = Color.rgbToHsv(Math.round(value.r * 255), Math.round(value.g * 255), Math.round(value.b * 255));
        root.hue = hsv[0];
        root.saturation = hsv[1];
        root.brightness = hsv[2];
    }

    function currentHex(): string {
        return Color.hsvToHex(root.hue, root.saturation, root.brightness);
    }

    onInitialColorChanged: root.adopt(root.initialColor)
    Component.onCompleted: root.adopt(root.initialColor)

    Rectangle {
        anchors.fill: parent
        radius: Theme.shapeLG
        color: Theme.popupSurface
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Item {
                width: parent.width
                height: 32

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.role.replace(/_/g, " ")
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitleSmall
                    font.weight: Font.Medium
                }

                Text {
                    id: closeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Theme.iconClose
                    color: Theme.surfaceVariantText
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSize

                    StateLayer {
                        hovered: closeHover.hovered
                        pressed: closeTap.pressed
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: closeTap

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancelled()
                    }

                    HoverHandler {
                        id: closeHover
                    }
                }
            }

            // Saturation left→right over the hue, value top→bottom.
            Item {
                id: sv

                width: parent.width
                height: 150

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shapeSM
                    color: Qt.hsva(root.hue / 360, 1, 1, 1)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shapeSM

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shapeSM

                    gradient: Gradient {
                        orientation: Gradient.Vertical

                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 1) }
                    }
                }

                Item {
                    width: 20
                    height: 20
                    x: Math.max(0, Math.min(sv.width - width, root.saturation * sv.width - width / 2))
                    y: Math.max(0, Math.min(sv.height - height, (1 - root.brightness) * sv.height - height / 2))

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.5)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: 7
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(1, 1, 1, 1)
                    }
                }

                MouseArea {
                    id: svArea

                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    preventStealing: true

                    function apply(x: real, y: real): void {
                        root.saturation = Math.max(0, Math.min(1, x / sv.width));
                        root.brightness = 1 - Math.max(0, Math.min(1, y / sv.height));
                    }

                    onPressed: mouse => svArea.apply(mouse.x, mouse.y)
                    onPositionChanged: mouse => {
                        if (svArea.pressed)
                            svArea.apply(mouse.x, mouse.y);
                    }
                }
            }

            Item {
                id: hueBar

                width: parent.width
                height: 20

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shapeFull

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0 / 6; color: Qt.hsva(0, 1, 1, 1) }
                        GradientStop { position: 1 / 6; color: Qt.hsva(1 / 6, 1, 1, 1) }
                        GradientStop { position: 2 / 6; color: Qt.hsva(2 / 6, 1, 1, 1) }
                        GradientStop { position: 3 / 6; color: Qt.hsva(3 / 6, 1, 1, 1) }
                        GradientStop { position: 4 / 6; color: Qt.hsva(4 / 6, 1, 1, 1) }
                        GradientStop { position: 5 / 6; color: Qt.hsva(5 / 6, 1, 1, 1) }
                        GradientStop { position: 1.0; color: Qt.hsva(0, 1, 1, 1) }
                    }
                }

                Rectangle {
                    width: 6
                    height: 24
                    radius: 3
                    x: Math.max(0, Math.min(hueBar.width - width, root.hue / 360 * hueBar.width - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 1)
                }

                MouseArea {
                    id: hueArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    function apply(x: real): void {
                        root.hue = Math.max(0, Math.min(1, x / hueBar.width)) * 360;
                    }

                    onPressed: mouse => hueArea.apply(mouse.x)
                    onPositionChanged: mouse => {
                        if (hueArea.pressed)
                            hueArea.apply(mouse.x);
                    }
                }
            }

            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentHex()
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        implicitWidth: resetLabel.implicitWidth + 28
                        implicitHeight: 36
                        radius: Theme.glass ? Theme.shapeMD : Theme.shapeFull
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.outline

                        StateLayer {
                            hovered: resetHover.hovered
                            pressed: resetTap.pressed
                            color: Theme.surfaceText
                        }

                        Text {
                            id: resetLabel

                            anchors.centerIn: parent
                            text: I18n.t("Сброс")
                            color: Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelLarge
                        }

                        MouseArea {
                            id: resetTap

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetRequested()
                        }

                        HoverHandler {
                            id: resetHover
                        }
                    }

                    Rectangle {
                        implicitWidth: doneLabel.implicitWidth + 28
                        implicitHeight: 36
                        radius: Theme.glass ? Theme.shapeMD : Theme.shapeFull
                        color: Theme.primary

                        StateLayer {
                            hovered: doneHover.hovered
                            pressed: doneTap.pressed
                            color: Theme.primaryText
                        }

                        Text {
                            id: doneLabel

                            anchors.centerIn: parent
                            text: I18n.t("Готово")
                            color: Theme.primaryText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelLarge
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: doneTap

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.accepted(root.currentHex())
                        }

                        HoverHandler {
                            id: doneHover
                        }
                    }
                }
            }
        }
    }
}
