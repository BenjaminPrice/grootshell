import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The centre island: a drawer that comes down from the clock and tabs between
// the dashboard, whatever is playing, and machine health.
//
// Hangs off the bar's centre because that is where the clock is, and the clock
// is the handle — the drawer appearing directly beneath the thing you clicked is
// what makes it feel attached rather than summoned.
//
// The panel resizes per tab rather than being one box big enough for the largest
// of them. Performance wants room for six dials; the dashboard is a clock and a
// date and looks abandoned in the same space.
//
// The tabs do not move while it resizes, which is the part that has to be got
// right or the whole thing feels unstable. Two things make that true: the tab
// row is sized to its own content rather than stretched to the panel, and the
// panel is centred on screen, so it grows symmetrically around the row. A
// fillWidth tab strip would have every button slide outward on every switch —
// including the one you just clicked, out from under the pointer.

// A card that drops from the clock pill, not an extrusion of the frame.
//
// It used to be a DockedPanel with frameThickness 0, merging into the underside
// of a bar that was painted frame-coloured all the way across. There is no such
// bar any more — the top of the screen is three floating pills over the
// wallpaper — so there is nothing to merge WITH, and an extrusion with no band
// to grow out of is just a rectangle that grows.
//
// So it became the same floating card the other modals are: it slides down from
// the clock pill and fades in, with the pill filling with accent while it is
// open so the two read as handle and drawer. Frame-coloured to match the pills
// rather than surface-coloured, which keeps the whole top of the screen one
// family of objects.
Panel {
    id: root

    edge: "top"
    open: ShellState.island
    surface: Theme.frame

    // Keyboard sink for the whole island.
    //
    // A bare Item rather than a FocusScope wrapping the content: nothing inside
    // wants focus of its own, so there is no scope to manage — and it must stay
    // VISIBLE, because an invisible item cannot hold active focus, which is the
    // bug that silently broke keyboard navigation in the wallpaper switcher.
    //
    // Declared first so it sits under the content and cannot intercept a click.
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.route(event)
    }

    // Sized per tab. Scaled by the font scale so the "sofa, not desk" knob moves
    // these too — a panel measured in pixels while its contents are measured in
    // scaled type would clip the moment the scale went up.
    readonly property var sizes: ({
            dashboard: {
                w: 700,
                h: 400
            },
            media: {
                // Tall enough for a 240px disc plus the tab row above it, wide
                // enough that the title beside it is not a column of two words.
                w: 720,
                h: 360
            },
            performance: {
                // Wide enough for one row of dials at roughly 20% larger than
                // the old 3x2 grid gave them.
                //
                // The old arrangement worked out to a ~177px dial: 700 wide less
                // padding over three columns is 206 across, but two rows of a
                // 480 panel left only ~194 tall, and Gauge squares itself to the
                // smaller of the two. One row of five at 212 needs
                // 5*212 + 4*gap + padding, and the height only has to clear one
                // dial plus its label and the line beneath.
                w: 1190,
                h: 310
            },
            wallpaper: {
                // The biggest tab, because it is the only one whose content is
                // photographs. A thumbnail below roughly 250px tells you the
                // rough colour of an image and nothing about whether you want to
                // look at it all day, which is the actual question being asked
                // here. Three columns at that size plus two rows of them is what
                // sets both numbers.
                w: 940,
                h: 470
            }
        })

    readonly property var size: sizes[ShellState.islandTab] ?? sizes.dashboard

    // Wallpaper is appended rather than slotted in beside the dashboard, so the
    // digits already in anyone's fingers keep pointing at the same tabs.
    readonly property var tabIds: ["dashboard", "media", "performance", "wallpaper"]

    // Focus has to be taken after the panel is actually on screen. The extrusion
    // animates up from nothing, so on the frame `open` flips there is still
    // nothing to focus — the same deferral the wallpaper switcher needs.
    onOpenChanged: if (root.open)
        Qt.callLater(root.grabFocus)

    function grabFocus(): void {
        if (root.open)
            keyHandler.forceActiveFocus();
    }

    function cycleTab(delta: int): void {
        const i = root.tabIds.indexOf(ShellState.islandTab);
        const next = Math.max(0, Math.min(root.tabIds.length - 1, (i < 0 ? 0 : i) + delta));
        ShellState.islandTab = root.tabIds[next];
    }

    // Moving between tabs is Tab, Shift+Tab and the digits. The arrow keys
    // belong entirely to whatever tab is open.
    //
    // Left and Right used to switch tabs, and that was never quite honest: they
    // only did so when the open tab had no use for them, so the same key meant
    // "next tab" on the dashboard and "next event" in the agenda's detail view,
    // depending on where you happened to be. The wallpaper grid is what makes it
    // untenable rather than merely inconsistent — a grid needs all four arrows,
    // so a tab that claims them would be a room with no door.
    //
    // Reserving Tab in both directions and handling it BEFORE the open tab gets
    // a look means no tab can trap the keyboard, whatever it decides to claim.
    function route(event): void {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.cycleTab(event.modifiers & Qt.ShiftModifier ? -1 : 1);
            event.accepted = true;
            return;
        }

        const tab = ShellState.islandTab;
        const target = tab === "dashboard" ? dashboardTab : tab === "media" ? mediaTab : tab === "wallpaper" ? wallpaperTab : null;

        if (target && target.handleKey(event)) {
            event.accepted = true;
            return;
        }

        // Direct access, because four tabs is few enough to address by number
        // and tabbing across is a step nobody needs. Safe to claim after the
        // open tab has declined: the only one that wants digits is the agenda's
        // detail view, which takes them above.
        const digit = event.key - Qt.Key_1;
        if (digit >= 0 && digit < root.tabIds.length) {
            ShellState.islandTab = root.tabIds[digit];
            event.accepted = true;
        }
    }

    // Resizing between tabs is its own motion, separate from opening. Panel
    // animates position and opacity on open; this animates the box, so switching
    // from the dashboard to the performance dials grows the card rather than
    // cutting to a new size.
    implicitWidth: Math.round(size.w * Appearance.font.scale)
    implicitHeight: Math.round(size.h * Appearance.font.scale)

    Behavior on implicitWidth {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    Behavior on implicitHeight {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    // The performance tab is the only expensive one. Subscribing on tab change
    // rather than on panel open means an open island sitting on Media costs
    // nothing.
    readonly property bool wantsMetrics: open && ShellState.islandTab === "performance"
    onWantsMetricsChanged: wantsMetrics ? Sys.subscribe() : Sys.unsubscribe()
    Component.onDestruction: if (wantsMetrics) Sys.unsubscribe()

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        // --- Tabs -----------------------------------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.xs

            Repeater {
                model: [
                    {
                        id: "dashboard",
                        icon: "dashboard",
                        label: "Dashboard"
                    },
                    {
                        id: "media",
                        icon: "music_note",
                        label: "Media"
                    },
                    {
                        id: "performance",
                        icon: "monitoring",
                        label: "Performance"
                    },
                    {
                        id: "wallpaper",
                        icon: "wallpaper",
                        label: "Wallpaper"
                    }
                ]

                delegate: Rectangle {
                    id: tab
                    required property var modelData

                    readonly property bool active: ShellState.islandTab === modelData.id

                    // Sized to content, deliberately. See the note above.
                    implicitWidth: tabRow.implicitWidth + Appearance.padding.lg * 2
                    implicitHeight: tabRow.implicitHeight + Appearance.padding.sm * 2
                    radius: Appearance.rounding.full
                    color: active ? Theme.accentContainer : tabHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    Behavior on color {
                        enabled: Appearance.anim.enabled
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    RowLayout {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.xs

                        Icon {
                            text: tab.modelData.icon
                            filled: tab.active
                            color: tab.active ? Theme.onAccentContainer : Theme.textSecondary
                            size: Appearance.font.size.md
                        }

                        StyledText {
                            text: tab.modelData.label
                            color: tab.active ? Theme.onAccentContainer : Theme.textSecondary
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }

                    MouseArea {
                        id: tabHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.islandTab = tab.modelData.id
                    }
                }
            }
        }

        // --- Body -----------------------------------------------------------
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: Math.max(0, root.tabIds.indexOf(ShellState.islandTab))

            Dashboard {
                id: dashboardTab
            }
            Media {
                id: mediaTab
            }
            // No handleKey: a row of dials has nothing to operate.
            Performance {}
            WallpaperTab {
                id: wallpaperTab
                // Only the visible tab should be loading photographs. A
                // StackLayout keeps every page alive, so without this the grid
                // would decode thumbnails the moment the island opened on any
                // tab at all.
                active: root.open && ShellState.islandTab === "wallpaper"
            }
        }
    }
}
