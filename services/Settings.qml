pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Writing to shell.json, one key at a time.
//
// config/Config.qml only ever READS. That is deliberate and this service exists
// to keep it that way, because the obvious alternative is a trap:
//
//   JsonAdapter.writeAdapter() does not serialise your settings. It serialises
//   the WHOLE adapter, defaults and all.
//
// Changing one value and calling it produced this, from a five-key test adapter:
//
//   { "bar": { "clockFormat": "ddd d MMM  HH:mm", "height": 60, "showTray": true },
//     "launcher": { "maxResults": 8, "width": 620 } }
//
// Four of those were never chosen by anyone. The file now asserts that
// launcher.width is 620 — so if that default later becomes 700 because the
// launcher grew a column, this user never gets it, for a value they never set,
// in a section they never opened. Every interaction with a settings panel would
// freeze the entire config surface at that moment, and anyone who nudged one
// slider on their first day would be pinned to day-one defaults forever.
//
// So this does a read-modify-write of the raw JSON instead. Keys the user has
// not touched stay ABSENT from the file, and absent means "follow the default",
// which is the only way an upstream default can ever reach anyone.
//
// The file is re-read immediately before each write rather than kept in memory.
// It is hand-editable and hot-reloaded, so anything cached here is a guess about
// what is on disk — and the failure mode of guessing wrong is silently reverting
// an edit somebody made in a text editor.

Singleton {
    id: root

    readonly property string path: `${Config.configDir}/shell.json`

    // Set only while a write is in flight, so a settings panel can show that it
    // is saving without inventing its own state.
    property bool saving: false

    property FileView file: FileView {
        id: file

        path: root.path
        // Not watched. Config already watches this file and applies changes; a
        // second watcher here would only be for our own writes coming back.
        printErrors: false

        // BOTH block, and that is the entire correctness of this service.
        //
        // Every operation here is read-modify-write. Left asynchronous, `read()`
        // after a `set()` returns the file as it was BEFORE the write landed —
        // so setting a second key builds on a stale document and the write that
        // follows silently drops the first one. Which is precisely the
        // clobbering this whole service exists to prevent, reproduced inside it:
        // the test wrote bar.height, read back {}, and lost it.
        //
        // The cost is a blocking read and write of a file with a handful of keys
        // in it, on a code path that only runs when a human changes a setting.
        blockLoading: true
        blockWrites: true

        // Written whole, so a crash mid-write must not leave a truncated file
        // that Config then fails to parse — which would drop every setting at
        // once, including the ones that were fine.
        atomicWrites: true
    }

    // The file as an object. Missing or unparseable both read as empty, which is
    // the same thing as "nothing overridden".
    //
    // Unparseable deliberately does NOT throw the contents away: the caller sets
    // one key on this and writes it back, so a file we cannot read would be
    // silently replaced by a file with one key in it. Returning null lets `set`
    // refuse instead.
    function read(): var {
        file.reload();
        const raw = file.text();
        if (!raw || raw.trim() === "")
            return ({});
        try {
            const parsed = JSON.parse(raw);
            // A JSON document can legally be a number or a list. Anything that
            // is not an object is not our file.
            return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : null;
        } catch (e) {
            return null;
        }
    }

    // `set("bar.height", 60)` — a dotted path, so callers name the setting the
    // same way they read it. Intermediate objects are created as needed.
    function set(key: string, value: var): bool {
        const doc = root.read();
        if (doc === null) {
            console.warn("grootshell: refusing to write shell.json, which is not readable as JSON — fix or remove it first");
            return false;
        }

        const parts = key.split(".").filter(p => p !== "");
        if (parts.length === 0)
            return false;

        let node = doc;
        for (let i = 0; i < parts.length - 1; i++) {
            const p = parts[i];
            if (typeof node[p] !== "object" || node[p] === null || Array.isArray(node[p]))
                node[p] = ({});
            node = node[p];
        }
        node[parts[parts.length - 1]] = value;

        return root.write(doc);
    }

    // Remove an override, so the key goes back to following the shipped default.
    // A settings panel needs this as much as it needs `set` — without it, "reset
    // to default" can only write today's default as a permanent override, which
    // is the very thing this service exists to avoid.
    function unset(key: string): bool {
        const doc = root.read();
        if (doc === null)
            return false;

        const parts = key.split(".").filter(p => p !== "");
        if (parts.length === 0)
            return false;

        // Walk to the parent, giving up if the path does not exist — there is
        // nothing to remove and no reason to rewrite the file.
        const chain = [doc];
        let node = doc;
        for (let i = 0; i < parts.length - 1; i++) {
            const next = node[parts[i]];
            if (typeof next !== "object" || next === null)
                return true;
            node = next;
            chain.push(node);
        }
        if (!(parts[parts.length - 1] in node))
            return true;
        delete node[parts[parts.length - 1]];

        // Prune sections that are now empty, so removing the only override in a
        // group does not leave `"bar": {}` behind. A file that accumulates empty
        // objects is one nobody will believe is "no overrides".
        for (let i = chain.length - 1; i > 0; i--) {
            if (Object.keys(chain[i]).length > 0)
                break;
            delete chain[i - 1][parts[i - 1]];
        }

        return root.write(doc);
    }

    function write(doc: var): bool {
        root.saving = true;
        // Two-space indent and a trailing newline: this file is meant to be
        // opened in an editor, and a settings panel should not turn it into one
        // long line the moment it is used.
        file.setText(JSON.stringify(doc, null, 2) + "\n");
        root.saving = false;
        return true;
    }

    // Whether a key currently has an override, for a panel that wants to show
    // which settings differ from the defaults.
    function has(key: string): bool {
        const doc = root.read();
        if (doc === null)
            return false;
        let node = doc;
        for (const p of key.split(".").filter(p => p !== "")) {
            if (typeof node !== "object" || node === null || !(p in node))
                return false;
            node = node[p];
        }
        return true;
    }
}
