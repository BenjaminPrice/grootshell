pragma Singleton

import QtQuick
import Quickshell

// Known media players, and which of them this machine actually has.
//
// The media tab's launch buttons come from Config.services.mediaApps, which is a
// list of objects — a label, an icon, the desktop-entry names to try and a
// fallback command. That is a reasonable thing to keep in a config file and an
// unreasonable thing to ask someone to type into a settings panel, so the
// awkward parts live here and the panel only has to ask which ones you want.
//
// Filtered to what is installed, because a launch button that launches nothing
// is worse than no button. Detection is the same DesktopEntries lookup the media
// tab uses to start them, so anything offered here can definitely be started —
// the check and the launch cannot disagree.
//
// Flatpaks are the exception and carry a `command` as well: a Flatpak's desktop
// entry is usually present under its reverse-DNS id, but if the heuristic misses
// it there is still `flatpak run` to fall back to.

Singleton {
    id: root

    // Order matters: the first ENABLED entry is the media tab's default — what
    // the spacebar reaches and what the empty state offers first.
    readonly property var mediaCatalogue: [
        {
            id: "youtube-music",
            label: "YouTube Music",
            icon: "music_note",
            names: ["pear-desktop", "YouTube Music", "com.github.th_ch.youtube_music"],
            command: ["pear-desktop"]
        },
        {
            id: "spotify",
            label: "Spotify",
            icon: "music_note",
            names: ["spotify", "com.spotify.Client"],
            command: ["spotify"]
        },
        {
            id: "tsukimi",
            label: "Tsukimi",
            icon: "movie",
            names: ["tsukimi", "moe.tsuna.tsukimi"],
            command: ["flatpak", "run", "moe.tsuna.tsukimi"]
        },
        {
            id: "jellyfin",
            label: "Jellyfin",
            icon: "movie",
            names: ["jellyfinmediaplayer", "com.github.iwalton3.jellyfin-media-player"],
            command: ["jellyfinmediaplayer"]
        },
        {
            id: "feishin",
            label: "Feishin",
            icon: "music_note",
            names: ["feishin", "com.github.jeffvli.feishin"],
            command: ["feishin"]
        },
        {
            id: "amberol",
            label: "Amberol",
            icon: "music_note",
            names: ["amberol", "io.bassi.Amberol"],
            command: ["amberol"]
        },
        {
            id: "elisa",
            label: "Elisa",
            icon: "music_note",
            names: ["elisa", "org.kde.elisa"],
            command: ["elisa"]
        },
        {
            id: "vlc",
            label: "VLC",
            icon: "movie",
            names: ["vlc", "org.videolan.VLC"],
            command: ["vlc"]
        },
        {
            id: "mpv",
            label: "mpv",
            icon: "movie",
            names: ["mpv", "io.mpv.Mpv"],
            command: ["mpv"]
        }
    ]

    function installed(app): bool {
        for (const name of app.names ?? []) {
            try {
                if (DesktopEntries.heuristicLookup(String(name)))
                    return true;
            } catch (e)
            // heuristicLookup throws on some inputs rather than returning
            // null, and one awkward name must not hide the rest of the list.
            {}
        }
        return false;
    }

    function installedMediaApps(): var {
        const out = [];
        for (const app of root.mediaCatalogue) {
            if (root.installed(app))
                out.push(app);
        }
        return out;
    }

    // Add or remove one, preserving CATALOGUE order in the result rather than
    // the order things were clicked. Otherwise which app is the default — the
    // first in the list — would depend on the sequence of clicks that got you
    // here, which is not something anyone would predict.
    function toggleMediaApp(current: var, id: string): var {
        const enabled = {};
        for (const a of current ?? []) {
            if (a?.id)
                enabled[a.id] = true;
        }

        if (enabled[id])
            delete enabled[id];
        else
            enabled[id] = true;

        const out = [];
        for (const app of root.mediaCatalogue) {
            if (enabled[app.id])
                out.push(app);
        }
        return out;
    }
}
