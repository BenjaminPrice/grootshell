pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

// Whether groot is currently pretending to be a games console.
//
// This service does NOT decide anything and does not touch the compositor. The
// `groot-mode` script in the nixos repo owns the switch: it applies the Hyprland
// look, moves to the game workspace, and then tells us. That split is deliberate
// — mode switching has to work when this shell is dead, because groot has no
// local console and being unable to leave game mode would mean being unable to
// use the machine.
//
// So all we do is reflect the state: stand our own chrome down, and stop
// animating. On a streamed host the second one matters — an animated frame is an
// encoded frame, and during a game that bandwidth belongs to the game.

Singleton {
    id: root

    property bool enabled: false

    // Everything that animates checks Appearance.anim.enabled, so this one
    // assignment stills the entire shell rather than each module needing to know
    // about game mode.
    onEnabledChanged: Appearance.anim.enabled = !enabled

    IpcHandler {
        target: "gameMode"

        function set(on: string): void {
            root.enabled = on === "true" || on === "1";
        }

        function toggle(): void {
            root.enabled = !root.enabled;
        }

        function isEnabled(): bool {
            return root.enabled;
        }
    }
}
