pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"
import "../style"

// Focused niri window: app icon + title, muted until hovered.
Item {
    id: root

    required property int maxWidth

    property var win: Niri.focusedWindow
    property string appId: win?.app_id ?? ""
    property string title: win?.title ?? ""

    readonly property string iconName: {
        if (appId === "") return "";
        const entry = DesktopEntries.applications.values.find(e => e.appId === appId);
        return entry?.icon ?? appId;
    }

    height: Theme.barHeight
    implicitWidth: 8 + icon.width + (icon.visible ? 6 : 0) + titleText.implicitWidth + 4
    width: Math.min(implicitWidth, maxWidth)

    IconImage {
        id: icon

        x: 8
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Theme.iconSizeSmall
        source: root.iconName !== "" ? Quickshell.iconPath(root.iconName) : ""
        visible: source.toString() !== ""
    }

    Text {
        id: titleText

        x: 8 + (icon.visible ? icon.width + 6 : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - x - 4)
        text: root.title
        elide: Text.ElideRight
        color: hover.hovered ? Theme.surfaceText : Theme.surfaceVariantText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabelLarge
        font.weight: Font.Medium

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }
    }

    HoverHandler {
        id: hover
    }

    Tip {
        target: root
        text: root.title
        // Only when the title is actually cut off.
        visible: hover.hovered && titleText.truncated
    }
}
