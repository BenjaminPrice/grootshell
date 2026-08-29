pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Calendar events, from the .ics feeds named in the configured feed list.
//
// scripts/fetch_calendar.py does the network and the parsing — including recurrence
// expansion, which is not something to reimplement in QML — and prints JSON.
// This polls it and shapes the result for the dashboard.
//
// Polled rather than pushed, because an .ics feed has no way to tell us it
// changed. Fifteen minutes: an agenda that is a quarter hour stale has never
// cost anyone a meeting, and the fetch crosses the network.

Singleton {
    id: root

    property var events: []
    property var calendars: []
    property bool configured: false
    property string error: ""
    property bool loading: false

    // Fixed, and NOT derived from the wallpaper.
    //
    // A calendar's colour is an identity — "the green one is work" — and an
    // identity that changes with the picture behind it is not one. Same
    // reasoning as success and warning in config/Theme.qml.
    //
    // Chosen to stay distinguishable on both a light and a dark ground, since
    // the mode follows the wallpaper even though these do not.
    readonly property var palette: ["#7aa2f7", "#9ece6a", "#e0af68", "#bb9af7", "#f7768e", "#7dcfff", "#e8a2af"]

    // Config wins where it names a calendar; otherwise position in the feed
    // list decides, which is stable across polls because the fetcher preserves
    // the order of the secret.
    function colourFor(name: string): color {
        const overrides = Config.services.calendarColours ?? ({});
        if (overrides[name])
            return overrides[name];
        const i = root.calendars.indexOf(name);
        return root.palette[(i < 0 ? 0 : i) % root.palette.length];
    }

    // Day key -> the colours to mark it with, in feed order and de-duplicated.
    // components/MonthGrid.qml draws whatever it is handed and knows nothing
    // about calendars, which is what keeps it a plain month view.
    //
    // Built once per refresh rather than scanned per cell: 42 cells against a
    // month of events is small, but doing it per cell means doing it again on
    // every repaint.
    readonly property var eventDays: {
        const out = {};
        for (let i = 0; i < root.events.length; i++) {
            const e = root.events[i];
            const d = new Date(e.start);
            const m = String(d.getMonth() + 1).padStart(2, "0");
            const day = String(d.getDate()).padStart(2, "0");
            const key = `${d.getFullYear()}-${m}-${day}`;
            const colour = String(root.colourFor(e.calendar ?? ""));
            if (!out[key])
                out[key] = [];
            if (out[key].indexOf(colour) < 0)
                out[key].push(colour);
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

    // Prefer a `grootshell-calendar` on PATH, and fall back to the script this
    // repo ships beside shell.qml. The packaged wrapper brings its own Python
    // environment — icalendar and recurring-ical-events — which a bare checkout
    // cannot assume; the fallback is what makes the agenda work without it.
    readonly property string script: `${Quickshell.shellDir}/scripts/fetch_calendar.py`

    Process {
        id: fetcher
        command: ["sh", "-c", 'if command -v grootshell-calendar >/dev/null 2>&1; then exec grootshell-calendar; else exec python3 "$0"; fi', root.script]
        running: false

        onRunningChanged: root.loading = fetcher.running

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    // calendars BEFORE events: colourFor reads the list, and
                    // eventDays recomputes the moment events changes.
                    root.calendars = parsed.calendars ?? [];
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
