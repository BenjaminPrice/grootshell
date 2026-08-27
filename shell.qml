//@ pragma UseQApplication
//@ pragma ShellId grootshell
//@ pragma IconTheme Papirus-Dark

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
// Three layer surfaces per screen:
//
//   Background  bottom layer, the wallpaper. Separate so a fullscreen window
//               covers it the way it covers any other window.
//   Bar         top layer, anchored to the top edge, and the ONLY surface here
//               with an exclusive zone. That zone is what stops tiled windows
//               opening underneath the bar — see below.
//   Overlay     everything else — border and panels — in one fullscreen
//               transparent surface.
//
// The bar is its own surface purely so it can reserve space. A layer surface
// anchored to all four edges has no meaningful exclusive zone (there is no edge
// to reserve *from*), so while the bar lived inside the overlay nothing told
// Hyprland it was there and windows tiled straight under it. Hyprland's gaps_out
// could have been widened at the top to compensate, but that would hard-code the
// bar's height into the compositor config, in a second place, where it could not
// follow Config.bar.height when it hot-reloads.
//
// The overlay keeps ExclusionMode.Ignore on purpose: the frame occupies the
// screen edges but must not reserve them, because gaps_out already insets tiled
// windows to clear it.
//
// The single-overlay shape for everything else is what lets panels look like
// they grow out of the frame instead of floating above it: they are siblings in
// one scene, sharing a coordinate space and a clip. The price is that a
// fullscreen transparent surface would eat every click on the desktop, which is
// what `mask` is for — only the rectangles listed there accept input, and
// everything else falls through to the window underneath.

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope
            required property ShellScreen modelData

            // What the bar occupies: its own height plus the frame band above
            // it. Panels in the overlay dock below this rather than to the bar
            // itself, which now lives in a different window.
            //
            // NOT readonly, despite being a pure function of its inputs: a
            // Behavior animates writes, and a read-only property is never
            // written to — it is re-evaluated. Declaring this readonly makes the
            // Behavior below a load-time error rather than a no-op, which takes
            // the whole shell down.
            property int barZone: GameMode.enabled ? 0 : Config.bar.height + Config.border.thickness

            Behavior on barZone {
                enabled: Appearance.anim.enabled
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.emphasised
                }
            }

            Background {
                screen: scope.modelData
            }

            PanelWindow {
                id: barWindow

                screen: scope.modelData
                color: "transparent"

                anchors {
                    top: true
                    left: true
                    right: true
                }

                implicitHeight: scope.barZone
                visible: scope.barZone > 0

                // Auto derives the exclusive zone from the anchored size, which
                // is exactly the reservation we want and keeps following the
                // height as it animates.
                exclusionMode: ExclusionMode.Auto

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "grootshell-bar"
                // The bar never types. Taking focus here would steal it from the
                // window you are working in every time the pointer crossed it.
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                Bar {
                    anchors.fill: parent
                    screen: scope.modelData
                }
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

                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "grootshell"

                // Exclusive only while something that types is open. OnDemand
                // would let a panel steal focus on hover, and None would make the
                // launcher unable to read a keystroke.
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
                        anchors.fill: parent
                    }

                    // Docked into the frame rather than floating over it. Each
                    // of these anchors to the screen edge it belongs to, inset
                    // past the bar's reserved zone at the top.
                    Island {
                        id: island
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: scope.barZone
                    }

                    Launcher {
                        id: launcher
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                    }

                    Sidebar {
                        id: sidebar
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: scope.barZone
                        anchors.bottom: parent.bottom
                    }

                    NotificationCentre {
                        id: notificationCentre
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: scope.barZone
                        anchors.bottom: parent.bottom
                    }

                    Toasts {
                        id: toasts
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: scope.barZone
                    }

                    Osd {
                        id: osd
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    NetworkPopout {
                        id: networkPopout
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: scope.barZone
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
                //
                // The bar is absent because it is no longer in this window; its
                // own surface takes input across its whole area.
                mask: Region {
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
