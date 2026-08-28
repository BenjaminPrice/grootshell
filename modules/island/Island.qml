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

// Docked to the bar rather than to the screen edge. frameThickness is 0 because
// there is no border band to overlap here — the bar is already frame-coloured
// and already occupies the top, so the island merges with the BAR's lower edge.
// shell.qml anchors it exactly there.
DockedPanel {
    id: root

    edge: "top"
    open: ShellState.island
    frameThickness: 0

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
                w: 660,
                h: 340
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
            }
        })

    readonly property var size: sizes[ShellState.islandTab] ?? sizes.dashboard

    readonly property var tabIds: ["dashboard", "media", "performance"]

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

    // The active tab gets first refusal on every key, and only what it declines
    // becomes a tab switch. That ordering is what lets the agenda keep Left for
    // "back to the list" while Left still moves between tabs everywhere else.
    function route(event): void {
        const tab = ShellState.islandTab;
        const target = tab === "dashboard" ? dashboardTab : tab === "media" ? mediaTab : null;

        if (target && target.handleKey(event)) {
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left) {
            root.cycleTab(-1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            root.cycleTab(1);
            event.accepted = true;
            return;
        }

        // Direct access, because three tabs is few enough to address by number
        // and arrowing across is a step nobody needs. Safe to claim here: the
        // tabs get first refusal, and the only one that wants digits is the
        // agenda's detail view, which takes them before this is reached.
        const digit = event.key - Qt.Key_1;
        if (digit >= 0 && digit < root.tabIds.length) {
            ShellState.islandTab = root.tabIds[digit];
            event.accepted = true;
        }
    }

    // Animated here rather than in DockedPanel: the panel already animates its
    // own depth on open and close, and a Behavior on the resulting size would
    // animate an animating value — which reads as lag, not as easing. This is a
    // separate motion (switching tabs) and gets its own.
    span: Math.round(size.w * Appearance.font.scale)
    depth: Math.round(size.h * Appearance.font.scale)

    Behavior on span {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    Behavior on depth {
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
            currentIndex: ["dashboard", "media", "performance"].indexOf(ShellState.islandTab)

            Dashboard {
                id: dashboardTab
            }
            Media {
                id: mediaTab
            }
            // No handleKey: a row of dials has nothing to operate.
            Performance {}
        }
    }
}
