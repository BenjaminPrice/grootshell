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

    // At most this many. The media tab shows them as a row of launch buttons in
    // an empty state, and past three that row stops reading as "pick one" and
    // starts reading as a menu. Fewer is entirely fine — two is what this
    // machine has run for months.
    readonly property int maxMediaApps: 3

    // Order matters: the first ENABLED entry is the media tab's default — what
    // the spacebar reaches and what the empty state offers first.
    //
    // `kind` is shown beside the name rather than used for filtering. Someone
    // may well want music, video and audiobooks, or two video players for local
    // files and for streaming — the point is to say what each one is, not to
    // decide for anybody which combination makes sense.
    //
    // Flatpaks carry a `command` as well: their desktop entry is usually present
    // under the reverse-DNS id, but if the heuristic misses it there is still
    // `flatpak run` to fall back to.
    readonly property var mediaCatalogue: [
        {
            id: "youtube-music",
            label: "YouTube Music",
            kind: "music",
            icon: "music_note",
            names: ["pear-desktop", "YouTube Music", "com.github.th_ch.youtube_music"],
            command: ["pear-desktop"]
        },
        {
            id: "spotify",
            label: "Spotify",
            kind: "music",
            icon: "music_note",
            names: ["spotify", "com.spotify.Client"],
            command: ["spotify"]
        },
        {
            id: "tidal",
            label: "TIDAL",
            kind: "music",
            icon: "music_note",
            names: ["tidal-hifi", "com.mastermindzh.tidal-hifi"],
            command: ["tidal-hifi"]
        },
        {
            id: "feishin",
            label: "Feishin",
            kind: "music",
            icon: "music_note",
            names: ["feishin", "com.github.jeffvli.feishin"],
            command: ["feishin"]
        },
        {
            id: "supersonic",
            label: "Supersonic",
            kind: "music",
            icon: "music_note",
            names: ["supersonic", "io.github.dweymouth.supersonic"],
            command: ["supersonic"]
        },
        {
            id: "strawberry",
            label: "Strawberry",
            kind: "music",
            icon: "music_note",
            names: ["strawberry", "org.strawberrymusicplayer.strawberry"],
            command: ["strawberry"]
        },
        {
            id: "amberol",
            label: "Amberol",
            kind: "music",
            icon: "music_note",
            names: ["amberol", "io.bassi.Amberol"],
            command: ["amberol"]
        },
        {
            id: "elisa",
            label: "Elisa",
            kind: "music",
            icon: "music_note",
            names: ["elisa", "org.kde.elisa"],
            command: ["elisa"]
        },
        {
            id: "rhythmbox",
            label: "Rhythmbox",
            kind: "music",
            icon: "music_note",
            names: ["rhythmbox", "org.gnome.Rhythmbox3"],
            command: ["rhythmbox"]
        },
        {
            id: "tsukimi",
            label: "Tsukimi",
            kind: "video",
            icon: "movie",
            names: ["tsukimi", "moe.tsuna.tsukimi"],
            command: ["flatpak", "run", "moe.tsuna.tsukimi"]
        },
        {
            id: "jellyfin",
            label: "Jellyfin",
            kind: "video",
            icon: "movie",
            names: ["jellyfinmediaplayer", "com.github.iwalton3.jellyfin-media-player"],
            command: ["jellyfinmediaplayer"]
        },
        {
            id: "plex",
            label: "Plex",
            kind: "video",
            icon: "movie",
            names: ["plex-desktop", "plexmediaplayer", "tv.plex.PlexDesktop"],
            command: ["plex-desktop"]
        },
        {
            id: "stremio",
            label: "Stremio",
            kind: "video",
            icon: "movie",
            names: ["stremio", "com.stremio.Stremio"],
            command: ["stremio"]
        },
        {
            id: "kodi",
            label: "Kodi",
            kind: "video",
            icon: "movie",
            names: ["kodi", "tv.kodi.Kodi"],
            command: ["kodi"]
        },
        {
            id: "celluloid",
            label: "Celluloid",
            kind: "video",
            icon: "movie",
            names: ["celluloid", "io.github.celluloid_player.Celluloid"],
            command: ["celluloid"]
        },
        {
            id: "haruna",
            label: "Haruna",
            kind: "video",
            icon: "movie",
            names: ["haruna", "org.kde.haruna"],
            command: ["haruna"]
        },
        {
            id: "vlc",
            label: "VLC",
            kind: "video",
            icon: "movie",
            names: ["vlc", "org.videolan.VLC"],
            command: ["vlc"]
        },
        {
            id: "mpv",
            label: "mpv",
            kind: "video",
            icon: "movie",
            names: ["mpv", "io.mpv.Mpv"],
            command: ["mpv"]
        },
        {
            id: "cozy",
            label: "Cozy",
            kind: "audiobooks",
            icon: "menu_book",
            names: ["com.github.geigi.cozy", "cozy"],
            command: ["com.github.geigi.cozy"]
        },
        {
            id: "audiobookshelf",
            label: "Audiobookshelf",
            kind: "audiobooks",
            icon: "menu_book",
            names: ["audiobookshelf-app", "com.audiobookshelf.app"],
            command: ["audiobookshelf-app"]
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

    // How many are currently chosen, for a panel that wants to say so.
    function chosenCount(current: var): int {
        let n = 0;
        for (const a of current ?? []) {
            if (a?.id)
                n++;
        }
        return n;
    }

    // Add or remove one, preserving CATALOGUE order in the result rather than
    // the order things were clicked. Otherwise which app is the default — the
    // first in the list — would depend on the sequence of clicks that got you
    // here, which is not something anyone would predict.
    //
    // Refuses to add past the cap rather than silently dropping the oldest.
    // Quietly evicting something the person chose, to make room for something
    // else they chose, is the kind of helpfulness nobody asks for; the panel
    // greys out the rest and says why instead.
    function toggleMediaApp(current: var, id: string): var {
        const enabled = {};
        for (const a of current ?? []) {
            if (a?.id)
                enabled[a.id] = true;
        }

        if (enabled[id]) {
            delete enabled[id];
        } else {
            if (Object.keys(enabled).length >= root.maxMediaApps)
                return current ?? [];
            enabled[id] = true;
        }

        const out = [];
        for (const app of root.mediaCatalogue) {
            if (enabled[app.id])
                out.push(app);
        }
        return out;
    }
}
