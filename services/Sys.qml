pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// System metrics, with no native plugin behind them.
//
// Caelestia reads these through ~5k lines of C++ talking to lm_sensors and
// /proc directly. We poll instead. That is a real trade — polling costs a
// process spawn per tick where the plugin costs a syscall — so two things keep
// it honest:
//
//   1. ONE process per tick, not one per metric. The script below emits a single
//      line with everything in it. Five separate Process objects at 3s each is
//      five spawns; this is one.
//   2. Nothing polls unless something is watching. `subscribers` is incremented
//      by whatever is on screen; at zero the timer stops. The performance tab is
//      usually closed, and a closed tab should cost nothing.
//
// On a host where every frame is encoded and shipped over a network, "costs
// nothing when idle" is worth more than shaving microseconds off each read.

Singleton {
    id: root

    // --- Values -------------------------------------------------------------
    property real cpu: 0        // percent, 0-100
    property real memory: 0     // percent used
    property real swap: 0       // percent used
    property real disk: 0       // percent used on /
    property real temperature: 0 // degrees C, 0 when unavailable
    property int uptime: 0      // seconds

    // --- Demand-driven polling ---------------------------------------------
    // Anything displaying metrics calls subscribe() when it appears and
    // unsubscribe() when it goes away.
    property int subscribers: 0

    function subscribe(): void {
        root.subscribers++;
        if (root.subscribers === 1) {
            poll.running = true;
            proc.running = true; // don't wait a whole interval for first paint
        }
    }

    function unsubscribe(): void {
        root.subscribers = Math.max(0, root.subscribers - 1);
        if (root.subscribers === 0)
            poll.running = false;
    }

    Timer {
        id: poll
        interval: Config.services.metricsInterval
        repeat: true
        running: false
        onTriggered: {
            // Skip if the previous tick has not finished. A slow `sensors` read
            // must not stack up spawns behind it — groot's ACPI thermal zone has
            // historically taken many seconds to answer.
            if (!proc.running)
                proc.running = true;
        }
    }

    Process {
        id: proc
        running: false

        // Sampled twice ~200ms apart because /proc/stat is cumulative: a single
        // read gives jiffies since boot, which says nothing about right now.
        //
        // Deliberately not `top -bn1`: top spawns, reads every process in
        // /proc, and formats a screenful of text we throw away, to produce one
        // number that two awk passes over a single file already have.
        command: ["bash", "-c", `
            read_cpu() { awk '/^cpu /{idle=$5+$6; total=0; for(i=2;i<=9;i++) total+=$i; print total, idle}' /proc/stat; }
            set -- $(read_cpu); t1=$1; i1=$2
            sleep 0.2
            set -- $(read_cpu); t2=$1; i2=$2
            dt=$((t2-t1)); di=$((i2-i1))
            cpu=0
            [ "$dt" -gt 0 ] && cpu=$(( (dt-di)*100/dt ))

            mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{ if (t>0) printf "%d", (t-a)*100/t; else print 0 }' /proc/meminfo)
            swap=$(awk '/^SwapTotal:/{t=$2} /^SwapFree:/{f=$2} END{ if (t>0) printf "%d", (t-f)*100/t; else print 0 }' /proc/meminfo)
            disk=$(df -P / | awk 'NR==2{gsub(/%/,"",$5); print $5}')
            up=$(awk '{printf "%d", $1}' /proc/uptime)

            # hwmon directly rather than the sensors binary: same data, no parse
            # of a human-readable layout that changes between chips. k10temp is
            # groot's CPU package sensor; the fallback keeps this working on a
            # host with different silicon.
            temp=0
            for h in /sys/class/hwmon/hwmon*; do
              name=$(cat "$h/name" 2>/dev/null || echo)
              case "$name" in
                k10temp|coretemp|zenpower)
                  v=$(cat "$h/temp1_input" 2>/dev/null || echo 0)
                  temp=$((v/1000)); break ;;
              esac
            done

            printf '%s %s %s %s %s %s\\n' "$cpu" "$mem" "$swap" "$disk" "$temp" "$up"
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/).map(Number);
                if (parts.length < 6 || parts.some(isNaN))
                    return;
                root.cpu = parts[0];
                root.memory = parts[1];
                root.swap = parts[2];
                root.disk = parts[3];
                root.temperature = parts[4];
                root.uptime = parts[5];
            }
        }
    }

    function formatUptime(): string {
        const d = Math.floor(root.uptime / 86400);
        const h = Math.floor((root.uptime % 86400) / 3600);
        const m = Math.floor((root.uptime % 3600) / 60);
        if (d > 0)
            return `${d}d ${h}h`;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }
}
