pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// Transient on-screen display shared by the volume and brightness chips: the
// chip calls show(); every OsdBadge window renders it and fades out after a
// short delay. Icon is a Material Symbols codepoint.
Singleton {
    id: root

    readonly property int showDuration: 1200

    property string icon: ""
    property real value: 0
    property bool shown: false

    function show(icon: string, value: real): void {
        root.icon = icon;
        root.value = Math.max(0, Math.min(1, value));
        root.shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer

        interval: root.showDuration
        onTriggered: root.shown = false
    }
}
