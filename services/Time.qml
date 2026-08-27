pragma Singleton

import Quickshell

// The clock.
//
// SystemClock rather than a Timer: it ticks on the minute boundary instead of
// every N seconds from whenever the shell happened to start, so the displayed
// minute changes when the minute changes. A 60s Timer drifts and updates at some
// arbitrary offset, which is visible if you ever look at it next to a real clock.
//
// Precision.Minutes, not Seconds — every tick repaints the bar, and on a streamed
// host a repaint is an encoded frame. There is no seconds display to justify 60x
// the wakeups.

Singleton {
    id: root

    readonly property alias clock: sysClock
    readonly property date now: sysClock.date

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    function format(fmt: string): string {
        return Qt.formatDateTime(root.now, fmt);
    }

    // "now", "5m", "3h", then a date. Reads `now` so it re-evaluates on every
    // tick — a relative time that never updates is worse than an absolute one,
    // because it looks live and is not.
    function since(epochMs: real): string {
        const elapsed = root.now.getTime() - epochMs;
        if (!isFinite(elapsed) || elapsed < 0)
            return "now";

        const minutes = Math.floor(elapsed / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return `${minutes}m`;

        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return `${hours}h`;

        return Qt.formatDateTime(new Date(epochMs), "d MMM");
    }
}
