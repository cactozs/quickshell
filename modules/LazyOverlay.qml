pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// One overlay window per screen, built only when it is first opened and thrown
// away again after it has been closed for `idle` ms. A window that is never
// opened costs nothing at all (before this, 11 dormant overlays held ~27 MB of
// PSS); the price is that a re-open after `idle` rebuilds the window instead of
// replaying its entrance animation.
//
// Same contract as a plain `Variants { model: Quickshell.screens; Foo {} }`
// child: `modelData` is the screen and `source` instantiates the module.
QtObject {
    id: root

    required property ShellScreen modelData
    required property Component source
    // Open state for this screen, e.g. ShellState.launcherScreen === modelData.name.
    required property bool active
    // How long a closed overlay is kept alive; its exit animation is long over.
    property int idle: 20000

    property var window: null

    function ensure(): void {
        if (root.window === null)
            root.window = root.source.createObject(root, { modelData: root.modelData });
    }

    onActiveChanged: {
        if (root.active) {
            destroyTimer.stop();
            root.ensure();
        } else if (root.window !== null) {
            destroyTimer.restart();
        }
    }

    // The window can be born already open (ShellState flips before this runs);
    // the module handles that in its own Component.onCompleted.
    Component.onCompleted: {
        if (root.active)
            root.ensure();
    }

    // A named property, not a child: QtObject has no default property to put
    // children in.
    property Timer destroyTimer: Timer {
        id: destroyTimer

        interval: root.idle
        onTriggered: {
            if (root.window !== null) {
                root.window.destroy();
                root.window = null;
            }
        }
    }
}
