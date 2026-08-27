pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Networking via nmcli.
//
// groot is a wired host with a static address, so the ethernet state is the one
// that actually matters day to day and wifi is the exception. The scan is
// therefore demand-driven — it only runs while the popout is open, because
// scanning costs a radio sweep and there is usually nothing to look at.

Singleton {
    id: root

    property string ethernet: ""      // connection name, "" when down
    property string wifi: ""          // SSID, "" when not connected
    property int strength: 0          // 0-100
    property bool wifiEnabled: false
    property bool scanning: false

    readonly property bool connected: ethernet !== "" || wifi !== ""

    readonly property alias networks: found

    ListModel {
        id: found
    }

    function icon(): string {
        if (ethernet !== "")
            return "lan";
        if (wifi === "")
            return "wifi_off";
        if (root.strength > 66)
            return "wifi";
        if (root.strength > 33)
            return "wifi_2_bar";
        return "wifi_1_bar";
    }

    function label(): string {
        if (ethernet !== "")
            return ethernet;
        if (wifi !== "")
            return wifi;
        return "offline";
    }

    // -m multiline is not used on purpose: -t (terse) with explicit -f fields
    // gives a stable colon-separated shape that does not shift when nmcli's
    // human-readable column widths change.
    Process {
        id: status
        running: true
        command: ["bash", "-c", `
            eth=$(nmcli -t -f TYPE,STATE,CONNECTION device status | awk -F: '$1=="ethernet" && $2=="connected"{print $3; exit}')
            wifi=$(nmcli -t -f ACTIVE,SSID,SIGNAL device wifi list --rescan no 2>/dev/null | awk -F: '$1=="yes"{print $2":"$3; exit}')
            enabled=$(nmcli -t radio wifi 2>/dev/null)
            printf '%s\\n%s\\n%s\\n' "$eth" "$wifi" "$enabled"
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.ethernet = (lines[0] ?? "").trim();

                const w = (lines[1] ?? "").trim();
                if (w) {
                    const sep = w.lastIndexOf(":");
                    root.wifi = w.slice(0, sep);
                    root.strength = parseInt(w.slice(sep + 1)) || 0;
                } else {
                    root.wifi = "";
                    root.strength = 0;
                }

                root.wifiEnabled = (lines[2] ?? "").trim() === "enabled";
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: if (!status.running) status.running = true
    }

    function refresh(): void {
        if (!status.running)
            status.running = true;
    }

    function scan(): void {
        if (scanProc.running)
            return;
        root.scanning = true;
        scanProc.running = true;
    }

    Process {
        id: scanProc
        running: false
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]

        stdout: StdioCollector {
            onStreamFinished: {
                found.clear();
                const seen = {};
                for (const line of text.split("\n")) {
                    if (!line.trim())
                        continue;
                    const f = line.split(":");
                    const ssid = f[1] ?? "";
                    // Hidden networks have no SSID and nothing to click on.
                    // Duplicates are the same network on several bands.
                    if (!ssid || seen[ssid])
                        continue;
                    seen[ssid] = true;
                    found.append({
                        active: f[0] === "yes",
                        ssid: ssid,
                        signal: parseInt(f[2]) || 0,
                        secured: (f[3] ?? "").trim() !== ""
                    });
                }
                root.scanning = false;
            }
        }
    }

    function connect(ssid: string, password: string): void {
        const cmd = password ? ["nmcli", "device", "wifi", "connect", ssid, "password", password] : ["nmcli", "device", "wifi", "connect", ssid];
        connectProc.command = cmd;
        connectProc.running = true;
    }

    Process {
        id: connectProc
        running: false
        onExited: root.refresh()
    }

    function setWifiEnabled(on: bool): void {
        radio.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        radio.running = true;
    }

    Process {
        id: radio
        running: false
        onExited: root.refresh()
    }
}
