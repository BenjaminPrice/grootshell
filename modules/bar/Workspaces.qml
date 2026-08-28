import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The workspace strip.
//
// Caelestia's version, laid out horizontally rather than down the left edge: a
// rounded track holding one slot per workspace, where an empty workspace shows
// its number, an occupied one shows the icons of what is actually running on it,
// and the focused one is wrapped in a filled pill.
//
// Icons rather than numbers because the useful question is "where did I leave
// the browser", not "which integer am I on". A number tells you nothing you did
// not already know from the highlight — so the numeral appears only when a
// workspace is EMPTY and there is nothing better to show.
//
// Kanji numerals for those, not digits. An empty slot is a placeholder, and a
// row of Arabic digits beside a row of application icons reads as data; 一二三
// reads as an ornament, which is what an empty slot should be. They need a CJK
// face, which the shell's wrapped fontconfig would not otherwise have — see
// nix/package.nix.
//
// Switchable three ways: the SUPER+1..5 binds, a click on a slot, and a scroll
// anywhere over the track. Scroll matters on a machine driven through a stream,
// where the pointer is often the only input that survives the client's OS
// eating a shortcut.

Item {
    id: root

    readonly property int count: Config.bar.workspaces
    readonly property int focused: Hyprland.focusedWorkspace?.id ?? 1

    // Indexed rather than computed: there is no arithmetic that turns 4 into 四,
    // and the list only has to reach Config.bar.workspaces. Anything past the end
    // falls back to the digit rather than showing nothing.
    readonly property var numerals: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    function numeralFor(n: int): string {
        return root.numerals[n - 1] ?? String(n);
    }

    // Cap the icons per workspace. Ten terminals on one workspace should not be
    // allowed to push the clock off centre.
    readonly property int maxIcons: 4

    implicitWidth: track.implicitWidth
    implicitHeight: track.implicitHeight

    // Filters the global toplevel list rather than reading a workspace's own
    // `toplevels` model. Same data, one less thing that has to be populated for
    // this to work at all.
    //
    // Indexed loop rather than .filter(): `values` comes across as a QList and
    // whether it arrives as a real JS array is not something to bet the whole
    // widget on — if it does not, an array method throws, the binding fails, and
    // the Repeater silently gets nothing.
    function windowsOn(id: int): var {
        const all = Hyprland.toplevels?.values ?? [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const t = all[i];
            if ((t?.workspace?.id ?? -1) === id)
                out.push(t);
        }
        return out;
    }

    // The Wayland app id first, the Hyprland IPC class second.
    //
    // lastIpcObject alone was empty here — quickshell creates a toplevel from the
    // Wayland toplevel-management protocol and only fills the IPC object in on a
    // later refresh, so reading it is a race this widget lost every time. appId
    // comes straight off the protocol and is populated from the start.
    function classOf(toplevel): string {
        const wayland = toplevel?.wayland?.appId ?? "";
        if (wayland)
            return wayland;
        const ipc = toplevel?.lastIpcObject;
        return (ipc ? (ipc["class"] ?? ipc["initialClass"]) : "") ?? "";
    }

    // A window class is not an icon name — "org.mozilla.firefox" and "firefox"
    // and "Navigator" all mean the same application. heuristicLookup is
    // Quickshell's own matcher for exactly this, and falls back to the class
    // itself so an app with no desktop entry still gets whatever the icon theme
    // has under that name.
    function iconFor(toplevel): string {
        const cls = root.classOf(toplevel);
        if (!cls)
            return "";
        // heuristicLookup can return null for anything without a desktop entry,
        // and can throw on odd input; neither should take the bar down.
        let named = cls;
        try {
            const entry = DesktopEntries.heuristicLookup(cls);
            if (entry?.icon)
                named = entry.icon;
        } catch (e) {}
        return Quickshell.iconPath(named, "application-x-executable");
    }

    function switchBy(delta: int): void {
        const next = Math.min(root.count, Math.max(1, root.focused + delta));
        if (next !== root.focused)
            Hypr.focusWorkspace(next);
    }

    Rectangle {
        id: track

        implicitWidth: row.implicitWidth + Appearance.padding.sm * 2
        implicitHeight: row.implicitHeight + Appearance.padding.xs * 2
        radius: Appearance.rounding.full
        color: Theme.surfaceContainer

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: Appearance.spacing.xs

            Repeater {
                model: root.count

                delegate: Rectangle {
                    id: slot

                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var windows: root.windowsOn(wsId)
                    readonly property bool occupied: windows.length > 0
                    readonly property bool active: root.focused === slot.wsId

                    // An empty slot is its numeral; an occupied one is as wide
                    // as its icons. The active slot keeps a minimum width so the
                    // pill is still a pill when the workspace is empty.
                    implicitWidth: Math.max(active ? numeral.implicitWidth + Appearance.padding.md * 2 : numeral.implicitWidth + Appearance.padding.xs * 2, content.implicitWidth + (occupied ? Appearance.padding.sm * 2 : 0))
                    implicitHeight: Appearance.font.size.lg + Appearance.padding.xs * 2

                    radius: Appearance.rounding.full
                    color: active ? Theme.accentContainer : "transparent"

                    Behavior on implicitWidth {
                        enabled: Appearance.anim.enabled
                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.emphasised
                        }
                    }

                    Behavior on color {
                        enabled: Appearance.anim.enabled
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    // --- Icons, when something is running -------------------
                    RowLayout {
                        id: content

                        anchors.centerIn: parent
                        spacing: 2
                        visible: slot.occupied

                        Repeater {
                            model: slot.windows.slice(0, root.maxIcons)

                            delegate: Item {
                                id: appIcon
                                required property var modelData

                                implicitWidth: Appearance.font.size.md
                                implicitHeight: implicitWidth
                                // Dim what is not focused, so the active
                                // workspace reads first even in a row that is
                                // otherwise all icons.
                                opacity: slot.active ? 1 : 0.65

                                IconImage {
                                    id: img
                                    anchors.fill: parent
                                    implicitSize: appIcon.implicitWidth
                                    source: root.iconFor(appIcon.modelData)
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                // A window with no resolvable icon still has to
                                // occupy its slot — otherwise "nothing is
                                // running here" and "the icon theme has no entry
                                // for this" look identical, which is exactly the
                                // ambiguity that made this hard to diagnose.
                                StyledText {
                                    anchors.centerIn: parent
                                    visible: !img.visible
                                    text: (root.classOf(appIcon.modelData)[0] ?? "?").toUpperCase()
                                    color: slot.active ? Theme.onAccentContainer : Theme.textSecondary
                                    font.pixelSize: Appearance.font.size.xs
                                }
                            }
                        }

                        // "and more" rather than an unbounded row.
                        StyledText {
                            visible: slot.windows.length > root.maxIcons
                            text: `+${slot.windows.length - root.maxIcons}`
                            color: slot.active ? Theme.onAccentContainer : Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }

                    // --- Numeral, when empty --------------------------------
                    StyledText {
                        id: numeral

                        anchors.centerIn: parent
                        visible: !slot.occupied
                        text: root.numeralFor(slot.wsId)
                        // Dimmer than a running workspace's icons: this is the
                        // absence of content, and it should not compete with the
                        // slots that have some.
                        color: slot.active ? Theme.onAccentContainer : Theme.outlineVariant
                        font.pixelSize: Appearance.font.size.sm

                        Behavior on color {
                            enabled: Appearance.anim.enabled
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        // A dot is far too small to hit with a pointer that has
                        // crossed a network; the hit box is the slot's full
                        // height and a little either side.
                        anchors.margins: -Appearance.spacing.xs
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hypr.focusWorkspace(slot.wsId)
                    }
                }
            }
        }

        // Scroll anywhere over the track. Placed after the per-slot MouseAreas
        // so those still take clicks, while wheel events fall through to here.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                // A single notch is 120 units. Up/away scrolls towards
                // workspace 1, which matches the left-to-right reading order of
                // the strip.
                root.switchBy(wheel.angleDelta.y > 0 ? -1 : 1);
            }
        }
    }
}
