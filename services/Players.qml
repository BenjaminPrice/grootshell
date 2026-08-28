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

    readonly property MprisPlayer active: {
        if (all.length === 0)
            return null;

        const playing = all.filter(p => p.playbackState === MprisPlaybackState.Playing);
        const pool = playing.length > 0 ? playing : all;

        // First name that matches wins, so the order in the config is the
        // preference order. Matched on Identity rather than the bus name: the
        // bus name changed when the app was renamed, and the identity is the
        // part meant to be human-readable in the first place.
        const wanted = Config.services.preferredPlayers ?? [];
        for (let i = 0; i < wanted.length; i++) {
            const needle = String(wanted[i]).toLowerCase();
            const hit = pool.find(p => (p.identity ?? "").toLowerCase().includes(needle));
            if (hit)
                return hit;
        }

        return pool[0];
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
