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
    property string lastGenerated: ""

    function generate(path: string): void {
        if (!path || path === root.lastGenerated || generator.running)
            return;
        root.lastGenerated = path;
        generator.command = ["grootshell-theme", path];
        generator.running = true;
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

    Process {
        id: generator
        running: false

        onExited: code => {
            if (code !== 0)
                console.warn("grootshell-theme failed with exit code", code);
        }
    }
}
