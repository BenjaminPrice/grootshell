pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.config

// Wallpapers: the list and the current selection.
//
// There is deliberately no thumbnail cache. There was one — generating scaled
// JPEGs into ~/.cache and matching them back by an md5 of the path — and it was
// three moving parts (an external magick, a hash that had to agree between a
// shell script and QML, and an error-fallback that broke its own binding) doing
// a job Qt already does. Setting sourceSize makes the decoder scale on the way
// in, so a 4K original is never held at 4K in order to draw it 200px tall.
//
// The current selection is persisted into shell.json rather than kept in memory,
// so it survives both a shell restart and the constant reloads of the dev loop.

Singleton {
    id: root

    readonly property string directory: Config.wallpaper.directory

    readonly property alias model: folder
    readonly property int count: folder.count

    property string current: Config.wallpaper.current

    FolderListModel {
        id: folder

        folder: `file://${root.directory}`
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name

        // Filters match case-sensitively by default, so anything saved as .PNG
        // or .JPG — which is most things straight off a camera or a download —
        // was invisible to the switcher.
        caseSensitive: false
        nameFilters: [
            "*.png",
            "*.jpg",
            "*.jpeg",
            "*.webp",
            "*.bmp"
        ]

        onCountChanged: {
            // First run, or the saved wallpaper has since been deleted.
            if (count > 0 && (root.current === "" || !root.exists(root.current)))
                root.set(folder.get(0, "filePath"));
        }
    }

    function exists(path: string): bool {
        for (let i = 0; i < folder.count; i++)
            if (folder.get(i, "filePath") === path)
                return true;
        return false;
    }

    function indexOf(path: string): int {
        for (let i = 0; i < folder.count; i++)
            if (folder.get(i, "filePath") === path)
                return i;
        return -1;
    }

    function set(path: string): void {
        if (!path || path === root.current)
            return;
        root.current = path;
        Config.wallpaper.current = path;
    }

    function at(index: int): string {
        if (index < 0 || index >= folder.count)
            return "";
        return folder.get(index, "filePath");
    }

    function next(): void {
        if (folder.count === 0)
            return;
        const i = root.indexOf(root.current);
        set(root.at((i + 1) % folder.count));
    }

    function previous(): void {
        if (folder.count === 0)
            return;
        const i = root.indexOf(root.current);
        set(root.at((i - 1 + folder.count) % folder.count));
    }
}
