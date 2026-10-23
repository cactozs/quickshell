pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Native port of ~/.config/waybar/scripts/waybar-system.sh:
// CPU usage/temperature, GPU (nvidia-smi or amdgpu sysfs), memory, network
// rates. /proc and sysfs are read through FileView.reload() so the 2 s timer
// does not spawn a process per sample. Named SystemMonitor (not SystemStats)
// so that `import "../services"` does not shadow the modules/SystemStats chip.
Singleton {
    id: root

    property int cpuUsage: 0
    property string cpuTemp: "N/A"

    property string gpuTemp: "N/A"
    property string gpuUsage: "N/A"

    property string ramUsed: "0.0 GiB"
    property string ramTotal: "0.0 GiB"
    property int ramUsage: 0

    property string rxSpeed: "0 B/s"
    property string txSpeed: "0 B/s"

    property bool hasNvidia: false
    property bool hasGpu: false
    property string gpuVendor: "none"
    property string gpuBusyPath: ""
    property string gpuTempPath: ""

    // Short history for the SystemPopup sparklines (60 samples ~ 2 min).
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property int gpuUsageNum: 0

    property string uptime: ""
    property string loadAvg: ""
    property string thermalPath: ""

    // Samples for delta calculations.
    property real statTotal1: 0
    property real statIdle1: 0
    property bool statReady: false
    property real netRx1: 0
    property real netTx1: 0
    property real netAt: 0
    property double lastNvidia: 0

    readonly property string tooltip:
        "CPU\n" +
        I18n.t("Temperature: ") + cpuTemp + "\n" +
        I18n.t("Usage: ") + cpuUsage + "%\n" +
        "\n" +
        "GPU\n" +
        I18n.t("Temperature: ") + gpuTemp + "\n" +
        I18n.t("Usage: ") + gpuUsage + "\n" +
        "\n" +
        I18n.t("Memory") + "\n" +
        I18n.t("Used: ") + ramUsed + " / " + ramTotal + "\n" +
        I18n.t("Usage: ") + ramUsage + "%\n" +
        "\n" +
        I18n.t("Network") + "\n" +
        "↓ " + rxSpeed + "\n" +
        "↑ " + txSpeed

    function formatSpeed(bytes: real): string {
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MiB/s";
        if (bytes >= 1024) return (bytes / 1024).toFixed(1) + " KiB/s";
        return Math.round(bytes) + " B/s";
    }

    function formatUptime(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const d = Math.floor(s / 86400);
        const h = Math.floor(s % 86400 / 3600);
        const m = Math.floor(s % 3600 / 60);
        const hh = h < 10 ? "0" + h : "" + h;
        const mm = m < 10 ? "0" + m : "" + m;
        return d > 0 ? d + I18n.t(" дн ") + hh + ":" + mm : hh + ":" + mm;
    }

    function pushHistory(series: var, value: int): var {
        const next = series.concat([Math.max(0, Math.min(100, value))]);
        return next.length > 60 ? next.slice(next.length - 60) : next;
    }

    function refresh(): void {
        statFile.reload();
        netFile.reload();
        memFile.reload();
        uptimeFile.reload();
        loadFile.reload();
        if (root.thermalPath !== "")
            thermalFile.reload();
        if (root.gpuVendor === "amd") {
            gpuBusyFile.reload();
            gpuTempFile.reload();
        }
        if (root.hasNvidia && (ShellState.systemScreen !== "" || Date.now() - root.lastNvidia > 10000)) {
            root.lastNvidia = Date.now();
            if (!gpuProc.running)
                gpuProc.running = true;
        }
    }

    onCpuUsageChanged: cpuHistory = pushHistory(cpuHistory, cpuUsage)
    onRamUsageChanged: ramHistory = pushHistory(ramHistory, ramUsage)
    onGpuUsageNumChanged: gpuHistory = pushHistory(gpuHistory, gpuUsageNum)

    FileView {
        id: statFile

        path: "/proc/stat"
        watchChanges: false
        printErrors: false

        onTextChanged: {
            const parts = text().trim().split(/\s+/).slice(1).map(Number);
            if (parts.length < 5)
                return;
            const idle = parts[3] + (parts[4] || 0);
            const total = parts.slice(0, 8).reduce((a, b) => a + b, 0);
            if (!root.statReady) {
                root.statTotal1 = total;
                root.statIdle1 = idle;
                root.statReady = true;
                return;
            }
            const dt = total - root.statTotal1;
            const di = idle - root.statIdle1;
            root.cpuUsage = dt > 0 ? Math.round(100 * (dt - di) / dt) : 0;
            root.statTotal1 = total;
            root.statIdle1 = idle;
        }
    }

    FileView {
        id: netFile

        path: "/proc/net/dev"
        watchChanges: false
        printErrors: false

        onTextChanged: {
            let rx = 0;
            let tx = 0;
            const lines = text().split("\n");
            for (let i = 2; i < lines.length; i++) {
                const parts = lines[i].trim().split(/\s+/);
                if (parts.length < 10)
                    continue;
                rx += Number(parts[1]) || 0;
                tx += Number(parts[9]) || 0;
            }
            const now = Date.now();
            if (root.netAt > 0 && now > root.netAt) {
                const secs = (now - root.netAt) / 1000;
                root.rxSpeed = root.formatSpeed((rx - root.netRx1) / secs);
                root.txSpeed = root.formatSpeed((tx - root.netTx1) / secs);
            }
            root.netRx1 = rx;
            root.netTx1 = tx;
            root.netAt = now;
        }
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
        watchChanges: false
        printErrors: false

        onTextChanged: {
            let total = 0;
            let available = 0;
            for (const line of text().split("\n")) {
                if (line.startsWith("MemTotal:"))
                    total = parseInt(line.split(/\s+/)[1]);
                else if (line.startsWith("MemAvailable:"))
                    available = parseInt(line.split(/\s+/)[1]);
            }
            if (total <= 0)
                return;
            const used = total - available;
            root.ramUsage = Math.round(100 * used / total);
            root.ramUsed = (used / 1024 / 1024).toFixed(1) + " GiB";
            root.ramTotal = (total / 1024 / 1024).toFixed(1) + " GiB";
        }
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        watchChanges: false
        printErrors: false

        onTextChanged: {
            const s = parseFloat(text().trim().split(/\s+/)[0]);
            if (!isNaN(s))
                root.uptime = root.formatUptime(s);
        }
    }

    FileView {
        id: loadFile

        path: "/proc/loadavg"
        watchChanges: false
        printErrors: false

        onTextChanged: {
            const parts = text().trim().split(/\s+/);
            if (parts.length >= 3)
                root.loadAvg = parts.slice(0, 3).join(" ");
        }
    }

    FileView {
        id: thermalFile

        path: root.thermalPath
        watchChanges: false
        printErrors: false

        onTextChanged: {
            const t = parseInt(text().trim());
            root.cpuTemp = isNaN(t) || t < 20000 || t > 110000 ? "N/A" : Math.round(t / 1000) + "°C";
        }
    }

    // First readable thermal zone, same range check as the old script.
    Process {
        id: thermalProbe

        command: [
            "sh", "-c",
            "for z in /sys/class/thermal/thermal_zone*/temp; do " +
            "[ -r \"$z\" ] || continue; " +
            "t=$(cat \"$z\" 2>/dev/null); " +
            "case \"$t\" in ''|*[!0-9]*) continue;; esac; " +
            "if [ \"$t\" -gt 20000 ] && [ \"$t\" -lt 110000 ]; then echo \"$z\"; exit 0; fi; " +
            "done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.thermalPath = text.trim();
                if (root.thermalPath !== "")
                    thermalFile.reload();
            }
        }
    }

    // nvidia-smi when present, otherwise the amdgpu sysfs pair.
    Process {
        id: gpuProbe

        command: [
            "sh", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then echo nvidia; exit 0; fi; " +
            "busy=$(for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && { echo \"$f\"; break; }; done); " +
            "[ -n \"$busy\" ] || { echo none; exit 0; }; " +
            "temp=$(for h in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$h/name\" 2>/dev/null)\" = amdgpu ] && { echo \"$h/temp1_input\"; break; }; done); " +
            "echo \"amd|$busy|$temp\""
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out === "nvidia") {
                    root.gpuVendor = "nvidia";
                    root.hasNvidia = true;
                    root.hasGpu = true;
                    root.refresh();
                } else if (out.startsWith("amd|")) {
                    const parts = out.split("|");
                    root.gpuVendor = "amd";
                    root.gpuBusyPath = parts[1] ?? "";
                    root.gpuTempPath = parts[2] ?? "";
                    root.hasGpu = root.gpuBusyPath !== "";
                    root.refresh();
                }
            }
        }
    }

    FileView {
        id: gpuBusyFile

        path: root.gpuBusyPath
        watchChanges: false
        printErrors: false

        onTextChanged: {
            const v = parseInt(text().trim());
            if (!isNaN(v)) {
                root.gpuUsageNum = v;
                root.gpuUsage = v + "%";
            }
        }
    }

    FileView {
        id: gpuTempFile

        path: root.gpuTempPath
        watchChanges: false
        printErrors: false

        onTextChanged: {
            const t = parseInt(text().trim());
            if (!isNaN(t))
                root.gpuTemp = Math.round(t / 1000) + "°C";
        }
    }

    Process {
        id: gpuProc

        command: [
            "nvidia-smi",
            "--query-gpu=temperature.gpu,utilization.gpu",
            "--format=csv,noheader,nounits"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",").map(s => s.trim());
                if (parts.length < 2)
                    return;
                const t = parseInt(parts[0]);
                if (isNaN(t))
                    return;
                root.gpuTemp = t + "°C";
                root.gpuUsage = parts[1] + "%";
                const u = parseInt(parts[1]);
                if (!isNaN(u))
                    root.gpuUsageNum = u;
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        thermalProbe.running = true;
        gpuProbe.running = true;
        refresh();
    }
}
