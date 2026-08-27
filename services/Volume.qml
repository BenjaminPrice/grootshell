pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default sink and source, and the OSD trigger.
//
// Named Volume rather than Audio because `Audio` is a QtMultimedia type. Nothing
// here imports QtMultimedia today, so it worked — but a file named after a
// built-in is a trap armed for whoever adds that import later.
//
// Note what is NOT here: keybinds do not call into this service to change the
// volume. They run `wpctl` directly (see keybinds.nix in the nixos repo), and we
// find out by watching PipeWire. That inversion is on purpose — volume keys
// keep working when the shell is dead, and the OSD becomes a thing that observes
// the system rather than a thing the system depends on.

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Without this the node's audio properties are never populated — Quickshell
    // binds PipeWire objects lazily and only tracked ones get live data.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null)
    }

    // Emitted on an actual change, so the OSD can show itself. Guarded by
    // `ready` so the initial binding pass at startup does not pop an OSD onto
    // the screen before anyone has touched anything.
    property bool ready: false
    signal changed(bool isMic)

    Component.onCompleted: readyTimer.start()

    Timer {
        id: readyTimer
        interval: 1500
        onTriggered: root.ready = true
    }

    onVolumeChanged: if (root.ready) root.changed(false)
    onMutedChanged: if (root.ready) root.changed(false)
    onMicMutedChanged: if (root.ready) root.changed(true)

    function icon(): string {
        if (root.muted || root.volume <= 0)
            return "volume_off";
        if (root.volume < 0.34)
            return "volume_mute";
        if (root.volume < 0.67)
            return "volume_down";
        return "volume_up";
    }
}
