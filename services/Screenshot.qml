pragma Singleton

import Quickshell
import Quickshell.Io

// Screenshots via grim, with slurp for region selection and swappy to annotate.
//
// Region capture must not include the shell's own layer surfaces in the
// selection overlay, which is why slurp runs as its own process against the
// compositor rather than being drawn here — a QML overlay would end up in its
// own screenshot.

Singleton {
    id: root

    signal taken(string path)

    function outputPath(): string {
        const dir = (Quickshell.env("XDG_PICTURES_DIR") || `${Quickshell.env("HOME")}/Pictures`) + "/Screenshots";
        // Sortable, and unique without a counter.
        const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
        return `${dir}/${stamp}.png`;
    }

    function region(): void {
        capture(true);
    }

    function screen(): void {
        capture(false);
    }

    function capture(selectRegion: bool): void {
        const path = root.outputPath();
        const geometry = selectRegion ? '-g "$(slurp)"' : "";

        // Copied to the clipboard AND written to disk: the clipboard is what you
        // almost always want, the file is what you want when you did not realise
        // you wanted it. cliphist's image watcher picks up the former, so a
        // screenshot also lands in clipboard history.
        proc.command = ["bash", "-c", `
            set -eu
            mkdir -p "$(dirname ${JSON.stringify(path)})"
            grim ${geometry} ${JSON.stringify(path)}
            wl-copy < ${JSON.stringify(path)}
            notify-send -a grootshell -i ${JSON.stringify(path)} "Screenshot" "Copied and saved"
            printf '%s' ${JSON.stringify(path)}
        `];
        proc.running = true;
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) root.taken(text.trim())
        }
    }

    // Annotate the most recent capture.
    function edit(path: string): void {
        editProc.command = ["swappy", "-f", path];
        editProc.running = true;
    }

    Process {
        id: editProc
        running: false
    }
}
