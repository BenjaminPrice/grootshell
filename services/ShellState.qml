pragma Singleton

import Quickshell
import qs.config

// What is currently open.
//
// Panels are per-screen (they live inside each screen's overlay window) but the
// commands that open them are global — a keybind says "show the launcher", not
// "show the launcher on DP-2". Keeping the state here and letting every screen
// bind to it means IPC never has to reach into a particular window, which is the
// thing that makes the handlers in shell.qml one-liners.
//
// It also survives a hot reload with the panel open, which the dev loop does
// constantly.

Singleton {
    id: root

    property bool launcher: false
    property bool translate: false
    property bool island: false
    property bool clipboard: false
    property bool notifications: false
    property bool network: false
    // The window switcher (every window, one grid) and the desktop switcher
    // (every workspace, drawn to scale). Different questions, so two panels.
    property bool switcher: false
    property bool desktops: false
    property bool keybinds: false
    property bool settings: false

    property string islandTab: Config.island.defaultTab

    // "Move the desktop switcher's selection", emitted by the SUPER+Tab IPC
    // handler and acted on by the panel.
    //
    // A signal and not a property, because the interesting case is pressing the
    // same key twice: writing 1 to a property that already holds 1 emits no
    // change, so the second tap of Tab would do nothing. A signal has no such
    // notion of being already-in-that-state.
    signal desktopStep(delta: int)

    // Only one of these can be up at a time. They all want keyboard focus and
    // they all sit in roughly the same place; two at once is visual soup and an
    // input fight. Opening one closes the rest.
    readonly property var exclusive: ["launcher", "translate", "island", "clipboard", "notifications", "network", "switcher", "desktops", "keybinds", "settings"]

    readonly property bool anyOpen: exclusive.some(n => root[n])

    function open(name: string): void {
        for (const n of root.exclusive)
            root[n] = n === name;
    }

    function close(name: string): void {
        root[name] = false;
    }

    function closeAll(): void {
        for (const n of root.exclusive)
            root[n] = false;
    }

    function toggle(name: string): void {
        if (root[name])
            root.close(name);
        else
            root.open(name);
    }
}
