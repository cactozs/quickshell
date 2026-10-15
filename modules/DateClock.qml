pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../style"

// Date with an M3 calendar glyph; the month calendar shows up in the tooltip.
Item {
    id: root

    implicitWidth: content.implicitWidth + 16
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    function calendarText(): string {
        const now = new Date();
        const y = now.getFullYear();
        const m = now.getMonth();
        const header = Qt.formatDateTime(now, "yyyy MMMM");
        const firstDow = new Date(y, m, 1).getDay();
        const days = new Date(y, m + 1, 0).getDate();

        const lines = ["Su Mo Tu We Th Fr Sa"];
        let line = "   ".repeat(firstDow);
        for (let d = 1; d <= days; d++) {
            line += String(d).padStart(2, " ") + " ";
            if ((firstDow + d) % 7 === 0) {
                lines.push(line);
                line = "";
            }
        }
        if (line.trim().length > 0) lines.push(line);

        return header + "\n\n" + lines.join("\n");
    }

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Theme.iconCalendar
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSizeSmall
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Qt.formatDateTime(clock.date, "ddd, dd MMM")
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            font.weight: Font.Medium
        }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) tip.text = root.calendarText();
            tip.visible = hovered;
        }
    }

    Tip {
        id: tip
        target: root
    }
}
