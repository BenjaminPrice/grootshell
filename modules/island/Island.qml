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
                w: 700,
                h: 480
            }
        })

    readonly property var size: sizes[ShellState.islandTab] ?? sizes.dashboard

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

            Dashboard {}
            Media {}
            Performance {}
        }
    }
}
