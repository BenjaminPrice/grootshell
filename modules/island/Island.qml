import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The centre island: a clock pill that becomes the dashboard.
//
// It is one object in two shapes, not a panel that appears near a button. Closed
// it is the clock capsule floating in the bar; open it has grown up into the
// top border and outward into a panel hanging off it, with the date faded out
// and the dashboard faded in. Closing runs the whole thing backwards.
//
// That is why the clock lives HERE and not in modules/bar. The bar is a separate
// layer surface — it exists to reserve space — and an object cannot morph across
// two surfaces. Putting the clock in the overlay beside the panel makes the pill
// and the panel literally the same rectangle, so there is nothing to line up and
// nothing to keep in sync: the capsule you clicked IS the panel that opened.
//
// ## The geometry
//
// Two rects and a number between them. Collapsed is the pill: centred, floating
// below the frame's top band, fully round. Expanded is the panel: wider, taller,
// its top edge pushed up INTO the band so it reads as hanging from it, square at
// the top and rounded at the bottom.
//
// The top corners have to square off as it docks. Left round, a 22px corner
// radius on a panel whose top is inside a 10px band would curve back out below
// the band and show a crescent of wallpaper on each side. Qt 6 has per-corner
// radii, so that is four interpolations rather than the extra squaring rectangle
// components/DockedPanel.qml needs.
//
// The fillets are what sell it. Where the panel's sides meet the underside of
// the band the filled region turns through 270°, and without a concave corner
// there that reads as a box overlapping a stripe. They grow with the panel, so
// there is nothing protruding at rest to fillet.
//
// The panel resizes per tab rather than being one box big enough for the largest
// of them. Performance wants room for six dials; the dashboard is a clock and a
// date and looks abandoned in the same space.
//
// The tabs do not move while it resizes, which is the part that has to be got
// right or the whole thing feels unstable. Two things make that true: the tab
// row is sized to its own content rather than stretched to the panel, and the
// panel is centred on screen, so it grows symmetrically around the row.

Item {
    id: root

    // Game mode strips the desktop, and the clock goes with the rest of the
    // chrome — this is the only panel that is visible at rest, so it is the only
    // one that has to say so.
    readonly property bool shown: !GameMode.enabled
    readonly property bool open: ShellState.island && root.shown

    // Config.bar.showClock hides the RESTING pill, not the dashboard. Turning
    // the clock off should not also remove the only thing you can click to get
    // at the agenda — SUPER+S still opens it, and it still appears when it does.
    visible: root.shown && (Config.bar.showClock || root.open || root.progress > 0)
    clip: true

    // 0 = pill, 1 = panel. Not readonly: a Behavior animates writes, and a
    // read-only property is only ever re-evaluated.
    property real progress: root.open ? 1 : 0

    Behavior on progress {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    function lerp(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }

    // --- Collapsed: the clock pill ------------------------------------------
    readonly property int pillHeight: Math.round(Config.bar.pillHeight * Appearance.font.scale)
    readonly property int pillWidth: Math.round(clockText.implicitWidth + Appearance.padding.xl * 2)

    // Vertically centred in the band of wallpaper between the frame's top edge
    // and where a tiled window begins — the same optical centring the other
    // pills get from the bar surface. See Config.bar.gap.
    readonly property int pillTop: Config.border.thickness + Math.round((Config.bar.height + Config.bar.gap - root.pillHeight) / 2)

    // --- Expanded: the panel -------------------------------------------------
    //
    // Sized per tab, and scaled by the font scale so the "sofa, not desk" knob
    // moves these too — a panel measured in pixels while its contents are
    // measured in scaled type would clip the moment the scale went up.
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

    readonly property var size: root.sizes[ShellState.islandTab] ?? root.sizes.dashboard

    readonly property int panelWidth: Math.round(root.size.w * Appearance.font.scale)
    // Plus the band it is buried in, so the CONTENT gets the height the tab
    // asked for rather than that minus the overlap.
    readonly property int panelHeight: Math.round(root.size.h * Appearance.font.scale) + Config.border.thickness

    // --- The morph ----------------------------------------------------------
    implicitWidth: Math.round(root.lerp(root.pillWidth, root.panelWidth, root.progress))
    implicitHeight: Math.round(root.lerp(root.pillHeight, root.panelHeight, root.progress))

    // Read by shell.qml, which owns the anchoring. Travels from the pill's
    // resting line up to the screen edge.
    readonly property int topOffset: Math.round(root.lerp(root.pillTop, 0, root.progress))

    // Resizing between tabs is a separate motion from opening, so it gets its
    // own easing on the endpoint rather than sharing the morph's.
    Behavior on implicitWidth {
        enabled: Appearance.anim.enabled && root.open
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    Behavior on implicitHeight {
        enabled: Appearance.anim.enabled && root.open
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    // --- Surface -------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: ShellState.island ? Theme.frame : clockHover.containsMouse ? Theme.surfaceContainerHigh : Theme.frame

        // Fully round as a pill; square at the top and rounded at the bottom
        // once docked into the band.
        topLeftRadius: Math.round(root.lerp(root.pillHeight / 2, 0, root.progress))
        topRightRadius: topLeftRadius
        bottomLeftRadius: Math.round(root.lerp(root.pillHeight / 2, Appearance.rounding.large, root.progress))
        bottomRightRadius: bottomLeftRadius

        // Only while it is a pill. Docked, it is a panel and the outline would
        // trace a box around something that is supposed to be part of the frame.
        border.width: root.progress < 0.02 ? 1 : 0
        border.color: Theme.outlineVariant

        Behavior on color {
            enabled: Appearance.anim.enabled
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // --- Junction fillets -----------------------------------------------------
    //
    // The corner named is the quarter-disc REMOVED, not the one the fillet
    // occupies — those are opposites, and conflating them rotates every fillet
    // by 180° and leaves the step it was meant to smooth.
    //
    // Positioned against the underside of the frame's top band, which is a fixed
    // line on screen: in this item's own coordinates it moves as the panel rises.
    readonly property int fillet: Math.round(Appearance.rounding.large * root.progress)
    readonly property int filletY: Config.border.thickness - root.topOffset

    InverseCorner {
        visible: root.fillet > 0
        size: root.fillet
        color: Theme.frame
        corner: "bottomLeft"
        x: -root.fillet
        y: root.filletY
    }

    InverseCorner {
        visible: root.fillet > 0
        size: root.fillet
        color: Theme.frame
        corner: "bottomRight"
        x: root.width
        y: root.filletY
    }

    // --- The clock, when collapsed -------------------------------------------
    //
    // Fades out over the first third of the morph. Anchored near the top rather
    // than centred in the whole item, so it stays roughly where the pill was
    // instead of sliding down the growing panel as it goes.
    StyledText {
        id: clockText

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((root.pillHeight - height) / 2)
        text: Time.format(Config.bar.clockFormat)
        color: Theme.text
        font.pixelSize: Appearance.font.size.md
        opacity: Math.max(0, 1 - root.progress * 3)
        visible: opacity > 0
    }

    MouseArea {
        id: clockHover
        anchors.fill: parent
        // Only the pill is a button. Once open the panel's own controls own the
        // pointer, and a full-area click target over them would swallow every
        // one of them.
        enabled: !root.open
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggle("island")
    }

    // --- Keyboard -------------------------------------------------------------
    //
    // A bare Item rather than a FocusScope wrapping the content: nothing inside
    // wants focus of its own, so there is no scope to manage — and it must stay
    // VISIBLE, because an invisible item cannot hold active focus, which is the
    // bug that silently broke keyboard navigation in the wallpaper switcher.
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.route(event)
    }

    readonly property var tabIds: ["dashboard", "media", "performance", "wallpaper"]

    // Focus has to be taken after the panel is actually on screen. It grows from
    // a pill, so on the frame `open` flips there is nothing yet to focus.
    onOpenChanged: if (root.open)
        Qt.callLater(root.grabFocus)

    function grabFocus(): void {
        if (root.open)
            keyHandler.forceActiveFocus();
    }

    function cycleTab(delta: int): void {
        const i = root.tabIds.indexOf(ShellState.islandTab);
        const next = (((i < 0 ? 0 : i) + delta) % root.tabIds.length + root.tabIds.length) % root.tabIds.length;
        ShellState.islandTab = root.tabIds[next];
    }

    // Moving between tabs is Tab, Shift+Tab and the digits. The arrow keys
    // belong entirely to whatever tab is open.
    //
    // Left and Right used to switch tabs, and that was never honest: they only
    // did so when the open tab had no use for them, so the same key meant "next
    // tab" on the dashboard and "next event" in the agenda's detail view,
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

    // The performance tab is the only expensive one. Subscribing on tab change
    // rather than on panel open means an open island sitting on Media costs
    // nothing.
    readonly property bool wantsMetrics: root.open && ShellState.islandTab === "performance"
    onWantsMetricsChanged: root.wantsMetrics ? Sys.subscribe() : Sys.unsubscribe()
    Component.onDestruction: if (root.wantsMetrics) Sys.unsubscribe()

    // --- Contents -------------------------------------------------------------
    //
    // Faded in over the back half of the morph, and not rendered at all before
    // that: a 700x400 layout squeezed into a 200x40 pill is a screenful of
    // binding warnings and a frame of garbage on the way out.
    Item {
        id: body

        anchors.fill: parent
        anchors.topMargin: Config.border.thickness + Appearance.padding.lg
        anchors.leftMargin: Appearance.padding.lg
        anchors.rightMargin: Appearance.padding.lg
        anchors.bottomMargin: Appearance.padding.lg

        opacity: Math.max(0, root.progress * 2 - 1)
        visible: opacity > 0

        ColumnLayout {
            anchors.fill: parent
            spacing: Appearance.spacing.md

            // --- Tabs ---------------------------------------------------------
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
                        color: tab.active ? Theme.accentContainer : tabHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

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

            // --- Body ---------------------------------------------------------
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
                    // StackLayout keeps every page alive, so without this the
                    // grid would decode thumbnails the moment the island opened
                    // on any tab at all.
                    active: root.open && ShellState.islandTab === "wallpaper"
                }
            }
        }
    }
}
