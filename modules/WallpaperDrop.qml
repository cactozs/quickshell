import Quickshell
import Quickshell.Wayland

// Invisible full-screen surface on the background layer: the bare desktop
// (where the awww wallpaper shows through) is the one click-free place to
// drop an image, and it lives here. Toplevels stack above it, so it never
// takes input meant for windows.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:wallpaper-drop"

    WallpaperDropArea {
        anchors.fill: parent
    }
}
