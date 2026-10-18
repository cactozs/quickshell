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

    Variants {
        model: Quickshell.screens

        QuickSettings {}
    }

    Variants {
        model: Quickshell.screens

        LayoutBadge {}
    }

    Variants {
        model: Quickshell.screens

        OsdBadge {}
    }

    Variants {
        model: Quickshell.screens

        Launcher {}
    }

    Variants {
        model: Quickshell.screens

        ClipboardLauncher {}
    }

    Variants {
        model: Quickshell.screens

        NotificationToast {}
    }

    Variants {
        model: Quickshell.screens

        NotificationCenter {}
    }

    Variants {
        model: Quickshell.screens

        WeatherPopup {}
    }

    Variants {
        model: Quickshell.screens

        SystemPopup {}
    }

    Variants {
        model: Quickshell.screens

        Settings {}
    }

    Variants {
        model: Quickshell.screens

        WallpaperManager {}
    }
}
