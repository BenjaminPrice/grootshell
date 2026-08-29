pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Dispatching to Hyprland, in the form THIS compositor accepts.
//
// groot's Hyprland is configured through its Lua config manager, and that
// changes what `dispatch` means over IPC. The Lua manager wraps whatever it is
// given in `return hl.dispatch(<arg>)` and evaluates it, so the classic
// dispatcher syntax is no longer a command — it is a Lua expression, and a
// malformed one:
//
//     hyprctl dispatch workspace 3
//     error: [string "return hl.dispatch(workspace 3)"]:1: ')' expected near '3'
//
// Quickshell's Hyprland.dispatch() sends exactly that classic syntax, so every
// call the shell made failed silently — the clicks on the workspace strip, the
// scroll over it, and the window switcher all did nothing, with the error going
// to the compositor rather than to us. It looked like dead mouse handling.
//
// The Lua form is `hl.dsp.<name>(<table>)`. Verified against the running
// compositor rather than the docs; hl.focus reports its own valid keys when
// given a wrong one:
//
//     hl.focus: unrecognized arguments. Expected one of:
//     direction, monitor, window, urgent_or_last, last
//
// Everything that dispatches goes through here, so there is one place that
// knows this and one place to change if the compositor's config manager ever
// goes back to the classic syntax.

Singleton {
    id: root

    // --- Geometry the shell has to agree with --------------------------------
    //
    // The shell draws a frame that tiled windows must clear, and docks panels
    // level with where a window actually begins. Both of those are the
    // COMPOSITOR's numbers, and until now they were mirrored by hand in
    // Config — border.thickness against gaps_out, bar.gap against
    // gaps_out + border_size.
    //
    // They drifted, of course. thickness said 10 while gaps_out said 12, which
    // is a 2px band of wallpaper between the frame and every window, and the
    // comment claiming they matched had been wrong for as long as it had been
    // there. Asking is not merely tidier: there is no version of "write the same
    // number in two repositories" that stays true.
    //
    // Unknown until the first query answers, and the fallbacks below are what
    // the shell draws in the meantime — and permanently, on a compositor that
    // cannot be asked.
    property int gapTop: 0
    property int gapMin: 0
    property int borderSize: 0
    property bool known: false

    readonly property int fallbackThickness: 10
    readonly property int fallbackInset: 14

    // The frame band, on every side.
    //
    // The smallest of the four gaps, not the top one: the band is uniform, so a
    // window only has to overlap it on ONE side for the frame to be drawn over.
    // A positive Config.border.thickness overrides this outright, for anyone who
    // wants a frame that is deliberately not flush.
    readonly property int frameThickness: {
        if (Config.border.thickness > 0)
            return Config.border.thickness;
        return root.known ? root.gapMin : root.fallbackThickness;
    }

    // From a reserved edge to where a tiled window actually starts. The bar
    // reserves its height; the window then begins another gap plus a border
    // beyond that, and the pills float in the difference.
    readonly property int windowInset: root.known ? root.gapTop + root.borderSize : root.fallbackInset

    // Queried once at startup, and again whenever game mode flips — which is the
    // one thing on this host that changes them, since the game look sets
    // gaps_out and border_size to 0 (see groot-mode in the nixos repo).
    Process {
        id: geometry

        running: true
        command: ["sh", "-c", `
            gaps=$(hyprctl -j getoption general:gaps_out 2>/dev/null | sed -n 's/.*"css": "\\([^"]*\\)".*/\\1/p')
            border=$(hyprctl -j getoption general:border_size 2>/dev/null | sed -n 's/.*"int": \\([0-9-]*\\).*/\\1/p')
            printf '%s|%s\\n' "$gaps" "\${border:-}"
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                const rawGaps = (parts[0] ?? "").trim();
                const rawBorder = (parts[1] ?? "").trim();

                // Emptiness is checked BEFORE converting, and that is the whole
                // guard. Number("") is 0 in JavaScript, not NaN — so with no
                // hyprctl on PATH this took an empty answer for a real one,
                // declared the geometry known, and set the frame to nothing at
                // all. A shell with no frame, on exactly the machines that
                // cannot ask.
                if (rawGaps === "" || rawBorder === "") {
                    console.log("grootshell: no answer from the compositor; using built-in frame geometry");
                    return;
                }

                // gaps_out is CSS shorthand — "12 12 12 12", top right bottom
                // left — so it is four numbers even when they are all the same.
                const gaps = rawGaps.split(/\s+/).map(Number);
                const border = Number(rawBorder);

                if (gaps.length === 0 || gaps.some(isNaN) || isNaN(border)) {
                    console.log("grootshell: could not parse the compositor's geometry:", text.trim());
                    return;
                }

                // Zero IS a legitimate answer here — game mode sets both to 0 —
                // which is why it has to be told apart from no answer above
                // rather than treated as absurd.
                root.gapTop = gaps[0];
                root.gapMin = Math.min(...gaps);
                root.borderSize = border;
                root.known = true;
            }
        }
    }

    function refreshGeometry(): void {
        if (!geometry.running)
            geometry.running = true;
    }

    Connections {
        target: GameMode
        function onEnabledChanged(): void {
            // Deferred: groot-mode applies the look and flips this flag from the
            // same script, and asking mid-switch reads whichever half has
            // landed.
            regeometry.restart();
        }
    }

    Timer {
        id: regeometry
        interval: 400
        onTriggered: root.refreshGeometry()
    }

    // Raw Lua, for anything without a wrapper below.
    function lua(expr: string): void {
        Hyprland.dispatch(expr);
    }

    function focusWorkspace(id: int): void {
        root.lua(`hl.dsp.focus({ workspace = ${id} })`);
    }

    // The address is Hyprland's own window handle, and the Lua side wants it
    // prefixed the same way the classic syntax did.
    function focusWindow(address: string): void {
        if (!address)
            return;
        root.lua(`hl.dsp.focus({ window = "address:${address}" })`);
    }
}
