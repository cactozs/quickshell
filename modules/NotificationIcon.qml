import Quickshell.Widgets
import QtQuick
import "../style"

// Notification app icon in a 40 px tonal circle; falls back to the bell glyph
// when the source is missing or fails to load.
Rectangle {
    id: root

    required property string source
    property color glyphColor: Theme.surfaceVariantText

    width: 40
    height: 40
    radius: Theme.shapeFull
    color: Theme.surfaceContainerHighest

    IconImage {
        id: iconImage

        anchors.fill: parent
        anchors.margins: 6
        source: root.source
        // A notification `image` can be a full-res screenshot; decode it at
        // the circle's size instead (2x for HiDPI).
        sourceSize.width: 56
        sourceSize.height: 56
        // Only a loaded image draws; a failed source would otherwise paint a
        // broken frame over the glyph.
        visible: root.source !== "" && status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: !iconImage.visible
        text: Theme.iconNotifications
        color: root.glyphColor
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSizeMedium
    }
}
