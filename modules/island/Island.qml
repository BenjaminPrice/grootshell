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

Panel {
    id: root

    edge: "top"
    open: ShellState.island
    implicitWidth: Config.island.width
    implicitHeight: Config.island.height
    radius: Appearance.rounding.large

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
            Layout.fillWidth: true
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
                    required property var modelData

                    readonly property bool active: ShellState.islandTab === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Appearance.rounding.normal
                    color: active ? Theme.accentContainer : tabHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    Behavior on color {
                        enabled: Appearance.anim.enabled
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.xs

                        Icon {
                            text: modelData.icon
                            filled: active
                            color: active ? Theme.accent : Theme.textSecondary
                            size: Appearance.font.size.md
                        }

                        StyledText {
                            text: modelData.label
                            color: active ? Theme.accent : Theme.textSecondary
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }

                    MouseArea {
                        id: tabHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.islandTab = modelData.id
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
