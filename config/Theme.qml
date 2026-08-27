pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The palette.
//
// Every value has a compiled-in fallback AND can be overridden by
// ~/.config/grootshell/theme.json. That file is expected to be generated from
// Nix — the same definition that feeds Stylix, so GTK, Qt, the terminal and this
// shell all agree — but nothing here requires it to exist.
//
// The fallbacks are not a nicety: the dev loop points Quickshell at a bare
// checkout, and a shell that renders black-on-black until a Nix rebuild has run
// would make that loop useless. Standalone must look correct.
//
// Deliberately NOT derived from the wallpaper. Wallpaper-driven schemes are
// lovely on a laptop and wrong here: the palette also drives GTK and Qt through
// Stylix, which are build-time, so a scheme that drifted at runtime would leave
// the shell and the applications disagreeing. Wallpaper and palette are separate
// concerns.

Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`) + "/grootshell"

    property var themeFile: FileView {
        path: `${root.configDir}/theme.json`
        watchChanges: true
        // Non-blocking: a missing file is the normal case for a fresh checkout,
        // not an error, and blocking would stall startup waiting for it.
        blockLoading: false
        onFileChanged: reload()
    }

    readonly property var data: {
        if (!themeFile.loaded)
            return ({});
        try {
            return JSON.parse(themeFile.text());
        } catch (e) {
            console.warn("grootshell: theme.json is not valid JSON, using defaults:", e);
            return ({});
        }
    }

    readonly property var c: data.colours ?? data.colors ?? ({})

    // --- Surfaces, darkest to lightest -------------------------------------
    // A near-black with a green cast rather than a neutral grey. Against the
    // teal accent below it reads as one material lit from somewhere, which flat
    // #000 does not.
    readonly property color background: c.background ?? "#0a0f0f"

    // The frame and the bar behind it. Its own token rather than reusing
    // `background`, because the two are only incidentally similar: `background`
    // is what you see when there is no wallpaper, and wants to be as close to
    // black as the palette goes. The frame is a physical-looking bezel drawn
    // over a photograph, and at true black it stops reading as part of the shell
    // and starts reading as the edge of the monitor.
    readonly property color frame: c.frame ?? "#151f1e"

    readonly property color surface: c.surface ?? "#0e1514"
    readonly property color surfaceContainer: c.surfaceContainer ?? "#131b1a"
    readonly property color surfaceContainerHigh: c.surfaceContainerHigh ?? "#192120"
    readonly property color surfaceContainerHighest: c.surfaceContainerHighest ?? "#1d2827"

    // --- Foreground ---------------------------------------------------------
    readonly property color text: c.text ?? "#dce8e6"
    readonly property color textSecondary: c.textSecondary ?? "#a2adac"
    readonly property color textMuted: c.textMuted ?? "#6d7876"

    readonly property color outline: c.outline ?? "#3f4a49"
    readonly property color outlineVariant: c.outlineVariant ?? "#2a3433"

    // --- Accent -------------------------------------------------------------
    readonly property color accent: c.accent ?? "#9bd0cc"
    readonly property color accentContainer: c.accentContainer ?? "#255b58"
    readonly property color onAccent: c.onAccent ?? "#0d4845"

    // --- Semantic -----------------------------------------------------------
    readonly property color success: c.success ?? "#a9d5a0"
    readonly property color warning: c.warning ?? "#e8c98a"
    readonly property color error: c.error ?? "#f2b8b5"

    readonly property color shadow: c.shadow ?? "#000000"

    // Layering helper. Panels sit on the border, popouts sit on panels, and each
    // step needs to read as *above* the last without a hand-picked colour per
    // widget. Index beyond the ramp clamps rather than going out of bounds.
    function layer(level: int): color {
        const ramp = [surface, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest];
        return ramp[Math.max(0, Math.min(ramp.length - 1, level))];
    }

    // Text that stays legible on an arbitrary background. Used by the tray and
    // notification icons, where the colour comes from someone else's app.
    function on(bg: color): color {
        return bg.hslLightness > 0.5 ? background : text;
    }
}
