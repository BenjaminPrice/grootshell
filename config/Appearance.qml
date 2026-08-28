pragma Singleton

import QtQuick
import Quickshell

// Design tokens: the numbers that make the shell look like one thing rather than
// a dozen widgets that happen to share a screen.
//
// Every group is scaled by a value from Config, because this shell is driven over
// Moonlight at whatever resolution the client asked for, which is not necessarily
// the resolution it is being *looked at*. A desk and a sofa want different sizes
// out of the same 1080p stream, and the difference should be one number in
// shell.json — which hot-reloads — rather than an edit to thirty files.
//
// Defaults are deliberately larger than a laptop shell would use. This is read
// from across a room through a video encoder, not from 60cm away.

Singleton {
    id: root

    // Config lives in the same directory, so it resolves without an import.
    // Deliberately one-way: Config knows nothing about Appearance, so there is
    // no initialisation cycle between the two singletons.

    // --- Geometry -----------------------------------------------------------

    readonly property QtObject rounding: QtObject {
        readonly property real scale: Config.appearance.roundingScale
        readonly property int small: Math.round(8 * scale)
        readonly property int normal: Math.round(14 * scale)
        readonly property int large: Math.round(22 * scale)
        // The frame's inner corner. Matches modules/border so panels that dock
        // into it share its curve rather than approximating it.
        readonly property int border: Math.round(25 * scale)
        readonly property int full: 9999
    }

    readonly property QtObject spacing: QtObject {
        readonly property real scale: Config.appearance.spacingScale
        readonly property int xs: Math.round(4 * scale)
        readonly property int sm: Math.round(8 * scale)
        readonly property int md: Math.round(12 * scale)
        readonly property int lg: Math.round(18 * scale)
        readonly property int xl: Math.round(26 * scale)
    }

    readonly property QtObject padding: QtObject {
        readonly property real scale: Config.appearance.paddingScale
        readonly property int xs: Math.round(4 * scale)
        readonly property int sm: Math.round(8 * scale)
        readonly property int md: Math.round(12 * scale)
        readonly property int lg: Math.round(16 * scale)
        readonly property int xl: Math.round(22 * scale)
    }

    // --- Type ---------------------------------------------------------------
    // Families are wrapped into the package's FONTCONFIG_FILE, so these names
    // resolve regardless of what the host has installed.

    readonly property QtObject font: QtObject {
        readonly property real scale: Config.appearance.fontScale

        readonly property QtObject family: QtObject {
            readonly property string sans: "Rubik"
            readonly property string mono: "CaskaydiaCove Nerd Font Mono"
            readonly property string icon: "Material Symbols Rounded"
        }

        readonly property QtObject size: QtObject {
            readonly property int xs: Math.round(13 * root.font.scale)
            readonly property int sm: Math.round(16 * root.font.scale)
            readonly property int md: Math.round(19 * root.font.scale)
            readonly property int lg: Math.round(24 * root.font.scale)
            readonly property int xl: Math.round(32 * root.font.scale)
            readonly property int xxl: Math.round(46 * root.font.scale)
        }
    }

    // --- Motion -------------------------------------------------------------
    //
    // Every animated frame on this host is an encoded frame pushed over the
    // network, so durations are shorter than a local desktop would want — long
    // easing reads as latency over a stream, not as polish.
    //
    // `enabled` is driven by game mode: services/GameMode.qml flips it and every
    // Behavior in the shell goes still at once.

    readonly property QtObject anim: QtObject {
        // Writable, and written by services/GameMode.qml. Not readonly like the
        // rest of these tokens because it is state, not a constant.
        property bool enabled: true
        readonly property int fast: 120
        readonly property int normal: 200
        readonly property int slow: 320

        // Recolouring the entire shell after a wallpaper change. Slower than
        // anything else here on purpose: this is the largest change the shell
        // ever makes to itself, and at panel speed a full-screen palette swap
        // reads as a flicker rather than as a transition.
        //
        // Not slower still, though. Every frame of it is a full-screen delta for
        // the encoder — the most expensive kind — so this is deliberately about
        // half of what a local desktop would use for the same effect.
        readonly property int theme: 450

        // Material's standard easing. Fast out, slow in — motion that starts
        // decisively and settles, rather than drifting at both ends.
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        readonly property var emphasised: [0.05, 0.7, 0.1, 1, 1, 1]
    }
}
