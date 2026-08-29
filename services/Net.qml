pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Networking via nmcli.
//
// Everything a person actually does with wifi: join a new protected network,
// reconnect to a known one, disconnect, forget, and turn the radio off.
//
// It used to stop at "connect to something NetworkManager already has a profile
// for", on the grounds that groot is wired and a passphrase field inside a layer
// surface on a host driven over a game stream was a bad idea. That is still true
// OF GROOT and false of everywhere else — most machines running this are on
// wifi, and a wifi panel that cannot join a network is a status icon with extra
// steps.
//
// The scan is demand-driven: it runs while the popout is open, because scanning
// costs a radio sweep and there is usually nothing to look at.
//
// nmcli is used with -t (terse) and explicit -f fields throughout, never the
// human-readable output — that shape is stable, where column widths are not.

Singleton {
    id: root

    property string ethernet: ""      // connection name, "" when down
    property string wifi: ""          // SSID, "" when not connected
    property string device: ""        // the wifi interface, for disconnect
    property int strength: 0          // 0-100
    property bool wifiEnabled: false
    property bool scanning: false

    // An action is in flight. The panel disables itself rather than queueing
    // clicks, because nmcli calls that overlap fight over the same device.
    property bool busy: false

    // The last failure, shown verbatim. nmcli's messages are the useful ones —
    // "Secrets were required, but not provided" is what a wrong passphrase looks
    // like, and paraphrasing it would only lose information.
    property string error: ""

    // SSIDs NetworkManager already has a profile for. Worth distinguishing: a
    // saved network joins on one click, an unsaved secured one needs a
    // passphrase, and only a saved one can be forgotten.
    property var saved: ({})

    readonly property bool connected: root.ethernet !== "" || root.wifi !== ""

    readonly property alias networks: found

    ListModel {
        id: found
    }

    function isSaved(ssid: string): bool {
        return root.saved[ssid] === true;
    }

    function icon(): string {
        if (root.ethernet !== "")
            return "lan";
        if (!root.wifiEnabled)
            return "wifi_off";
        if (root.wifi === "")
            return "wifi_off";
        if (root.strength > 66)
            return "wifi";
        if (root.strength > 33)
            return "wifi_2_bar";
        return "wifi_1_bar";
    }

    function label(): string {
        if (root.ethernet !== "")
            return root.ethernet;
        if (root.wifi !== "")
            return root.wifi;
        return "offline";
    }

    Process {
        id: status
        running: true
        command: ["bash", "-c", `
            eth=$(nmcli -t -f TYPE,STATE,CONNECTION device status | awk -F: '$1=="ethernet" && $2=="connected"{print $3; exit}')
            wifi=$(nmcli -t -f ACTIVE,SSID,SIGNAL device wifi list --rescan no 2>/dev/null | awk -F: '$1=="yes"{print $2":"$3; exit}')
            dev=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')
            enabled=$(nmcli -t radio wifi 2>/dev/null)
            # Saved wireless profiles, one per line, after the counts above.
            printf '%s\\n%s\\n%s\\n%s\\n' "$eth" "$wifi" "$dev" "$enabled"
            nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1}'
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

                root.device = (lines[2] ?? "").trim();
                root.wifiEnabled = (lines[3] ?? "").trim() === "enabled";

                // Everything from the fifth line on is a saved profile name.
                const known = {};
                for (let i = 4; i < lines.length; i++) {
                    const name = lines[i].trim();
                    if (name)
                        known[name] = true;
                }
                root.saved = known;
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: if (!status.running)
            status.running = true
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

    // --- Actions --------------------------------------------------------------
    //
    // One Process for all of them, with the command swapped before each run.
    // They are mutually exclusive by nature — you cannot forget a network while
    // connecting to it — and `busy` is what the panel reads to stop you trying.

    function run(args: var): void {
        if (root.busy)
            return;
        root.error = "";
        root.busy = true;
        action.command = args;
        action.running = true;
    }

    Process {
        id: action
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message)
                    root.error = message.replace(/^Error:\s*/i, "");
            }
        }

        onExited: code => {
            root.busy = false;
            if (code !== 0 && root.error === "")
                root.error = `nmcli exited ${code}`;
            root.refresh();
            // Re-scan so the list reflects what just happened — a forgotten
            // network loses its saved marker, a joined one becomes active.
            root.scan();
        }
    }

    // An empty password means "use the saved profile", which is what a known
    // network needs and what an open one needs. NetworkManager stores the
    // passphrase itself on first success, so this is asked once per network.
    function connect(ssid: string, password: string): void {
        root.run(password ? ["nmcli", "device", "wifi", "connect", ssid, "password", password] : ["nmcli", "device", "wifi", "connect", ssid]);
    }

    // The DEVICE rather than the connection: disconnecting the device is what
    // stops NetworkManager immediately reconnecting to the same network, which
    // `connection down` does not.
    function disconnect(): void {
        if (root.device === "")
            return;
        root.run(["nmcli", "device", "disconnect", root.device]);
    }

    // Deletes the stored profile and its passphrase, so the network has to be
    // joined from scratch next time.
    function forget(ssid: string): void {
        root.run(["nmcli", "connection", "delete", ssid]);
    }

    function setWifiEnabled(on: bool): void {
        root.run(["nmcli", "radio", "wifi", on ? "on" : "off"]);
    }

    function clearError(): void {
        root.error = "";
    }
}
