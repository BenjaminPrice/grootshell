pragma Singleton

import Quickshell
import Quickshell.Io

// Runtime state that has to survive a restart.
//
// Deliberately NOT in shell.json. That file is the user's, and writing the
// config adapter back would serialise every default in it — every colour, every
// size, everything the shell has an opinion about — freezing them at whatever
// they happened to be on the day it was written. A later change to a default
// would then silently not apply, because the file now says otherwise. Config is
// read; state is written; they do not share a file.
//
// Quickshell.stateDir is ~/.local/state/quickshell/by-shell/<shellId>, and
// quickshell mkpaths it before anything runs, so there is no directory to
// create. It is keyed on the shell id — which shell.qml pins to "grootshell"
// via a pragma — so it stays put rather than moving when the QML is loaded from
// a dev checkout instead of the store.
//
// Not watched. We are the only writer, and pairing a file watcher with a
// write-on-change handler is how you get a loop that rewrites the file forever.

Singleton {
    id: root

    property alias wallpaper: adapter.wallpaper

    FileView {
        path: `${Quickshell.stateDir}/state.json`
        // Absent on first run, which is normal rather than an error.
        blockLoading: false
        printErrors: false

        // Persist on every change. State here is a handful of values that change
        // when a human does something, so there is nothing to debounce.
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            // Absolute path of the current wallpaper. Empty means "not chosen
            // yet"; services/Wallpapers.qml then picks the first it finds.
            property string wallpaper: ""
        }
    }
}
