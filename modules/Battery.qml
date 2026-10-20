pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import "../services"
import "../style"

// UPower chip: errorContainer fill when critically low, charging glyph and
// primary tint while plugged in.
IconButton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool isBattery: device !== null && device.type === UPowerDeviceType.Battery
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property int state: device?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool plugged: state === UPowerDeviceState.PendingCharge
    readonly property bool critical: percent <= 15 && !charging

    function formatTime(secs: real): string {
        if (!isFinite(secs) || secs <= 0) return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h + ":" + String(m).padStart(2, "0");
    }

    readonly property string remaining: formatTime(
        charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0))

    visible: root.isBattery

    icon: {
        if (root.charging || root.plugged) return Theme.iconBatteryCharging;
        if (root.full) return Theme.iconBatteryFull;
        return Theme.iconBatteryBars[Math.min(6, Math.floor(root.percent / 100 * 7))];
    }
    label: root.percent + "%"
    containerColor: root.critical ? Theme.errorContainer : Theme.surfaceContainerHigh
    contentColor: root.critical
        ? Theme.errorContainerText
        : (root.charging ? Theme.primary : Theme.surfaceText)

    Tip {
        target: root
        text: (root.remaining !== "" ? root.remaining + I18n.t(" remaining") + "\n" : "") + root.percent + "%"
        shown: root.hovered
    }
}
