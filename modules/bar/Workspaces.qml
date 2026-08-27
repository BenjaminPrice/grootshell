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
// rounded track holding one slot per workspace, where an empty workspace is a
// dot, an occupied one shows the icons of what is actually running on it, and
// the focused one is wrapped in a filled pill.
//
// Icons rather than numbers because the useful question is "where did I leave
// the browser", not "which integer am I on". A number tells you nothing you did
// not already know from the highlight.
//
// Switchable three ways: the SUPER+1..5 binds, a click on a slot, and a scroll
// anywhere over the track. Scroll matters on a machine driven through a stream,
// where the pointer is often the only input that survives the client's OS
// eating a shortcut.

Item {
    id: root

    readonly property int count: Config.bar.workspaces
    readonly property int focused: Hyprland.focusedWorkspace?.id ?? 1

    // Cap the icons per workspace. Ten terminals on one workspace should not be
    // allowed to push the clock off centre.
    readonly property int maxIcons: 4

    implicitWidth: track.implicitWidth
    implicitHeight: track.implicitHeight

    function windowsOn(id: int): var {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        return ws?.toplevels?.values ?? [];
    }

    // A window class is not an icon name — "org.mozilla.firefox" and "firefox"
    // and "Navigator" all mean the same application. heuristicLookup is
    // Quickshell's own matcher for exactly this, and falls back to the class
    // itself so an app with no desktop entry still gets whatever the icon theme
    // has under that name.
    function iconFor(toplevel): string {
        const cls = toplevel?.lastIpcObject?.class ?? "";
        if (!cls)
            return "";
        const entry = DesktopEntries.heuristicLookup(cls);
        return Quickshell.iconPath(entry?.icon ?? cls, "application-x-executable");
    }

    function switchBy(delta: int): void {
        const next = Math.min(root.count, Math.max(1, root.focused + delta));
        if (next !== root.focused)
            Hyprland.dispatch(`workspace ${next}`);
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

                    // An empty slot is a dot; an occupied one is as wide as its
                    // icons. The active slot keeps a minimum width so the pill
                    // is still a pill when the workspace is empty.
                    implicitWidth: Math.max(active ? dotSize * 2.4 : dotSize, content.implicitWidth + (occupied ? Appearance.padding.sm * 2 : 0))
                    implicitHeight: Appearance.font.size.lg + Appearance.padding.xs * 2

                    readonly property int dotSize: Math.round(Appearance.font.size.sm * 0.7)

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

                            delegate: IconImage {
                                required property var modelData

                                implicitSize: Appearance.font.size.md
                                source: root.iconFor(modelData)
                                asynchronous: true
                                // Dim what is not focused, so the active
                                // workspace reads first even in a row that is
                                // otherwise all icons.
                                opacity: slot.active ? 1 : 0.65
                            }
                        }

                        // "and more" rather than an unbounded row.
                        StyledText {
                            visible: slot.windows.length > root.maxIcons
                            text: `+${slot.windows.length - root.maxIcons}`
                            color: slot.active ? Theme.accent : Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }

                    // --- Dot, when empty ------------------------------------
                    Rectangle {
                        anchors.centerIn: parent
                        visible: !slot.occupied
                        width: slot.dotSize
                        height: slot.dotSize
                        radius: height / 2
                        color: slot.active ? Theme.accent : Theme.outlineVariant

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
                        onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
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
