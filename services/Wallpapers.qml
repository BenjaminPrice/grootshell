pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.config

// Wallpapers: the list, the current selection, and the thumbnail cache.
//
// Thumbnails are cached to disk because the switcher is a horizontal strip of
// full-resolution photographs. Decoding a dozen 4K JPEGs to draw them 130px tall
// is slow enough to be visible, and on a streamed host a stutter in the switcher
// is a stutter in the video.
//
// The current selection is persisted into shell.json rather than kept in memory,
// so it survives both a shell restart and the constant reloads of the dev loop.

Singleton {
    id: root

    readonly property string directory: Config.wallpaper.directory
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`) + "/grootshell/thumbs"

    readonly property alias model: folder
    readonly property int count: folder.count

    property string current: Config.wallpaper.current

    FolderListModel {
        id: folder
        folder: `file://${root.directory}`
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        // Filters match case-sensitively by default, so a file saved as
        // .PNG or .JPG — which is most things straight off a camera or a
        // download — was invisible to the switcher.
        caseSensitive: false

        onCountChanged: {
            // First run, or the saved wallpaper has since been deleted.
            if (count > 0 && (root.current === "" || !root.exists(root.current)))
                root.set(folder.get(0, "filePath"));
            if (count > 0)
                cache.running = true;
        }
    }

    function exists(path: string): bool {
        for (let i = 0; i < folder.count; i++)
            if (folder.get(i, "filePath") === path)
                return true;
        return false;
    }

    function set(path: string): void {
        if (!path || path === root.current)
            return;
        root.current = path;
        Config.wallpaper.current = path;
    }

    function next(): void {
        if (folder.count === 0)
            return;
        let i = 0;
        for (let n = 0; n < folder.count; n++)
            if (folder.get(n, "filePath") === root.current) {
                i = (n + 1) % folder.count;
                break;
            }
        set(folder.get(i, "filePath"));
    }

    function thumbnail(path: string): string {
        // Content-addressed by path, so two files with the same basename in
        // different directories do not collide.
        return `${root.cacheDir}/${Qt.md5(path)}.jpg`;
    }

    // Generates only what is missing, so this is cheap on every run but the
    // first. Uses ImageMagick if present and degrades to no thumbnails (the
    // switcher falls back to the full image) if it is not.
    Process {
        id: cache
        running: false
        command: ["bash", "-c", `
            set -eu
            dir=${JSON.stringify(root.directory)}
            out=${JSON.stringify(root.cacheDir)}
            height=${Config.wallpaper.thumbnailHeight}

            command -v magick >/dev/null 2>&1 || exit 0
            mkdir -p "$out"

            find "$dir" -maxdepth 1 -type f \\
                \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \\) \\
            | while IFS= read -r f; do
                # Must match Qt.md5() above, which hashes the plain path string.
                hash=$(printf '%s' "$f" | md5sum | cut -d' ' -f1)
                thumb="$out/$hash.jpg"
                [ -f "$thumb" ] && continue
                magick "$f" -auto-orient -resize "x$((height*2))" -quality 82 "$thumb" 2>/dev/null || true
            done
        `]
    }
}
