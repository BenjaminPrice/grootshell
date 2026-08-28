pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Audio spectrum, from cava.
//
// cava does the hard part — reading the sink monitor, the FFT, the frequency
// banding and the smoothing — and can emit the result as plain text on stdout.
// That makes the whole integration a Process and a line parser, which is the
// same trade the rest of this shell makes: shell out to the tool that already
// solves it rather than carry a native plugin to do it in-process.
//
// It runs whenever something is PLAYING, not merely whenever the media tab is
// visible. The tab is the main consumer, but tying the process to a panel means
// the ring is always at rest for the first frames after you open it, and the
// thing you came to look at spends its first half second winding up.
//
// It does not run when nothing is playing. That is not an optimisation detail —
// cava on a silent sink still wakes 30 times a second to report zeros, and on a
// host that encodes its own display for the network, a widget that redraws for
// no reason is a cost paid twice.

Singleton {
    id: root

    // Frequency bands. Sixteen because the ring mirrors them into 32 segments,
    // and much past that the bars are thinner than the gaps between them at the
    // size this is actually viewed — across a room, through a video encoder.
    readonly property int bars: 16

    // 0..1 per band, low frequency first. Empty until the first frame arrives,
    // so a consumer must cope with a short array rather than assume `bars`.
    property var levels: []

    // Whether cava is on PATH at all. The shell must not require it: a dev
    // checkout on a machine without it should show a still ring, not an error.
    property bool available: false

    // Consecutive failed starts. cava exiting non-zero while we still want it
    // running would otherwise respawn forever — `running` is a binding, so the
    // exit that clears it immediately re-evaluates to true. Three strikes and
    // it stays down until something is played again.
    property int failures: 0

    readonly property bool wanted: root.available && Players.playing

    // Written once at startup and then only read. Not in the config directory:
    // this is a generated artefact of how the shell talks to cava, not
    // something a human edits, and putting it beside shell.json would invite
    // editing it.
    readonly property string configPath: `${Quickshell.stateDir}/cava.conf`

    Process {
        id: probe
        command: ["sh", "-c", "command -v cava"]
        running: true
        onExited: code => {
            root.available = code === 0;
            if (code !== 0)
                console.log("grootshell: cava not found, the spectrum ring will stay still");
        }
    }

    // A fresh attempt every time playback starts, so a transient failure — the
    // sink not being ready yet, say — does not disable the ring for the session.
    onWantedChanged: if (root.wanted)
        root.failures = 0

    Process {
        id: cava

        running: root.wanted && root.failures < 3

        // The config is written on every start rather than kept on disk,
        // because it is derived from `bars` above and a stale file would
        // silently disagree with the parser.
        //
        // `exec` so cava replaces the shell: without it the shell is the direct
        // child, and stopping the Process kills the shell while cava keeps the
        // sink monitor open and goes on writing into a closed pipe.
        command: ["sh", "-c", `cat > '${root.configPath}' <<'CAVACONF'
[general]
framerate = 30
bars = ${root.bars}
autosens = 1

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
channels = mono
mono_option = average
CAVACONF
exec cava -p '${root.configPath}'`]

        onExited: code => {
            if (code !== 0 && root.wanted) {
                root.failures++;
                console.warn("grootshell: cava exited", code, `(attempt ${root.failures})`);
            }
            root.levels = [];
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                // cava emits `n;n;...;n;` — note the TRAILING separator, so the
                // split yields one more field than there are bars and the last
                // is empty. Parsing by index up to `bars` rather than trusting
                // the split length is what keeps that from becoming a NaN on
                // the end of every frame.
                const parts = data.split(";");
                if (parts.length <= root.bars)
                    return;

                const out = [];
                for (let i = 0; i < root.bars; i++) {
                    const v = parseInt(parts[i], 10);
                    if (isNaN(v))
                        return; // A stray line — cava writes a terminal title escape at startup.
                    // Square root rather than linear. Loudness is roughly
                    // logarithmic, and a linear bar spends most of its travel in
                    // a range music rarely reaches, so the ring barely moves.
                    out.push(Math.sqrt(Math.max(0, Math.min(100, v)) / 100));
                }
                root.levels = out;
            }
        }
    }
}
