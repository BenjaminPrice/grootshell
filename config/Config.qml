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
                property bool showOnHover: false
                // Workspaces 1-5 are the desktop; 10 is where games live (see
                // groot-mode in the nixos repo). Showing 10 in the strip would
                // invite clicking into it mid-session, which is exactly what the
                // mode switch exists to do deliberately.
                property int workspaces: 5
                property bool showTray: true
                // Tray icons are images, not glyphs, and IconImage pads a
                // non-square source to fit — so they need to be a size up to
                // look level with the Material Symbols icons next to them.
                property int trayIconSize: 28
                property bool showClock: true
                property string clockFormat: "ddd d MMM  HH:mm"
            }

            component Border: JsonObject {
                // Matches gaps_out in the nixos repo's hyprland.lua. If these
                // disagree, tiled windows either overlap the frame or float
                // inside it with a dead gap.
                property int thickness: 10
                property int rounding: 25
            }

            component Island: JsonObject {
                property string defaultTab: "dashboard"
                property int width: 520
                property int height: 360
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
                property bool showOnLeft: false
            }

            component Osd: JsonObject {
                property int timeout: 1600
            }

            component Wallpaper: JsonObject {
                property string directory: `${Quickshell.env("HOME")}/Pictures/Wallpapers`
                property string current: ""
                property int thumbnailHeight: 130
            }

            component Services: JsonObject {
                // Polling intervals, in milliseconds. There is no native metrics
                // plugin here — everything comes from Process calls to ordinary
                // userspace tools — so these are a real cost, paid in encoded
                // frames as well as CPU. Slower than a local desktop would use.
                property int metricsInterval: 3000
                // Only polled while the performance tab is actually visible.
                property int sensorsInterval: 5000
                property string defaultPlayer: "YouTube Music"
                property string weatherLocation: ""
            }
        }
    }
}
