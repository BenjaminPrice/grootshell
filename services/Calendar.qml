pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Calendar events, from the .ics feed the nixos repo fetches.
//
// `grootshell-calendar` does the network and the parsing — including recurrence
// expansion, which is not something to reimplement in QML — and prints JSON.
// This polls it and shapes the result for the dashboard.
//
// Polled rather than pushed, because an .ics feed has no way to tell us it
// changed. Fifteen minutes: an agenda that is a quarter hour stale has never
// cost anyone a meeting, and the fetch crosses the network.

Singleton {
    id: root

    property var events: []
    property bool configured: false
    property string error: ""
    property bool loading: false

    // Days with something on them, as a set of "yyyy-mm-dd" keys — the shape
    // components/Calendar.qml wants for its markers. Built once per refresh
    // rather than scanned per cell.
    readonly property var eventDays: {
        const out = {};
        for (let i = 0; i < root.events.length; i++) {
            const d = new Date(root.events[i].start);
            const m = String(d.getMonth() + 1).padStart(2, "0");
            const day = String(d.getDate()).padStart(2, "0");
            out[`${d.getFullYear()}-${m}-${day}`] = true;
        }
        return out;
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // Events on a given day, in order. Returns a plain array so a ListView can
    // take it directly as a model.
    function on(day: date): var {
        const out = [];
        for (let i = 0; i < root.events.length; i++) {
            const e = root.events[i];
            if (root.sameDay(new Date(e.start), day))
                out.push(e);
        }
        return out;
    }

    // The next few things coming up, ignoring what has already finished. This is
    // what the dashboard shows when the selected day is today — "the rest of
    // today" is more useful than "today from midnight".
    function upcoming(limit: int): var {
        const now = Date.now();
        const out = [];
        for (let i = 0; i < root.events.length && out.length < limit; i++) {
            const e = root.events[i];
            if ((e.end ?? e.start) >= now)
                out.push(e);
        }
        return out;
    }

    function refresh(): void {
        if (!fetcher.running)
            fetcher.running = true;
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: fetcher
        command: ["grootshell-calendar"]
        running: false

        onRunningChanged: root.loading = fetcher.running

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.events = parsed.events ?? [];
                    root.configured = parsed.configured ?? false;
                    root.error = parsed.error ?? "";
                } catch (e) {
                    // A fetcher that printed nothing usable is a fetcher that is
                    // not there — which is the normal state before the nixos side
                    // has been rebuilt, so it is reported rather than thrown.
                    root.error = "calendar: could not read the feed";
                    root.events = [];
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("grootshell-calendar:", text.trim());
            }
        }
    }
}
