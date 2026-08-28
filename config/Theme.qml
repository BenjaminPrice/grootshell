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

    // Light or dark, decided by the generator from the wallpaper's brightness
    // rather than configured. Mostly the shell does not need to ask — every
    // colour below already flipped — but anything mixing its own tone has to
    // know which way is up.
    readonly property bool isLight: (data.mode ?? "dark") === "light"

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
    // Each container comes WITH its paired foreground, and text drawn on one of
    // these fills must use its partner rather than a hand-picked colour. Material
    // 3 computes the pairing to be legible for any source colour; choosing by eye
    // works until the wallpaper is yellow. Measured on one: accent on
    // accentContainer is 1.32:1, where onAccentContainer on it is 7.09:1.
    readonly property color accent: c.accent ?? "#cbbeff"
    readonly property color accentContainer: c.accentContainer ?? "#493e76"
    readonly property color onAccent: c.onAccent ?? "#32285e"
    readonly property color onAccentContainer: c.onAccentContainer ?? "#ffffff"

    // Secondary text ON a container fill — the generic name under an app in the
    // launcher, the detail line under a network. Dimmed to keep the hierarchy
    // the muted greys give elsewhere, which those greys cannot do here because
    // they are chosen to sit on a dark surface, not a bright accent.
    //
    // 0.8, and not lower, because these are the smallest labels in the UI: at
    // 0.7 the worst-case pairing measures 3.63:1, under the 4.5:1 that small
    // text needs. Measured against a yellow wallpaper rather than picked.
    readonly property color onAccentContainerMuted: Qt.alpha(onAccentContainer, 0.8)

    // --- Semantic -----------------------------------------------------------
    readonly property color success: c.success ?? "#a9d5a0"
    readonly property color warning: c.warning ?? "#e8c98a"
    readonly property color error: c.error ?? "#ffb4ab"
    readonly property color onError: c.onError ?? "#690005"

    readonly property color shadow: c.shadow ?? "#000000"

    // Layering helper. Panels sit on the border, popouts sit on panels, and each
    // step needs to read as *above* the last without a hand-picked colour per
    // widget. Index beyond the ramp clamps rather than going out of bounds.
    function layer(level: int): color {
        const ramp = [surface, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest];
        return ramp[Math.max(0, Math.min(ramp.length - 1, level))];
    }

    // Text that stays legible on an ARBITRARY background — a tray or notification
    // icon whose colour comes from someone else's app, where there is no paired
    // role to reach for. Anything drawn on one of our own container colours
    // should use that container's partner above instead; this is the fallback for
    // colours nobody chose.
    //
    // WCAG relative luminance, not HSL lightness. HSL treats every hue as equally
    // bright, so pure blue (L=0.5) and pure yellow (L=0.5) come out the same when
    // yellow is roughly ten times more luminous — which is exactly the case that
    // was getting white text on a bright fill. Weighting the channels the way an
    // eye does puts the flip point where it belongs.
    function luminance(c: color): real {
        const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    function contrast(a: color, b: color): real {
        const la = luminance(a);
        const lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Whichever of our two extremes reads better, rather than a fixed threshold —
    // on a mid-tone neither is great and the answer is whichever is less bad.
    function on(bg: color): color {
        return contrast(text, bg) >= contrast(background, bg) ? text : background;
    }
}
