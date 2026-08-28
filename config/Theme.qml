pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The palette.
//
// Every value has a compiled-in fallback AND can be overridden by
// ~/.config/grootshell/theme.json. Nothing here requires that file to exist:
// the dev loop points Quickshell at a bare checkout, and a shell that rendered
// black-on-black until something else had run would make that loop useless.
//
// DERIVED from the wallpaper, at runtime. matugen generates a Material 3 palette
// from whatever image is set and writes it here; see theming.nix in the nixos
// repo and services/Theming.qml for the trigger.
//
// The fallbacks below are that same generator's output for the default
// wallpaper, so a bare checkout with nothing generated yet looks like the real
// thing rather than like a placeholder.
//
// success and warning are NOT generated and never should be. Material 3 has no
// semantic colour for either, so a derived one is whatever the algorithm felt
// like — and "your disk is nearly full" must not change meaning with the
// wallpaper.

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

    // Whether a generated palette was actually read. services/Theming.qml uses
    // this to decide whether the wallpaper needs running through matugen on
    // startup, rather than regenerating unconditionally.
    readonly property bool loaded: Object.keys(c).length > 0

    // --- Surfaces, darkest to lightest -------------------------------------
    // Tinted toward the wallpaper's own hue rather than neutral grey — that is
    // what scheme-content buys over the default scheme, and it is the difference
    // between a dark theme and a dark theme that belongs to this image.
    readonly property color background: c.background ?? "#14121b"

    // The frame and the bar behind it. Its own token rather than reusing
    // `background`, because the two are only incidentally similar: `background`
    // is what shows when there is no wallpaper and wants to be the darkest step
    // in the ramp. The frame is a bezel drawn over a photograph, and at that
    // darkness it stops reading as part of the shell and starts reading as the
    // edge of the monitor.
    readonly property color frame: c.frame ?? "#201e27"

    readonly property color surface: c.surface ?? "#1c1a23"
    readonly property color surfaceContainer: c.surfaceContainer ?? "#201e27"
    readonly property color surfaceContainerHigh: c.surfaceContainerHigh ?? "#2b2932"
    readonly property color surfaceContainerHighest: c.surfaceContainerHighest ?? "#36333d"

    // --- Foreground ---------------------------------------------------------
    readonly property color text: c.text ?? "#e6e0ed"
    readonly property color textSecondary: c.textSecondary ?? "#c9c4d4"
    readonly property color textMuted: c.textMuted ?? "#938e9e"

    readonly property color outline: c.outline ?? "#938e9e"
    readonly property color outlineVariant: c.outlineVariant ?? "#484553"

    // --- Accent -------------------------------------------------------------
    readonly property color accent: c.accent ?? "#cbbeff"
    readonly property color accentContainer: c.accentContainer ?? "#493e76"
    readonly property color onAccent: c.onAccent ?? "#32285e"

    // --- Semantic -----------------------------------------------------------
    readonly property color success: c.success ?? "#a9d5a0"
    readonly property color warning: c.warning ?? "#e8c98a"
    readonly property color error: c.error ?? "#ffb4ab"

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
