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
}
