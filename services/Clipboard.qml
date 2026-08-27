pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, backed by cliphist.
//
// The store itself is filled by two `wl-paste --watch cliphist store` services
// that the nixos module runs (one for text, one for images) — a shell restart
// must not lose history, so the recorder cannot live in the shell.
//
// This is only the reader: list on open, decode on selection. cliphist's list
// format is "<id>\t<preview>", and the id is what decode wants.

Singleton {
    id: root

    readonly property alias entries: store
    property bool loading: false

    ListModel {
        id: store
    }

    function refresh(): void {
        root.loading = true;
        list.running = true;
    }

    Process {
        id: list
        running: false
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                store.clear();
                for (const line of text.split("\n")) {
                    if (!line.trim())
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const preview = line.slice(tab + 1);
                    store.append({
                        entryId: line.slice(0, tab),
                        preview: preview,
                        // cliphist represents images as a synthetic caption
                        // rather than data, so this is the only way to know one
                        // without decoding every entry up front.
                        isImage: /^\[\[\s*binary.*(png|jpe?g|bmp|webp)/i.test(preview)
                    });
                }
                root.loading = false;
            }
        }
    }

    // Decode writes the original bytes back to the clipboard. Piping through
    // wl-copy rather than reading it into QML keeps images working — they are
    // not text and would not survive the round trip.
    function copy(entryId: string): void {
        decode.command = ["bash", "-c", `cliphist decode ${JSON.stringify(entryId)} | wl-copy`];
        decode.running = true;
    }

    Process {
        id: decode
        running: false
    }

    function remove(entryId: string): void {
        wipe.command = ["bash", "-c", `cliphist decode ${JSON.stringify(entryId)} | cliphist delete`];
        wipe.running = true;
        refreshSoon.start();
    }

    function clear(): void {
        wipe.command = ["cliphist", "wipe"];
        wipe.running = true;
        refreshSoon.start();
    }

    Process {
        id: wipe
        running: false
    }

    // cliphist writes its database asynchronously; listing immediately after a
    // delete races and shows the entry still there.
    Timer {
        id: refreshSoon
        interval: 150
        onTriggered: root.refresh()
    }
}
