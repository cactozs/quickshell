pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Native port of ~/.config/waybar/scripts/waybar-system.sh:
// CPU usage/temperature, GPU (nvidia-smi), memory, network rates.
// Named SystemMonitor (not SystemStats) so that `import "../services"`
// does not shadow the modules/SystemStats bar chip.
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

    // Short history for the SystemPopup sparklines (60 samples ~ 2 min).
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property int gpuUsageNum: 0

    property string uptime: ""
    property string loadAvg: ""

    // Samples for delta calculations.
    property real statTotal1: 0
    property real statIdle1: 0
    property real netRx1: 0
    property real netTx1: 0

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
        if (!statProc.running) statProc.running = true;
        if (!netProc.running) netProc.running = true;
        if (!memProc.running) memProc.running = true;
        if (!thermalProc.running) thermalProc.running = true;
        if (!uptimeProc.running) uptimeProc.running = true;
        if (hasNvidia && !gpuProc.running) gpuProc.running = true;
    }

    onCpuUsageChanged: cpuHistory = pushHistory(cpuHistory, cpuUsage)
    onRamUsageChanged: ramHistory = pushHistory(ramHistory, ramUsage)
    onGpuUsageNumChanged: gpuHistory = pushHistory(gpuHistory, gpuUsageNum)

    // CPU usage: two /proc/stat samples 100 ms apart.
    Process {
        id: statProc
        command: ["head", "-n", "1", "/proc/stat"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/).slice(1).map(Number);
                if (parts.length < 5) return;
                const idle = parts[3] + (parts[4] || 0);
                const total = parts.slice(0, 8).reduce((a, b) => a + b, 0);
                if (root.statTotal1 === 0) {
                    root.statTotal1 = total;
                    root.statIdle1 = idle;
                    cpuDelay.restart();
                } else {
                    const dt = total - root.statTotal1;
                    const di = idle - root.statIdle1;
                    root.cpuUsage = dt > 0 ? Math.round(100 * (dt - di) / dt) : 0;
                    root.statTotal1 = 0;
                }
            }
        }
    }

    Timer {
        id: cpuDelay
        interval: 100
        onTriggered: statProc.running = true
    }

    // Network rates: two /proc/net/dev samples 100 ms apart.
    Process {
        id: netProc
        command: ["sh", "-c", "awk 'NR>2 {rx += $2; tx += $10} END {print rx, tx}' /proc/net/dev"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/).map(Number);
                if (parts.length < 2 || isNaN(parts[0])) return;
                if (root.netRx1 === 0) {
                    root.netRx1 = parts[0] || 1;
                    root.netTx1 = parts[1];
                    netDelay.restart();
                } else {
                    // Samples are 0.1 s apart -> bytes/s = delta * 10.
                    root.rxSpeed = root.formatSpeed((parts[0] - root.netRx1) * 10);
                    root.txSpeed = root.formatSpeed((parts[1] - root.netTx1) * 10);
                    root.netRx1 = 0;
                }
            }
        }
    }

    Timer {
        id: netDelay
        interval: 100
        onTriggered: netProc.running = true
    }

    Process {
        id: memProc
        command: ["rg", "-N", "^(MemTotal|MemAvailable):", "/proc/meminfo"]

        stdout: StdioCollector {
            onStreamFinished: {
                let total = 0, available = 0;
                for (const line of text.split("\n")) {
                    if (line.startsWith("MemTotal:")) total = parseInt(line.split(/\s+/)[1]);
                    else if (line.startsWith("MemAvailable:")) available = parseInt(line.split(/\s+/)[1]);
                }
                if (total <= 0) return;
                const used = total - available; // kB
                root.ramUsage = Math.round(100 * used / total);
                root.ramUsed = (used / 1024 / 1024).toFixed(1) + " GiB";
                root.ramTotal = (total / 1024 / 1024).toFixed(1) + " GiB";
            }
        }
    }

    // First readable thermal zone in 20..110 C, same as the waybar script.
    Process {
        id: thermalProc
        command: [
            "sh", "-c",
            "for z in /sys/class/thermal/thermal_zone*/temp; do " +
            "[ -r \"$z\" ] || continue; " +
            "t=$(cat \"$z\" 2>/dev/null); " +
            "case \"$t\" in ''|*[!0-9]*) continue;; esac; " +
            "if [ \"$t\" -gt 20000 ] && [ \"$t\" -lt 110000 ]; then echo $((t / 1000)); exit 0; fi; " +
            "done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(text.trim());
                if (isNaN(t)) {
                    root.cpuTemp = "N/A";
                    return;
                }
                root.cpuTemp = t + "°C";
            }
        }
    }

    Process {
        id: gpuProbe
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1 && echo yes"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.hasNvidia = text.trim() === "yes";
                if (root.hasNvidia) root.refresh();
            }
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
                if (parts.length < 2) return;
                const t = parseInt(parts[0]);
                if (isNaN(t)) return;
                root.gpuTemp = t + "°C";
                root.gpuUsage = parts[1] + "%";
                const u = parseInt(parts[1]);
                if (!isNaN(u)) root.gpuUsageNum = u;
            }
        }
    }

    // Uptime seconds + load average, one cheap read per cycle.
    Process {
        id: uptimeProc
        command: ["sh", "-c", "cut -d' ' -f1 /proc/uptime; awk '{print $1, $2, $3}' /proc/loadavg"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const s = parseFloat(lines[0]);
                if (!isNaN(s)) root.uptime = root.formatUptime(s);
                if (lines.length > 1 && lines[1].trim() !== "") root.loadAvg = lines[1].trim();
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
        gpuProbe.running = true;
        refresh();
    }
}
