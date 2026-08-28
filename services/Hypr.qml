pragma Singleton

import Quickshell
import Quickshell.Hyprland

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
