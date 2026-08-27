//@ pragma UseQApplication
//@ pragma ShellId grootshell

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.background
import qs.modules.bar
import qs.modules.border
import qs.modules.island
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd
import qs.modules.sidebar
import qs.modules.wallpaper
import qs.modules.network
import qs.modules.clipboard
import qs.modules.switcher
import qs.modules.keybinds

// grootshell.
//
// Two layer surfaces per screen:
//
//   Background  bottom layer, the wallpaper. Separate so a fullscreen window
//               covers it the way it covers any other window.
//   Overlay     everything else — border, bar, panels — in one fullscreen
//               transparent surface.
//
// The single-overlay shape is what lets panels look like they grow out of the
// frame instead of floating above it: they are siblings in one scene, sharing a
// coordinate space and a clip. The price is that a fullscreen transparent
// surface would eat every click on the desktop, which is what `mask` is for —
// only the rectangles listed there accept input, and everything else falls
// through to the window underneath.

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope
            required property ShellScreen modelData

            Background {
                screen: scope.modelData
            }

            PanelWindow {
                id: overlay

                screen: scope.modelData
                color: "transparent"

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                // Ignore, not Auto: the frame occupies the screen edges but must
                // NOT reserve them. Hyprland's own gaps_out already insets tiled
                // windows to clear the border (see hyprland.lua), and an
                // exclusive zone on top of that would inset them twice.
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "grootshell"

                // Exclusive only while something that types is open. OnDemand
                // would let the bar steal focus from the focused window on
                // hover, and None would make the launcher unable to read a
                // keystroke.
                WlrLayershell.keyboardFocus: ShellState.anyOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                // Escape closes whatever is open, from anywhere. The one binding
                // that must always work, because a panel that has taken
                // exclusive keyboard focus and cannot be dismissed is a hung
                // desktop on a host with no local console.
                Item {
                    anchors.fill: parent
                    focus: ShellState.anyOpen
                    Keys.onEscapePressed: ShellState.closeAll()

                    Border {
                        id: border
                        anchors.fill: parent
                    }

                    Bar {
                        id: bar
                        screen: scope.modelData
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                    }

                    // Docked into the frame rather than floating over it: each
                    // of these anchors to the border's inner edge.
                    Island {
                        id: island
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: bar.bottom
                    }

                    Launcher {
                        id: launcher
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                    }

                    Sidebar {
                        id: sidebar
                        anchors.left: parent.left
                        anchors.top: bar.bottom
                        anchors.bottom: parent.bottom
                    }

                    NotificationCentre {
                        id: notificationCentre
                        anchors.right: parent.right
                        anchors.top: bar.bottom
                        anchors.bottom: parent.bottom
                    }

                    Toasts {
                        id: toasts
                        anchors.right: parent.right
                        anchors.top: bar.bottom
                    }

                    Osd {
                        id: osd
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    NetworkPopout {
                        id: networkPopout
                        anchors.right: parent.right
                        anchors.top: bar.bottom
                    }

                    ClipboardPanel {
                        id: clipboardPanel
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                    }

                    WallpaperSwitcher {
                        id: wallpaperSwitcher
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                    }

                    Switcher {
                        id: switcher
                        anchors.centerIn: parent
                    }

                    KeybindsModal {
                        id: keybindsModal
                        anchors.centerIn: parent
                    }
                }

                // Everything that should accept a click. A panel that is closed
                // contributes nothing, so the desktop underneath stays fully
                // usable — which is the difference between a shell and a
                // fullscreen window that happens to be mostly transparent.
                mask: Region {
                    Region {
                        item: bar
                    }
                    Region {
                        item: island.visible ? island : null
                    }
                    Region {
                        item: launcher.visible ? launcher : null
                    }
                    Region {
                        item: sidebar.visible ? sidebar : null
                    }
                    Region {
                        item: notificationCentre.visible ? notificationCentre : null
                    }
                    Region {
                        item: toasts.visible ? toasts : null
                    }
                    Region {
                        item: networkPopout.visible ? networkPopout : null
                    }
                    Region {
                        item: clipboardPanel.visible ? clipboardPanel : null
                    }
                    Region {
                        item: wallpaperSwitcher.visible ? wallpaperSwitcher : null
                    }
                    Region {
                        item: switcher.visible ? switcher : null
                    }
                    Region {
                        item: keybindsModal.visible ? keybindsModal : null
                    }
                    // The OSD is deliberately absent: it is feedback, not a
                    // control, and it appears exactly when your pointer might be
                    // somewhere near the right edge doing something else.
                }
            }
        }
    }

    // --- IPC ----------------------------------------------------------------
    //
    // The surface the Hyprland keybinds call, via `grootshell-ipc call <target>
    // <fn>`. Names here and in the nixos repo's keybinds.nix have to agree; a
    // typo on either side is a key that silently does nothing.

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            ShellState.toggle("launcher");
        }
        function open(): void {
            ShellState.open("launcher");
        }
        function close(): void {
            ShellState.close("launcher");
        }
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void {
            ShellState.toggle("sidebar");
        }
    }

    IpcHandler {
        target: "island"
        function toggle(): void {
            ShellState.toggle("island");
        }
        // `grootshell-ipc call island show media` — jump straight to a tab
        // rather than opening and then clicking.
        function show(tab: string): void {
            ShellState.islandTab = tab;
            ShellState.open("island");
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            ShellState.toggle("notifications");
        }
        function clear(): void {
            Notifs.clear();
        }
        function dnd(on: string): void {
            Notifs.doNotDisturb = on === "true" || on === "1";
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (!ShellState.clipboard)
                Clipboard.refresh();
            ShellState.toggle("clipboard");
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            ShellState.toggle("wallpaper");
        }
        function next(): void {
            Wallpapers.next();
        }
        function set(path: string): void {
            Wallpapers.set(path);
        }
    }

    IpcHandler {
        target: "network"
        function toggle(): void {
            if (!ShellState.network)
                Net.scan();
            ShellState.toggle("network");
        }
    }

    IpcHandler {
        target: "switcher"
        function toggle(): void {
            ShellState.toggle("switcher");
        }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            ShellState.toggle("keybinds");
        }
    }

    IpcHandler {
        target: "screenshot"
        function region(): void {
            ShellState.closeAll();
            Screenshot.region();
        }
        function screen(): void {
            ShellState.closeAll();
            Screenshot.screen();
        }
    }
}
