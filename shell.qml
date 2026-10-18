import Quickshell
import QtQuick
import "modules"
import "services"

ShellRoot {
    // Writes the palette onto GTK, Qt, ghostty and the niri border (singletons
    // are instantiated lazily, this is what pulls SystemTheme in).
    Component.onCompleted: SystemTheme.sync()

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens

        WallpaperDrop {}
    }

    // Every other overlay is built the first time it is opened and dropped again
    // once it has been closed for a while (LazyOverlay): a dormant window was
    // 2-4 MB each, an open-then-closed one left its scene behind as well.
    // LayoutBadge stays eager — it has no state to key on, only an event inside
    // itself (a keyboard layout switch).

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { QuickSettings {} }
            active: ShellState.quickSettingsScreen === modelData.name
        }
    }

    Variants {
        model: Quickshell.screens

        LayoutBadge {}
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { OsdBadge {} }
            active: Osd.shown
        }
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { Launcher {} }
            active: ShellState.launcherScreen === modelData.name
        }
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { ClipboardLauncher {} }
            active: ShellState.clipboardScreen === modelData.name
        }
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { NotificationToast {} }
            active: Notifications.popupScreen === modelData.name
                && Notifications.popups.length > 0
        }
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { NotificationCenter {} }
            active: ShellState.notificationScreen === modelData.name
        }
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { WeatherPopup {} }
            active: ShellState.weatherScreen === modelData.name
        }
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { SystemPopup {} }
            active: ShellState.systemScreen === modelData.name
        }
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { Settings {} }
            active: ShellState.settingsScreen === modelData.name
        }
    }

    Variants {
        model: Quickshell.screens

        LazyOverlay {
            source: Component { WallpaperManager {} }
            active: ShellState.wallpaperScreen === modelData.name
        }
    }
}
