import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Tabbing between desktops, with a picture of each one.
//
// The existing ./Switcher.qml answers "where is that window"; this answers
// "what is on the other desktops", which is a different question and wants a
// different shape. A grid of window cards cannot show that workspace 3 is the
// one with the terminal on the left and the browser on the right — the spatial
// arrangement IS the memory, and a list throws it away.
//
// So each desktop is drawn to scale: a card with the screen's aspect ratio,
// windows placed where they actually are, at the size they actually are, with
// their real contents inside them.
//
// ## Committing
//
// Advancing the selection focuses that desktop after a short pause, exactly like
// the wallpaper grid applies after one. There is no confirm step and no need to
// detect the SUPER key being released — which is fortunate, because a
// compositor keybind cannot tell us that.
//
// The pause is what makes it feel like alt-tab: hold SUPER, tap Tab past the
// desktops you do not want, stop on the one you do, and it goes there. Tapping
// through five desktops does not switch five times, which on a host that encodes
// its own display would be five workspace animations nobody asked to watch.
//
// Tab is handled by the COMPOSITOR bind, not here. Hyprland processes its own
// keybinds before forwarding to clients, so SUPER+Tab fires even while this
// panel holds exclusive keyboard focus — if this also claimed Tab, every press
// would advance twice.

Panel {
    id: root

    edge: "none"
    open: ShellState.desktops
    radius: Appearance.rounding.large
    surface: Theme.layer(2)

    // The focused monitor, not this panel's own screen. The switcher is about
    // where you are working, and reaching it through Hyprland rather than
    // through QsWindow means one source for both the geometry below and the
    // workspace ids — which have to agree, or the windows are drawn at
    // coordinates from a different screen.
    readonly property HyprlandMonitor monitor: Hyprland.focusedMonitor

    readonly property int count: Config.bar.workspaces

    // Kanji, matching modules/bar/Workspaces.qml. The numeral is an ornament
    // behind the windows rather than a label, so it should read as a mark and
    // not as data — which is the same argument made there.
    readonly property var numerals: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    // Cards are the screen's shape, so a window that occupies the left half of
    // the desktop occupies the left half of the card. Any other aspect makes the
    // scaled geometry a lie.
    readonly property real aspect: (root.monitor?.height ?? 0) > 0 ? root.monitor.width / root.monitor.height : 16 / 9

    readonly property int cardWidth: Math.round(230 * Appearance.font.scale)
    readonly property int cardHeight: Math.round(cardWidth / root.aspect)

    property int selected: 1

    implicitWidth: cards.implicitWidth + Appearance.padding.lg * 2
    implicitHeight: cards.implicitHeight + header.implicitHeight + Appearance.padding.lg * 2 + Appearance.spacing.md

    onOpenChanged: {
        if (!root.open) {
            commit.stop();
            return;
        }
        root.selected = Hyprland.focusedWorkspace?.id ?? 1;
        Qt.callLater(root.grabFocus);
    }

    function grabFocus(): void {
        if (root.open)
            keys.forceActiveFocus();
    }

    // Wraps, because a switcher you can fall off the end of makes you look at
    // the screen to find out where you are — which is the thing it exists to
    // save you from.
    function move(delta: int): void {
        root.selected = ((root.selected - 1 + delta) % root.count + root.count) % root.count + 1;
        commit.restart();
    }

    function apply(): void {
        commit.stop();
        if (root.selected !== (Hyprland.focusedWorkspace?.id ?? -1))
            Hypr.focusWorkspace(root.selected);
        ShellState.close("desktops");
    }

    // SUPER+Tab arrives here rather than through this panel's own keys. See the
    // note at the top for why the compositor has to own that chord.
    Connections {
        target: ShellState
        function onDesktopStep(delta: int): void {
            if (root.open)
                root.move(delta);
        }
    }

    Timer {
        id: commit
        // Long enough to tap past a desktop without landing on it, short enough
        // that stopping on one feels like arriving rather than waiting.
        interval: 650
        onTriggered: root.apply()
    }

    // Focus sink. Tab is deliberately absent — see the note at the top.
    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Right:
            case Qt.Key_Down:
                root.move(1);
                event.accepted = true;
                break;
            case Qt.Key_Left:
            case Qt.Key_Up:
                root.move(-1);
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.apply();
                event.accepted = true;
                break;
            default:
                // Digits jump straight there, same as the island's tabs.
                const digit = event.key - Qt.Key_1 + 1;
                if (digit >= 1 && digit <= root.count) {
                    root.selected = digit;
                    root.apply();
                    event.accepted = true;
                }
                break;
            }
        }
    }

    // Every toplevel on a given desktop.
    //
    // Indexed rather than .filter(): `values` arrives as a QML list, which is
    // array-LIKE but not an Array, and betting a panel on which Array methods
    // survive the wrapper is the bug modules/bar/Workspaces.qml documents.
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

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        RowLayout {
            id: header
            Layout.fillWidth: true

            StyledText {
                text: "Desktops"
                font.pixelSize: Appearance.font.size.md
                color: Theme.text
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: "SUPER + Tab"
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }
        }

        RowLayout {
            id: cards
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.md

            Repeater {
                model: root.count

                delegate: Rectangle {
                    id: card

                    required property int index
                    readonly property int wsId: card.index + 1
                    readonly property bool isSelected: root.selected === card.wsId
                    readonly property bool isFocused: (Hyprland.focusedWorkspace?.id ?? -1) === card.wsId
                    readonly property var windows: root.windowsOn(card.wsId)

                    implicitWidth: root.cardWidth
                    implicitHeight: root.cardHeight
                    radius: Appearance.rounding.normal
                    color: Theme.surfaceContainer
                    clip: true

                    border.width: card.isSelected ? 3 : card.isFocused ? 1 : 0
                    border.color: card.isSelected ? Theme.accent : Theme.outlineVariant

                    Behavior on border.width {
                        enabled: Appearance.anim.enabled
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    // The numeral, behind everything. Only really visible on an
                    // empty desktop, which is exactly when it is the only thing
                    // that distinguishes one card from the next.
                    StyledText {
                        anchors.centerIn: parent
                        text: root.numerals[card.index] ?? String(card.wsId)
                        color: Theme.outlineVariant
                        font.pixelSize: Math.round(root.cardHeight * 0.5)
                        opacity: card.windows.length > 0 ? 0.25 : 1
                    }

                    // --- The windows, to scale ------------------------------
                    Repeater {
                        model: card.windows

                        delegate: Item {
                            id: win

                            required property var modelData

                            // Hyprland reports absolute desktop coordinates, so
                            // the monitor's own origin has to come off before
                            // anything can be expressed as a fraction of it.
                            readonly property var box: win.modelData?.lastIpcObject
                            readonly property real mw: root.monitor?.width ?? 1920
                            readonly property real mh: root.monitor?.height ?? 1080

                            readonly property bool placed: !!(win.box?.at && win.box?.size && win.box.size[0] > 0)

                            x: win.placed ? (win.box.at[0] - (root.monitor?.x ?? 0)) / win.mw * card.width : 0
                            y: win.placed ? (win.box.at[1] - (root.monitor?.y ?? 0)) / win.mh * card.height : 0
                            width: win.placed ? win.box.size[0] / win.mw * card.width : card.width
                            height: win.placed ? win.box.size[1] / win.mh * card.height : card.height

                            // Floating and fullscreen windows sit above tiled
                            // ones, the same order the compositor draws them in.
                            z: (win.box?.floating ? 1 : 0) + (win.box?.fullscreen ? 2 : 0)

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Appearance.rounding.small
                                color: Theme.surfaceContainerHighest

                                // A still frame, not a live feed.
                                //
                                // `live: true` is a screencopy request per
                                // window per frame, and on a host already
                                // encoding its whole output for the network that
                                // is a poor trade for a thumbnail you look at
                                // for a second. One capture when the switcher
                                // opens says everything a switcher needs to say.
                                ScreencopyView {
                                    id: shot
                                    anchors.fill: parent
                                    live: false
                                    captureSource: root.open ? win.modelData?.wayland ?? null : null

                                    // The capture has to be ASKED for with
                                    // live off, and can only be asked once
                                    // there is a source to capture.
                                    onCaptureSourceChanged: if (captureSource)
                                        shot.captureFrame()
                                }

                                // Whatever the window is, named. Shown when the
                                // capture has not arrived — a window with no
                                // preview should still say which one it is,
                                // rather than being an empty grey box.
                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.max(16, Math.min(parent.width, parent.height) * 0.4)
                                    visible: !shot.hasContent
                                    source: Quickshell.iconPath(win.modelData?.lastIpcObject?.class ?? "", "application-x-executable")
                                    asynchronous: true
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // A click is a decision, so it skips the pause.
                        onClicked: {
                            root.selected = card.wsId;
                            root.apply();
                        }
                    }
                }
            }
        }
    }
}
