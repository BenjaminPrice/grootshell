pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Regenerates the colour scheme from the wallpaper.
//
// The shell decides WHEN because the shell is what knows the wallpaper changed;
// Nix decides WHAT, owning matugen and the templates that turn its Material 3
// palette into each consumer's config format. See theming.nix in the nixos repo.
//
// Nothing here reads a colour. The generator writes theme.json, config/Theme.qml
// is already watching that file, and the shell recolours itself on the next
// frame. Which is why this service can be this small.

Singleton {
    id: root

    property bool running: generator.running

    // Guards against regenerating from the same image twice — the binding below
    // fires on any assignment, and the wallpaper service reasserts `current`
    // when the folder model reloads.
    //
    // Set only on a SUCCESSFUL run, never optimistically at launch. Recording
    // the attempt instead of the result means one failure is permanent: the
    // wallpaper is already marked done, so re-picking it is deduped away and
    // the only route back is a restart. A failed generation must leave no trace.
    property string lastGenerated: ""

    // The image the in-flight run is for, promoted to lastGenerated on exit 0.
    property string pending: ""

    // Forced regeneration, ignoring the dedupe — for the IPC handler, and for
    // any case where the file on disk is wrong rather than merely stale.
    function regenerate(): void {
        root.lastGenerated = "";
        root.generate(Wallpapers.current);
    }

    // Cycles auto -> light -> dark -> auto. Bound to a key in the wallpaper
    // grid, because that is where you are standing when you notice the mode is
    // wrong. Regenerating is not done here — see onThemeModeChanged below, which
    // does it for whoever changed the mode.
    function cycleMode(): void {
        const order = ["auto", "light", "dark"];
        const next = order[(order.indexOf(Persist.themeMode) + 1) % order.length];
        Persist.themeMode = next;
    }

    // Prefer a `grootshell-theme` on PATH, and fall back to the script this repo
    // ships beside shell.qml.
    //
    // The packaged wrapper is preferred because it brings its own dependencies —
    // matugen, ImageMagick, dconf — which a bare checkout cannot assume are
    // installed. The fallback is what makes the shell work at all without that
    // package: same script, run directly, with whatever the user has.
    //
    // Chosen inside the shell rather than by probing first, so there is no
    // availability state to keep and no ordering to get wrong. `command -v` costs
    // nothing next to a matugen run.
    readonly property string script: `${Quickshell.shellDir}/scripts/generate-theme.sh`

    function generate(path: string): void {
        if (!path || path === root.lastGenerated || generator.running)
            return;
        root.pending = path;
        // The generator picks light or dark from the image unless told; passing
        // the mode is what overrides that, so "auto" passes nothing at all.
        const mode = Persist.themeMode === "auto" ? "" : Persist.themeMode;
        generator.command = ["sh", "-c", 'if command -v grootshell-theme >/dev/null 2>&1; then exec grootshell-theme "$@"; else exec "$0" "$@"; fi', root.script, path, mode];
        generator.running = true;
        console.log("grootshell: generating colours from", path);
    }

    // A mode change has to regenerate the same image it just generated, so the
    // dedupe has to be cleared rather than worked around — and then actually
    // regenerate.
    //
    // Here rather than in cycleMode, because the mode has more than one place
    // that sets it now: the M key in the wallpaper grid and the settings panel.
    // Anything that changes the mode wants the same thing to happen next, so it
    // happens once, where the change is observed.
    Connections {
        target: Persist
        function onThemeModeChanged(): void {
            root.lastGenerated = "";
            root.generate(Wallpapers.current);
        }
    }

    Connections {
        target: Wallpapers
        function onCurrentChanged(): void {
            root.generate(Wallpapers.current);
        }
    }

    // On startup, generate only if there is no theme to load. A wallpaper that
    // has not changed since last time already has its colours on disk, and
    // regenerating them on every shell restart would burn a matugen run per
    // reload of the dev loop for a file that would come out byte-identical.
    Component.onCompleted: generateIfMissing.start()

    Timer {
        id: generateIfMissing
        // Long enough for Theme's FileView to have tried the read and for
        // Wallpapers to have settled on a current image.
        interval: 1500
        onTriggered: {
            if (!Theme.loaded && Wallpapers.current)
                root.generate(Wallpapers.current);
        }
    }

    // matugen runs --quiet, so anything it does say is a real problem and worth
    // repeating into the journal. Without this the generator failed for a week
    // behind a single WARN from quickshell, and the only symptom anyone saw was
    // a theme that would not change.
    Process {
        id: generator
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("grootshell-theme:", text.trim());
            }
        }

        onExited: code => {
            if (code === 0) {
                root.lastGenerated = root.pending;
                console.log("grootshell: colours generated from", root.pending);
            } else {
                // Deliberately does NOT record pending, so the same wallpaper can
                // be retried rather than being deduped away forever.
                console.warn("grootshell-theme exited", code, "for", root.pending);
            }
            root.pending = "";
        }
    }
}
