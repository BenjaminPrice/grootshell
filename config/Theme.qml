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
//
// ## Why every role animates
//
// A new wallpaper rewrites this whole palette at once, and without a Behavior the
// entire shell changes colour between two frames — every surface, every label,
// the frame, the bar. That reads as a glitch rather than as a change, because
// nothing physical recolours instantaneously.
//
// So each role eases independently. They all start and finish together, which
// makes the shell look like one object being lit differently rather than like
// thirty widgets repainted in the same instant. Cross-fading a rendered SNAPSHOT
// is the other way to do this and is worse here: it needs the whole shell in a
// layer, which on a host that encodes every frame for the network costs an extra
// full-screen texture per frame for the duration.
//
// None of these can be `readonly` as a result. A Behavior animates WRITES, and a
// read-only property is never written — it is re-evaluated — so a Behavior on one
// is a load-time error that takes the shell down with it. scripts/qml-audit.py
// has a rule for precisely that mistake.

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

    // --- The transition -----------------------------------------------------
    //
    // Off until the shell has settled. The first palette arrives a few
    // milliseconds after startup, when theme.json is read, and animating THAT
    // would mean every launch — and every reload of the dev loop, which happens
    // constantly — opens with a half-second colour wash from the compiled-in
    // fallbacks to the real thing. A change is worth animating; an arrival is
    // not.
    //
    // A plain timer rather than a hook on the first successful read, because
    // "first read" is not one event: the file may be absent at startup and
    // written a second later by the generator, and the two cases want the same
    // answer. Anything after the shell has been up for a moment is a change.
    property bool animate: false

    Timer {
        // Comfortably past the FileView's first read, and past the 1500ms
        // startup generation in services/Theming.qml only if that one is
        // skipped — a palette generated because none existed SHOULD ease in,
        // since by then there is something on screen to ease from.
        interval: 800
        running: true
        onTriggered: root.animate = true
    }

    // Gate for every Behavior below. Game mode stills the shell, and a wallpaper
    // change during a game should land instantly rather than spend half a second
    // of encoded frames on a fade nobody is watching.
    readonly property bool easing: root.animate && Appearance.anim.enabled

    // --- Surfaces, darkest to lightest -------------------------------------
    // Tinted toward the wallpaper's own hue rather than neutral grey — that is
    // what scheme-content buys over the default scheme, and it is the difference
    // between a dark theme and a dark theme that belongs to this image.
    property color background: c.background ?? "#14121b"

    Behavior on background {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    // The frame and the bar behind it. Its own token rather than reusing
    // `background`, because the two are only incidentally similar: `background`
    // is what shows when there is no wallpaper and wants to be the darkest step
    // in the ramp. The frame is a bezel drawn over a photograph, and at that
    // darkness it stops reading as part of the shell and starts reading as the
    // edge of the monitor.
    property color frame: c.frame ?? "#201e27"

    Behavior on frame {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color surface: c.surface ?? "#1c1a23"

    Behavior on surface {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color surfaceContainer: c.surfaceContainer ?? "#201e27"

    Behavior on surfaceContainer {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color surfaceContainerHigh: c.surfaceContainerHigh ?? "#2b2932"

    Behavior on surfaceContainerHigh {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color surfaceContainerHighest: c.surfaceContainerHighest ?? "#36333d"

    Behavior on surfaceContainerHighest {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    // --- Foreground ---------------------------------------------------------
    property color text: c.text ?? "#e6e0ed"

    Behavior on text {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color textSecondary: c.textSecondary ?? "#c9c4d4"

    Behavior on textSecondary {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color textMuted: c.textMuted ?? "#938e9e"

    Behavior on textMuted {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color outline: c.outline ?? "#938e9e"

    Behavior on outline {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color outlineVariant: c.outlineVariant ?? "#484553"

    Behavior on outlineVariant {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    // --- Accent -------------------------------------------------------------
    // Each container comes WITH its paired foreground, and text drawn on one of
    // these fills must use its partner rather than a hand-picked colour. Material
    // 3 computes the pairing to be legible for any source colour; choosing by eye
    // works until the wallpaper is yellow. Measured on one: accent on
    // accentContainer is 1.32:1, where onAccentContainer on it is 7.09:1.
    property color accent: c.accent ?? "#cbbeff"

    Behavior on accent {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color accentContainer: c.accentContainer ?? "#493e76"

    Behavior on accentContainer {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color onAccent: c.onAccent ?? "#32285e"

    Behavior on onAccent {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color onAccentContainer: c.onAccentContainer ?? "#ffffff"

    Behavior on onAccentContainer {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

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
    //
    // These ease too, even though success and warning are fixed per mode rather
    // than derived. They still change when the mode flips, and a green that
    // snaps while every surface around it fades is the one thing on screen that
    // looks broken.
    property color success: c.success ?? "#a9d5a0"

    Behavior on success {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color warning: c.warning ?? "#e8c98a"

    Behavior on warning {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color error: c.error ?? "#ffb4ab"

    Behavior on error {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    property color onError: c.onError ?? "#690005"

    Behavior on onError {
        enabled: root.easing
        ColorAnimation {
            duration: Appearance.anim.theme
        }
    }

    // Not animated: it is black in every palette this generator produces, and a
    // shadow is the one thing whose job is to be unnoticed.
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
