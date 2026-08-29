pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

// MPRIS, with a preference for whatever Config.services.preferredPlayers names —
// the YouTube Music app by default rather than a browser tab.
//
// "Active player" is a judgement call when several are running. Playing beats
// paused, then the configured favourite, then whatever came first. Without the
// first rule a paused browser tab steals the media tab from music that is
// actually audible.

Singleton {
    id: root

    readonly property list<MprisPlayer> all: Mpris.players.values

    // The bus name of the last player seen actually playing. Written only from
    // the playing branch below, and only when it changes, so the binding that
    // reads it cannot chase its own tail.
    property string lastBus: ""

    // A real JS array, built by index.
    //
    // `values` arrives as a QML list, which is array-LIKE — it has length and
    // indexes — but is not an Array, and which Array.prototype methods survive
    // the wrapper is not something to bet the media tab on. The old code called
    // .filter() on it and then .find() on the result; the first happened to
    // work, and the second ran against the raw list whenever nothing was
    // playing, which is precisely the case that broke. Same reasoning as the
    // note in modules/bar/Workspaces.qml.
    function snapshot(): var {
        const out = [];
        const src = root.all;
        const n = src?.length ?? 0;
        for (let i = 0; i < n; i++) {
            if (src[i])
                out.push(src[i]);
        }
        return out;
    }

    function preferred(pool: var): var {
        // First name that matches wins, so the order in the config is the
        // preference order. Matched on Identity rather than the bus name: the
        // bus name changed when the app was renamed, and the identity is the
        // part meant to be human-readable in the first place.
        const wanted = Config.services.preferredPlayers ?? [];
        for (let i = 0; i < wanted.length; i++) {
            const needle = String(wanted[i]).toLowerCase();
            for (let j = 0; j < pool.length; j++) {
                if ((pool[j].identity ?? "").toLowerCase().includes(needle))
                    return pool[j];
            }
        }
        return pool[0];
    }

    readonly property MprisPlayer active: {
        const pool = root.snapshot();
        if (pool.length === 0)
            return null;

        const playing = [];
        for (let i = 0; i < pool.length; i++) {
            if (pool[i].playbackState === MprisPlaybackState.Playing)
                playing.push(pool[i]);
        }
        if (playing.length > 0)
            return root.preferred(playing);

        // Nothing is playing. STAY on whatever was last playing rather than
        // re-running the preference, which would hand the tab to a different
        // app the moment you pressed pause — and with two media apps
        // configured, hand it to one with nothing loaded and no way back.
        if (root.lastBus) {
            for (let i = 0; i < pool.length; i++) {
                if (pool[i].dbusName === root.lastBus)
                    return pool[i];
            }
        }

        return root.preferred(pool);
    }

    // Recorded only while playing, and only on a change. A pause therefore
    // leaves it alone, which is what makes the selection above sticky.
    onActiveChanged: {
        const a = root.active;
        if (a && a.playbackState === MprisPlaybackState.Playing && (a.dbusName ?? "") !== root.lastBus)
            root.lastBus = a.dbusName ?? "";
    }

    readonly property bool hasActive: active !== null
    readonly property bool playing: active?.playbackState === MprisPlaybackState.Playing

    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string artUrl: active?.trackArtUrl ?? ""

    // Some players report a length of 0 until the first position update, which
    // makes a progress bar jump. Treat that as "unknown" rather than "zero".
    readonly property real length: (active?.length ?? 0) > 0 ? active.length : 0
    readonly property real position: active?.position ?? 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    // Bring the playing app's own window forward. MPRIS exposes this directly,
    // which beats guessing which desktop entry a bus name belongs to — and it
    // raises the app that is ACTUALLY playing rather than whichever one the
    // shell would have launched.
    function raise(): bool {
        if (active?.canRaise) {
            active.raise();
            return true;
        }
        return false;
    }

    function playPause(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }

    function next(): void {
        if (active?.canGoNext)
            active.next();
    }

    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }

    // Position is not pushed by most players; it has to be asked for. Only while
    // something is actually playing — polling a paused player is pure waste, and
    // on this host waste is bandwidth.
    Timer {
        running: root.playing && root.hasActive
        interval: 1000
        repeat: true
        onTriggered: root.active.positionChanged()
    }

    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s.toString().padStart(2, "0")}`;
    }
}
