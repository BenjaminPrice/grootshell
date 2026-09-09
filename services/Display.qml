pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// How big the desktop is, per resolution.
//
// groot has no monitor. Sunshine retargets the headless output to whatever the
// Moonlight client asked for on connect — 1440p from the desk, 4K from the
// sofa, and whatever odd geometry a MacBook with a notch or a phone reports —
// so the resolution is not a setting anybody chose. It is a property of
// whichever client is looking.
//
// Which means the scale cannot be one number either. 1x is right at 1440p and
// unreadable at 4K, and a single "UI scale" would be wrong for every client but
// one. So the scale is remembered PER RESOLUTION, and connecting at a size you
// have used before brings back the scale you picked for it.
//
// ## The contract with sunscreen.sh
//
// The map lives in a plain JSON file that both this shell and the nixos repo's
// sunscreen.sh read:
//
//     ${XDG_STATE_HOME:-$HOME/.local/state}/grootshell/display-scales.json
//     { "3840x2160": 1.5, "2560x1440": 1, "1920x1080": 1 }
//
// Keys are "<width>x<height>" of the PHYSICAL mode; values are Hyprland scales.
// Refresh rate is deliberately not part of the key — the same screen at 60 and
// at 120 is the same size, and splitting them would ask you to set the scale
// twice for one display.
//
// This side writes it when you pick a scale; sunscreen.sh reads it on connect
// and applies the entry for the mode it just set. Neither owns the other: with
// the shell dead, connecting still gets the right scale, and with Sunshine out
// of the picture the panel still works. That matters here for the same reason
// game mode lives in a script — groot has no local console, so nothing may
// depend on this shell being alive to make the machine usable.
//
// A file of its own rather than a key in state.json, which is a JsonAdapter:
// assigning a whole object through a var property on one does not reliably
// persist (see the same note in services/Settings.qml), and a foreign script
// should not have to parse a file whose shape is quickshell's business. This
// path is a published interface; state.json is not.

Singleton {
    id: root

    // The scales offered, before they are snapped to what the current mode can
    // actually express. Not every one of these survives that — see `options`.
    //
    // Stops at 3: past there a 4K desktop is 1280x720 of logical space, which is
    // fewer usable pixels than the 1080p client this box started life serving.
    readonly property var presets: [1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/grootshell/display-scales.json`

    // --- What the compositor currently has ----------------------------------

    property string output: ""
    property int width: 0
    property int height: 0
    property real refreshRate: 0
    property real scale: 1
    property bool known: false

    // The map key for the mode on screen right now.
    readonly property string resolution: root.width > 0 && root.height > 0 ? `${root.width}x${root.height}` : ""

    // How much desktop the current scale actually leaves. This is the number
    // that decides whether a scale is usable, and it is not the one anybody has
    // in mind when they pick "2x" — 4K at 2x is a 1080p desktop, which is
    // obvious once said and surprising until it is.
    readonly property int logicalWidth: root.scale > 0 ? Math.round(root.width / root.scale) : root.width
    readonly property int logicalHeight: root.scale > 0 ? Math.round(root.height / root.scale) : root.height

    // --- Legal scales -------------------------------------------------------

    function gcd(a: int, b: int): int {
        while (b) {
            const t = a % b;
            a = b;
            b = t;
        }
        return a;
    }

    // Hyprland refuses a scale unless the mode divides into a whole number of
    // logical pixels, counted in 1/120ths — so the legal scales are the divisors
    // of gcd(width, height) in those units, and everything else is rejected.
    //
    // Rejected SILENTLY, which is the part worth guarding against: the eval
    // returns nothing, the monitor keeps the scale it had, and the panel would
    // sit there showing a tick beside a value that never took. So a request is
    // snapped UP to the next legal value rather than sent as asked and hoped
    // for.
    //
    // It is not a rounding detail. At 2560x1440 the divisor grid means 1.5 is
    // not expressible and becomes 1.6; at 3840x2160 it is exact. The same
    // preset is therefore a different number on two clients, which is why
    // `options` is computed against the live mode rather than being a fixed
    // list.
    function cleanScale(scale: real, w: int, h: int): real {
        if (w <= 0 || h <= 0)
            return scale;
        const g = root.gcd(w * 120, h * 120);
        let k = Math.round(scale * 120);
        if (k < 1)
            k = 1;
        if (k > g)
            k = g;
        while (g % k !== 0)
            k++;
        return k / 120;
    }

    // The presets as this mode can actually express them, deduplicated and in
    // order.
    //
    // Deduplicated because snapping collapses neighbours: on a mode with a
    // coarse grid, 1.5 and 1.75 can both land on 1.6, and two rows that set the
    // same scale is a panel offering a choice it cannot honour.
    //
    // The current scale is folded in even when no preset produced it, so the
    // ticked row always exists. Without that, a scale set by hand or by an older
    // preset list would leave the panel showing nothing as current — which reads
    // as "no scale is applied" rather than "the applied one is not offered".
    readonly property var options: {
        const seen = ({});
        const out = [];

        for (const p of root.presets) {
            const value = root.cleanScale(p, root.width, root.height);
            const key = value.toFixed(5);
            if (key in seen)
                continue;
            seen[key] = true;
            out.push(value);
        }

        // Compared with a tolerance rather than by key, for the reason in
        // `matches` below: the compositor's own number is rounded, so an exact
        // test would decide the live scale is missing and add a second row for
        // it a hundredth away from one already there.
        if (root.known && !out.some(v => root.matches(v, root.scale)))
            out.push(root.scale);

        return out.sort((a, b) => a - b);
    }

    // Whether two scales are the same scale.
    //
    // hyprctl reports scale to two decimals — `"scale": 1.00` — so a monitor set
    // to 4/3 comes back as 1.33 against an option of 1.333333, and an exact
    // comparison ticks nothing. The panel then shows a list with no current
    // entry, which reads as "no scale is applied".
    //
    // 0.006 covers that rounding (worst case 0.005) and still cannot match two
    // options at once: adjacent legal scales are 1/120 = 0.00833 apart.
    function matches(a: real, b: real): bool {
        return Math.abs(a - b) < 0.006;
    }

    // For the compositor and the file: enough precision that the value survives
    // the trip.
    //
    // NOT toFixed. A legal scale need not be a short decimal — 3456x2160 admits
    // 4/3 — and 1.3333 is a quarter of a 1/120 step off the grid, which Hyprland
    // rejects silently. Ten significant figures round-trips through its
    // scale × 120 back to the integer we meant, and trailing zeros still come off
    // so 1 is "1" rather than "1.000000000".
    function format(scale: real): string {
        return String(Number(scale.toPrecision(10)));
    }

    // For the panel. Three decimals is past anything worth reading — 1.875 is
    // exact, 4/3 shows as 1.333 — and keeps a column of scales the same width
    // instead of one row carrying ten digits.
    function label(scale: real): string {
        return String(Number(scale.toFixed(3)));
    }

    // --- The remembered map -------------------------------------------------

    // Blocking, for the same reason services/Settings.qml blocks: every write is
    // a read-modify-write, and an asynchronous read after a write returns the
    // file as it was before it landed, so setting a second key silently drops
    // the first.
    property FileView file: FileView {
        id: file

        path: root.path
        // Not watched. This shell and sunscreen.sh both write it, but never at
        // the same moment — sunscreen only ever reads — and a watcher here would
        // exist to see our own writes come back.
        printErrors: false
        blockLoading: true
        blockWrites: true
        // Read by another process, so a crash mid-write must not leave it
        // truncated: sunscreen.sh would then fall back to 1x on a client that
        // had a scale set, which looks like the setting was forgotten.
        atomicWrites: true
    }

    function read(): var {
        file.reload();
        const raw = file.text();
        if (!raw || raw.trim() === "")
            return ({});
        try {
            const parsed = JSON.parse(raw);
            return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({});
        } catch (e) {
            return ({});
        }
    }

    // Bumped after every write, so anything showing the map re-reads it. No
    // property changes when a file does, and the panel lists remembered
    // resolutions straight out of it.
    property int revision: 0

    // What is remembered for a resolution, or 0 for "nothing yet". Never
    // snapped: it is returned as stored, and the callers that apply it snap
    // against the mode they are applying it to.
    function scaleFor(resolution: string): real {
        const value = root.read()[resolution];
        return typeof value === "number" && value > 0 ? value : 0;
    }

    // Every remembered resolution, widest first, for the panel's list of clients
    // it has seen before.
    readonly property var remembered: {
        root.revision;
        const map = root.read();
        const out = [];
        for (const key in map) {
            const parts = /^(\d+)x(\d+)$/.exec(key);
            if (!parts || typeof map[key] !== "number")
                continue;
            out.push({
                resolution: key,
                width: Number(parts[1]),
                height: Number(parts[2]),
                scale: map[key]
            });
        }
        return out.sort((a, b) => b.width * b.height - a.width * a.height);
    }

    function remember(resolution: string, scale: real): void {
        if (resolution === "")
            return;
        const map = root.read();
        // Same precision as goes to the compositor. sunscreen.sh snaps whatever
        // it reads back onto the grid, so a rounded value here would self-correct
        // — but a file meant to be read by a human and a shell script should not
        // need that to be true.
        map[resolution] = Number(scale.toPrecision(10));
        file.setText(JSON.stringify(map, null, 2) + "\n");
        root.revision++;
    }

    function forget(resolution: string): void {
        const map = root.read();
        if (!(resolution in map))
            return;
        delete map[resolution];
        file.setText(JSON.stringify(map, null, 2) + "\n");
        root.revision++;
    }

    // --- Applying -----------------------------------------------------------

    // Set the scale for the mode on screen now, and remember it for the next
    // client that connects at this size.
    //
    // The mode is passed back exactly as read rather than being omitted. Hyprland
    // takes a whole monitor declaration, not a scale on its own, so leaving the
    // mode out would set the output to "preferred" — which on a headless output
    // is 1920x1080@60, undoing the resolution Sunshine negotiated. The point is
    // to change one field of a line we otherwise reproduce.
    function apply(scale: real): void {
        if (!root.known || root.output === "")
            return;

        const value = root.cleanScale(scale, root.width, root.height);

        // hl.monitor is config and applies on eval; hl.dsp.* are factories
        // needing dispatch to call them. The same note is in sunscreen.sh, and
        // getting it wrong builds a closure and throws it away with no error.
        apply.command = ["hyprctl", "eval", `hl.monitor({ output = '${root.output}', mode = '${root.width}x${root.height}@${root.format(root.refreshRate)}', position = '0x0', scale = ${root.format(value)} })`];
        apply.running = true;

        root.remember(root.resolution, value);

        // Optimistic, then confirmed by the requery below. The panel is being
        // looked at while this runs, and waiting a round trip to move the tick
        // makes a click feel like it missed.
        root.scale = value;
        settle.restart();
    }

    Process {
        id: apply
        running: false
    }

    // Move one option up or down the list.
    //
    // The escape hatch, and the reason it is reachable over IPC as well as from
    // the panel. Nothing here can strand you — the panel scales along with
    // everything else, so its rows stay clickable — but groot has no local
    // console, and "the desktop is the wrong size" is a bad time to find that
    // the only way to fix it is to hit a target you cannot read.
    function step(delta: int): void {
        if (!root.known)
            return;
        const list = root.options;
        if (list.length === 0)
            return;

        // Nearest rather than indexOf, for the same reason the panel ticks with
        // a tolerance: the compositor reports a measured float, not the value we
        // sent it.
        let at = 0;
        for (let i = 1; i < list.length; i++) {
            if (Math.abs(list[i] - root.scale) < Math.abs(list[at] - root.scale))
                at = i;
        }

        root.apply(list[Math.max(0, Math.min(list.length - 1, at + delta))]);
    }

    // Deferred: the eval returns before the compositor has finished resizing
    // every surface, and asking mid-resize reads whichever half has landed. The
    // same reason services/Hypr.qml waits before re-reading its geometry.
    Timer {
        id: settle
        interval: 400
        onTriggered: {
            root.refresh();
            // The frame and the docked panels are measured from the
            // compositor's gaps, which are in logical pixels and therefore mean
            // something different at a new scale.
            Hypr.refreshGeometry();
        }
    }

    // --- Reading the compositor ---------------------------------------------

    function refresh(): void {
        if (!query.running)
            query.running = true;
    }

    // The focused output rather than a hardcoded HEADLESS-0. This shell is not
    // only for groot, and on a machine with a real monitor the answer is
    // whichever one you are looking at.
    Process {
        id: query

        running: true
        command: ["sh", "-c", `hyprctl monitors -j | jq -c '[.[] | select(.focused == true)][0] // .[0] // empty'`]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (raw === "") {
                    console.log("grootshell: no answer from the compositor; display scaling is unavailable");
                    return;
                }
                try {
                    const monitor = JSON.parse(raw);
                    // The name is interpolated into a Lua string in `apply`, so
                    // it is checked here rather than there — one gate, on the way
                    // in. A connector name is a connector name; anything else is
                    // not something we will quote our way out of.
                    if (!/^[A-Za-z0-9._-]+$/.test(monitor.name ?? "")) {
                        console.warn("grootshell: refusing an unsafe monitor name:", monitor.name);
                        return;
                    }
                    root.output = monitor.name;
                    root.width = monitor.width;
                    root.height = monitor.height;
                    root.refreshRate = monitor.refreshRate;
                    root.scale = monitor.scale;
                    root.known = true;
                } catch (e) {
                    console.warn("grootshell: could not read the compositor's monitors:", e);
                }
            }
        }
    }

    // Sunshine retargets the output on connect, which is the one moment the
    // resolution changes without anybody here asking. Quickshell learns the new
    // geometry through its own surface, so this fires without polling.
    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            regeometry.restart();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "monitoradded" || event.name === "monitoraddedv2" || event.name === "monitorremoved")
                regeometry.restart();
        }
    }

    Timer {
        id: regeometry
        interval: 400
        onTriggered: root.refresh()
    }

    // The state directory is ours to make: quickshell mkpaths its OWN state dir
    // before anything runs, but this file deliberately lives outside it so a
    // foreign script can find it by a stable path. Done once at startup, long
    // before any write, which only happens when somebody picks a scale.
    Component.onCompleted: mkdir.running = true

    Process {
        id: mkdir
        running: false
        command: ["mkdir", "-p", `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/grootshell`]
    }
}
