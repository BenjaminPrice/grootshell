pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// A tray menu the APP draws, as an ordinary window — and closing it like a menu.
//
// Items with a D-Bus menu get a real popup from Quickshell, which closes on an
// outside click by itself. Items without one draw their own on a right click:
// on groot those are Wine/Proton apps (Battle.net) relayed by xembedsniproxy.
// Wine maps that menu as a normal toplevel, and neither Wine nor the app ever
// closes it when you click elsewhere — focus leaving it changes nothing, so it
// stayed open until Escape.
//
// So the shell closes it. request() notes the time just before asking for the
// menu, and the first window Hyprland opens shortly after is taken to be it —
// nothing else marks it: Battle.net's menu is titled "Battle.net", the same as
// its main window. It is then closed, the way Hyprland closes any window, when
//   - focus moves to anything else (a click on another window or the bar's
//     workspace strip), or
//   - the desktop is clicked: that changes no focus, so the wallpaper reports
//     it (modules/background/Background.qml).
// Choosing an item or pressing Escape closes it from the app's side, and the
// resulting closewindow clears the state here.

Singleton {
    id: root

    // Hyprland's address for the open menu, "0x…", or "" when there is none.
    property string address: ""

    property real expectedAt: 0

    // The window adopted for this click, kept after it unmaps. Wine maps the
    // menu, unmaps it ~15ms later and maps it again at the same address; the
    // first closewindow cleared `address`, the second open was ignored, and the
    // menu sat there untracked. Re-adopting only THIS address keeps anything
    // else that opens in the window — a dialog the chosen item opened — from
    // being taken for the menu.
    property string adopted: ""

    // How long after the click the menu window may take to appear. Battle.net's
    // shows in well under a second; anything later is unrelated.
    readonly property int appearWithin: 1500

    function expect(): void {
        root.expectedAt = Date.now();
        root.adopted = "";
    }

    // Ask `item` (a SystemTrayItem with no D-Bus menu) for its own menu, at the
    // icon drawn by `visual` on `screen`.
    //
    // Through scripts/tray-context-menu.sh rather than Quickshell: only a
    // ContextMenu call can say where the icon is, and Wine opens the menu where
    // it believes the icon to be — so this is what puts the menu under the icon
    // rather than against the screen edge. Quickshell has no such call and does
    // not expose the item's D-Bus address, which the script finds instead.
    //
    // X root coordinates are DEVICE pixels (Hyprland's xwayland
    // force_zero_scaling), so the logical position is scaled by the monitor's.
    // The point is the icon's bottom centre, the corner the menu hangs from.
    //
    // If the script fails, secondaryActivate() — which groot's xembedsniproxy
    // turns into a right click at its parking spot, top-right — still gets a
    // menu up, just not under the icon.
    function request(item, visual: Item, screen: ShellScreen): void {
        root.expect();
        const monitor = Hyprland.monitorFor(screen);
        const scale = monitor?.scale ?? 1;
        const p = visual.mapToItem(null, visual.width / 2, visual.height);
        const x = Math.round(((monitor?.x ?? 0) + p.x) * scale);
        const y = Math.round(((monitor?.y ?? 0) + p.y) * scale);
        root.fallbackItem = item;
        helper.command = [`${Quickshell.shellDir}/scripts/tray-context-menu.sh`, item.id, String(x), String(y)];
        helper.running = true;
    }

    property var fallbackItem: null

    Process {
        id: helper

        onExited: code => {
            if (code !== 0 && root.fallbackItem) {
                console.warn("grootshell: tray-context-menu failed, falling back to secondaryActivate");
                root.fallbackItem.secondaryActivate();
            }
            root.fallbackItem = null;
        }
    }

    function close(): void {
        if (!root.address)
            return;
        Hypr.lua(`hl.dsp.window.close({ window = "address:${root.address}" })`);
        root.address = "";
    }

    Connections {
        target: Hyprland

        // Event data carries addresses as bare hex; the dispatcher wants 0x.
        function onRawEvent(event: HyprlandEvent): void {
            switch (event.name) {
            case "openwindow": {
                // ADDRESS,WORKSPACE,CLASS,TITLE. A class-less window is
                // xembedsniproxy's own container, never the menu.
                const fields = event.data.split(",");
                const opened = "0x" + fields[0];
                const recent = Date.now() - root.expectedAt < root.appearWithin;
                if (recent && fields[2] && (!root.adopted || opened === root.adopted)) {
                    root.address = opened;
                    root.adopted = opened;
                }
                break;
            }
            case "closewindow":
                if ("0x" + event.data === root.address)
                    root.address = "";
                break;
            case "activewindowv2":
                if (root.address && "0x" + event.data !== root.address)
                    root.close();
                break;
            }
        }
    }
}
