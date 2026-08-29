pragma Singleton

import Quickshell
import Quickshell.Io

// User configuration, read from ~/.config/grootshell/shell.json and watched for
// changes. Everything has a default, so the file is entirely optional.
//
// This is the pure-QML answer to caelestia's C++ config plugin. JsonObject gives
// typed, nested, live-reloading settings for the cost of a few declarations —
// which is the single biggest reason this shell does not need a 17k-line native
// plugin behind it.

Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`) + "/grootshell"

    property alias appearance: adapter.appearance
    property alias bar: adapter.bar
    property alias border: adapter.border
    property alias island: adapter.island
    property alias launcher: adapter.launcher
    property alias notifications: adapter.notifications
    property alias osd: adapter.osd
    property alias wallpaper: adapter.wallpaper
    property alias services: adapter.services
    property alias weather: adapter.weather

    FileView {
        path: `${root.configDir}/shell.json`
        watchChanges: true
        blockLoading: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter

            // Type is Scaling, not Appearance: an inline component named
            // Appearance would shadow the Appearance singleton next door, which
            // is exactly the thing reading these values back.
            property Scaling appearance: Scaling {}
            property Bar bar: Bar {}
            property Border border: Border {}
            property Island island: Island {}
            property Launcher launcher: Launcher {}
            property Notifications notifications: Notifications {}
            property Osd osd: Osd {}
            property Wallpaper wallpaper: Wallpaper {}
            property Services services: Services {}
            property Weather weather: Weather {}

            // Global size multipliers, read by config/Appearance.qml. This is
            // the knob for "I am on the sofa, not at the desk" — bump fontScale
            // and everything grows together. Hot-reloads, so it can be tuned
            // against a live stream rather than guessed at.
            component Scaling: JsonObject {
                property real fontScale: 1.0
                property real roundingScale: 1.0
                property real spacingScale: 1.0
                property real paddingScale: 1.0
            }

            component Bar: JsonObject {
                // Tall enough for the type above at scale 1. Raising fontScale
                // does not raise this, so bump both together if you want a
                // bigger bar rather than a cramped one.
                property int height: 54
                // Workspaces 1-5 are the desktop; 10 is where games live (see
                // groot-mode in the nixos repo). Showing 10 in the strip would
                // invite clicking into it mid-session, which is exactly what the
                // mode switch exists to do deliberately.
                property int workspaces: 5
                property bool showTray: true

                // The two network indicators, and the panels behind them.
                //
                // Separate, because one icon cannot show two connections: it has
                // to choose what it is reporting, and whatever it chooses, the
                // other has no way to be seen. Wired answers "what is my
                // address"; wifi joins, forgets and switches the radio.
                //
                // Both off by default because the machine this was built on is
                // wired and has never been anything else, so even the wired icon
                // would report a fact that cannot change. Turn on whichever
                // matches how your machine is actually connected — for most
                // people that is wifi, and for a desktop it may be both.
                property bool showEthernet: false
                property bool showWifi: false
                // Tray icons are images, not glyphs, and IconImage pads a
                // non-square source to fit — so they need to be a size up to
                // look level with the Material Symbols icons next to them.
                property int trayIconSize: 28
                property bool showClock: true
                property string clockFormat: "ddd d MMM  HH:mm"

                // Every pill is exactly this tall.
                //
                // One number rather than each capsule sizing to its own
                // contents: a row of pills whose heights follow their text is a
                // row of subtly different objects, and the eye reads that as
                // sloppy long before it works out why. The workspace track is
                // the tallest thing up here — a slot plus its padding — so this
                // is that, and everything else is padded out to match.
                property int pillHeight: 40

                // Tray items that publish no Activate method, mapped to what
                // left-clicking them should do instead.
                //
                // Left-click is meant to call Activate over D-Bus, and a
                // well-behaved item that has no primary action says so by
                // setting ItemIsMenu. Steam does neither: introspecting its item
                // shows SecondaryActivate, XAyatanaSecondaryActivate and Scroll,
                // and no Activate at all — so the call went nowhere and the icon
                // looked dead until you right-clicked it.
                //
                // Keyed on the item's id. A map rather than a special case in
                // the bar, because Steam will not be the last application to
                // ship a half-implemented tray icon.
                property var trayFallback: ({
                        steam: ["steam", "steam://open/games"]
                    })
            }

            component Border: JsonObject {
                // 0 means "however thick the compositor's gaps are", which is
                // the only answer that is always right: the frame has to fit
                // inside the space Hyprland already leaves around a window, and
                // that number lives in the compositor's config.
                //
                // It used to be mirrored here — and said 10 while gaps_out said
                // 12, so there was a 2px band of wallpaper between the frame and
                // every window, and the comment claiming they matched had been
                // wrong for as long as it had been there. services/Hypr.qml asks
                // now.
                //
                // A positive value overrides that, for a frame deliberately
                // thinner than the gap. Thicker will be drawn over by windows.
                property int thickness: 0
                property int rounding: 25

                // How far tiled windows are held off the frame, on the sides and
                // the bottom. -1 means "the compositor's gaps_in", which is what
                // makes the frame behave like just another neighbouring window:
                // two tiled windows sit 2 x gaps_in apart, so each keeps gaps_in
                // to the line between them, and this keeps the same to the frame.
                //
                // Without it a window sits flush against the frame — gaps_out IS
                // the frame's thickness, so the two meet exactly — and the
                // frame's rounded inner corners cut across the window's own.
                //
                // 0 is a real value meaning no padding, which is why "follow the
                // compositor" has to be -1 here rather than 0 as it is above.
                property int padding: -1
            }

            component Island: JsonObject {
                // Which tab it opens on. There is no width or height here: the
                // island sizes itself per tab, so one pair of numbers could only
                // ever be wrong for four of the five.
                property string defaultTab: "dashboard"
            }

            component Launcher: JsonObject {
                property int maxResults: 8
                property int width: 620
                // Actions typed as a prefix rather than a mode switch: `>` runs
                // a command, `=` calculates.
                property string commandPrefix: ">"
                property string mathPrefix: "="
            }

            component Notifications: JsonObject {
                property int expireTimeout: 5000
                property int maxVisible: 4
            }

            component Osd: JsonObject {
                property int timeout: 1600
            }

            component Wallpaper: JsonObject {
                property string directory: `${Quickshell.env("HOME")}/Pictures/Wallpapers`
                // Which wallpaper is current is NOT here — it is runtime state,
                // and lives in services/Persist.qml. See the note there.
            }

            // Open-Meteo, which needs no API key. That is not a convenience —
            // it is what makes the forecast work for anyone who clones this
            // repo. A shell that asks every user to register for a key before
            // the weather tab does anything is a shell nobody else runs.
            component Weather: JsonObject {
                // A place name, geocoded on first use: "Osaka", "Osaka, Japan",
                // "Shinjuku". Empty by default and deliberately so — there is no
                // sensible guess, and a wrong city shown confidently is worse
                // than a panel that says where to set it.
                property string location: ""

                // "metric" or "imperial". Passed straight through to the API,
                // which does the conversion, so there is no unit arithmetic on
                // this side to get wrong.
                property string units: "metric"

                // Open-Meteo allows up to 16. Ten fits the tab without the rows
                // becoming a wall, and the last few days of any forecast are
                // closer to climate than weather anyway.
                property int days: 10

                // The upstream model updates hourly, so polling faster than this
                // asks a free service for a number that has not changed.
                property int updateMinutes: 15
            }

            component Services: JsonObject {
                // Polling intervals, in milliseconds. There is no native metrics
                // plugin here — everything comes from Process calls to ordinary
                // userspace tools — so these are a real cost, paid in encoded
                // frames as well as CPU. Slower than a local desktop would use.
                property int metricsInterval: 3000
                // Substrings matched against an MPRIS player's Identity, in
                // order, first hit wins. A list rather than one name because the
                // YouTube Music desktop app was renamed — th-ch/youtube-music is
                // now pear-devs/pear-desktop — and which string the app reports
                // is its own business, not something to pin a rebuild on.
                property var preferredPlayers: ["youtube music", "pear", "tsukimi"]

                // What the media tab offers to start when nothing is playing,
                // in order — the first is the default and the one a keypress
                // reaches.
                //
                // `names` are tried against the desktop entry database first, so
                // the app starts with the environment its packager intended;
                // `command` is the fallback for anything with no entry to find.
                // Entries carry an `id` matching services/SettingsCatalogue.qml.
                //
                // The settings panel identifies a chosen app by that id, so a
                // default without one is a default the panel cannot see: it read
                // "0 of 3 chosen" while two were plainly configured, and ticking
                // either would have replaced rather than recognised it.
                property var mediaApps: [
                    {
                        id: "youtube-music",
                        label: "YouTube Music",
                        kind: "music",
                        icon: "music_note",
                        names: ["pear-desktop", "YouTube Music", "com.github.th-ch.youtube-music"],
                        command: ["pear-desktop"]
                    },
                    {
                        id: "tsukimi",
                        label: "Tsukimi",
                        kind: "video",
                        icon: "movie",
                        // A Flatpak, so there is no bare binary to fall back to.
                        command: ["flatpak", "run", "moe.tsuna.tsukimi"],
                        names: ["tsukimi", "moe.tsuna.tsukimi"]
                    }
                ]

                // Calendar name -> colour, overriding the built-in palette.
                // Names are whatever the secret labels a feed, or the feed's own
                // X-WR-CALNAME if it was left unlabelled. Colours live here and
                // NOT in the secret: a colour is not sensitive, and changing one
                // should not mean decrypting a file.
                //   { "Work": "#7aa2f7", "Family": "#9ece6a" }
                property var calendarColours: ({})

                // Which Theme role the media tab's spectrum ring is drawn in.
                //
                // A role name rather than a colour, so whatever you pick still
                // follows the wallpaper — the point of the ring is that it
                // belongs to the artwork it surrounds, and a fixed hex would be
                // the one thing on that panel ignoring the scheme. "accent" is
                // the automatic answer and what it has always been.
                property string waveformColour: "accent"
            }
        }
    }
}
