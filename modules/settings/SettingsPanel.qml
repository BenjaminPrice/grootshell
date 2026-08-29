import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The settings panel.
//
// A modal rather than a sixth island tab. The island is where you glance at
// something — the clock, what is playing, whether the disk is filling — and its
// tabs are all things you look at for a few seconds. Settings is the opposite:
// you go there deliberately, you stay a while, and you want room. It also has no
// business being one Tab keypress away from the agenda.
//
// ## A schema, not a screenful of widgets
//
// Every row below is one entry in `groups`, and SettingRow picks its control
// from the type. Adding a setting is a line of data. The alternative — a
// hand-placed slider per setting — is how a settings panel becomes the file
// nobody wants to touch, and it would drift from config/Config.qml within a
// month.
//
// Deliberately NOT everything in Config. trayFallback, mediaApps,
// calendarColours and preferredPlayers are structured data — maps and lists of
// objects — and a control for those is a JSON editor wearing a costume. They
// stay hand-edited, which is what shell.json is for.

Panel {
    id: root

    edge: "none"
    open: ShellState.settings
    radius: Appearance.rounding.large
    surface: Theme.layer(2)

    implicitWidth: Math.round(880 * Appearance.font.scale)
    implicitHeight: Math.round(620 * Appearance.font.scale)

    // Every row asks the FILE whether its key is overridden, and no property
    // changes when a file does. Bumping this after any write is what re-runs
    // those checks.
    property int revision: 0

    readonly property var groups: [
        {
            title: "Scale",
            detail: "Everything is measured in these. The shell is driven over a video stream, so the right size depends on how far away you are sitting rather than on the resolution.",
            settings: [
                {
                    key: "appearance.fontScale",
                    label: "Font scale",
                    detail: "Type, and everything sized from it",
                    type: "real",
                    min: 0.6,
                    max: 2,
                    step: 0.05
                },
                {
                    key: "appearance.spacingScale",
                    label: "Spacing scale",
                    type: "real",
                    min: 0.6,
                    max: 2,
                    step: 0.05
                },
                {
                    key: "appearance.paddingScale",
                    label: "Padding scale",
                    type: "real",
                    min: 0.6,
                    max: 2,
                    step: 0.05
                },
                {
                    key: "appearance.roundingScale",
                    label: "Corner scale",
                    type: "real",
                    min: 0,
                    max: 2,
                    step: 0.05
                }
            ]
        },
        {
            title: "Bar",
            settings: [
                {
                    key: "bar.height",
                    label: "Bar height",
                    detail: "The strip the pills float in, and what windows tile below",
                    type: "int",
                    min: 32,
                    max: 96,
                    step: 1
                },
                {
                    key: "bar.pillHeight",
                    label: "Pill height",
                    detail: "All three are this tall, deliberately",
                    type: "int",
                    min: 24,
                    max: 64,
                    step: 1
                },
                {
                    key: "bar.workspaces",
                    label: "Workspaces",
                    detail: "How many the strip shows",
                    type: "int",
                    min: 1,
                    max: 10,
                    step: 1
                },
                {
                    key: "bar.showClock",
                    label: "Show the clock",
                    detail: "Hides the resting pill only — the dashboard still opens",
                    type: "bool"
                },
                {
                    key: "bar.showTray",
                    label: "Show the tray",
                    type: "bool"
                },
                {
                    key: "bar.trayIconSize",
                    label: "Tray icon size",
                    type: "int",
                    min: 16,
                    max: 40,
                    step: 1
                },
                {
                    key: "bar.clockFormat",
                    label: "Clock format",
                    detail: "Qt date format: ddd d MMM  HH:mm",
                    type: "string"
                }
            ]
        },
        {
            title: "Frame",
            settings: [
                {
                    key: "border.thickness",
                    label: "Frame thickness",
                    detail: "0 follows the compositor's gaps, which is almost always what you want",
                    type: "int",
                    min: 0,
                    max: 40,
                    step: 1
                },
                {
                    key: "border.rounding",
                    label: "Frame rounding",
                    type: "int",
                    min: 0,
                    max: 60,
                    step: 1
                }
            ]
        },
        {
            title: "Panels",
            settings: [
                {
                    key: "island.defaultTab",
                    label: "Dashboard opens on",
                    type: "choice",
                    options: ["dashboard", "media", "performance", "wallpaper", "weather"]
                },
                {
                    key: "launcher.maxResults",
                    label: "Launcher results",
                    type: "int",
                    min: 3,
                    max: 20,
                    step: 1
                },
                {
                    key: "launcher.width",
                    label: "Launcher width",
                    type: "int",
                    min: 400,
                    max: 1200,
                    step: 10
                },
                {
                    key: "notifications.expireTimeout",
                    label: "Notification timeout",
                    detail: "Milliseconds. Hovering a toast holds it open regardless.",
                    type: "int",
                    min: 1000,
                    max: 20000,
                    step: 500
                },
                {
                    key: "notifications.maxVisible",
                    label: "Toasts on screen",
                    type: "int",
                    min: 1,
                    max: 10,
                    step: 1
                },
                {
                    key: "osd.timeout",
                    label: "Volume readout timeout",
                    detail: "Milliseconds",
                    type: "int",
                    min: 500,
                    max: 6000,
                    step: 100
                }
            ]
        },
        {
            title: "Weather",
            detail: "Forecasts come from Open-Meteo, which needs no account.",
            settings: [
                {
                    key: "weather.location",
                    label: "Location",
                    detail: "A place name — “Osaka”, “Osaka, Japan”. Empty turns the tab off.",
                    type: "string"
                },
                {
                    key: "weather.units",
                    label: "Units",
                    type: "choice",
                    options: ["metric", "imperial"]
                },
                {
                    key: "weather.days",
                    label: "Days to forecast",
                    type: "int",
                    min: 1,
                    max: 16,
                    step: 1
                },
                {
                    key: "weather.updateMinutes",
                    label: "Refresh every",
                    detail: "Minutes. The upstream model updates hourly.",
                    type: "int",
                    min: 5,
                    max: 120,
                    step: 5
                }
            ]
        },
        {
            title: "Wallpaper and system",
            settings: [
                {
                    key: "wallpaper.directory",
                    label: "Wallpaper folder",
                    type: "string"
                },
                {
                    key: "services.metricsInterval",
                    label: "Metrics interval",
                    detail: "Milliseconds. Only polled while the performance tab is open.",
                    type: "int",
                    min: 1000,
                    max: 15000,
                    step: 500
                }
            ]
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        // --- Header ---------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            Icon {
                text: "settings"
                color: Theme.accent
                filled: true
                size: Appearance.font.size.lg
            }

            StyledText {
                text: "Settings"
                font.pixelSize: Appearance.font.size.lg
                color: Theme.text
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                // Where these end up, said once. A settings panel that hides the
                // fact that it is writing a plain file is a settings panel you
                // cannot fix from a terminal when it goes wrong.
                text: "~/.config/grootshell/shell.json"
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "Only what you change is written. Everything else follows the shipped default, including when that default improves."
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            wrapMode: Text.WordWrap
        }

        // --- The settings ---------------------------------------------------
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: column
                width: parent.width
                spacing: Appearance.spacing.lg

                Repeater {
                    model: root.groups

                    delegate: ColumnLayout {
                        id: group
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Appearance.spacing.xs

                        StyledText {
                            Layout.topMargin: Appearance.spacing.sm
                            text: group.modelData.title
                            color: Theme.accent
                            font.pixelSize: Appearance.font.size.sm
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: (group.modelData.detail ?? "") !== ""
                            text: group.modelData.detail ?? ""
                            color: Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: Appearance.spacing.xs
                            Layout.bottomMargin: Appearance.spacing.xs
                            implicitHeight: 1
                            color: Theme.outlineVariant
                        }

                        Repeater {
                            model: group.modelData.settings

                            delegate: SettingRow {
                                required property var modelData

                                Layout.fillWidth: true
                                spec: modelData
                                revision: root.revision
                                onChanged: root.revision++
                            }
                        }
                    }
                }
            }
        }
    }
}
