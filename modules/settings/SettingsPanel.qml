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

    // Honour a request to open on a particular group, then clear it so the next
    // opening lands where the user left off rather than repeating the jump.
    //
    // Keyed on `open` rather than on settingsGroup changing, because the request
    // is set immediately before the panel opens and the order of the two is not
    // guaranteed — watching the group would miss a request that arrived first.
    onOpenChanged: {
        if (!root.open || ShellState.settingsGroup === "")
            return;
        const wanted = root.groups.findIndex(g => g.title === ShellState.settingsGroup);
        if (wanted >= 0)
            root.category = wanted;
        ShellState.settingsGroup = "";
    }

    implicitWidth: Math.round(880 * Appearance.font.scale)
    implicitHeight: Math.round(620 * Appearance.font.scale)

    // Every row asks the FILE whether its key is overridden, and no property
    // changes when a file does. Bumping this after any write is what re-runs
    // those checks.
    property int revision: 0

    // Which category is showing. A rail rather than one long scroll: there are
    // enough settings now that scrolling past four groups to reach the fifth is
    // its own small chore, and the categories are genuinely separate concerns
    // rather than arbitrary slices of one list.
    property int category: 0

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
                    key: "bar.showNetwork",
                    label: "Show Wi-Fi",
                    detail: "The indicator and its panel — joining, forgetting, and the radio switch",
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
                },
                {
                    key: "border.padding",
                    label: "Window spacing",
                    detail: "How far windows sit off the frame. -1 follows the compositor's inner gaps, so the frame is spaced like a neighbouring window",
                    type: "int",
                    min: -1,
                    max: 40,
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
                    type: "select",
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
            title: "Theme",
            detail: "Colours are generated from the wallpaper by matugen. Pick a wallpaper in the dashboard's Wallpaper tab; this is how light or dark is decided.",
            settings: [
                {
                    key: "themeMode",
                    store: "state",
                    label: "Light or dark",
                    detail: "auto reads the wallpaper's own brightness, which is right nearly always. The other two are for the images it reads wrong.",
                    type: "choice",
                    options: ["auto", "light", "dark"]
                }
            ]
        },
        {
            title: "Media",
            settings: [
                {
                    key: "services.mediaApps",
                    label: "Players",
                    detail: "Offered when nothing is playing, up to three. The first is the default. Only installed apps are listed.",
                    type: "apps"
                },
                {
                    key: "services.waveformColour",
                    label: "Spectrum ring",
                    detail: "A Theme role, so it still follows the wallpaper",
                    type: "choice",
                    options: ["accent", "text", "success", "warning", "error"]
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

            // Escape closes it too — this is for when the pointer is already
            // here, which for a panel full of sliders is most of the time.
            Icon {
                text: "close"
                color: closeHover.containsMouse ? Theme.error : Theme.textSecondary
                size: Appearance.font.size.lg

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.close("settings")
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "Only what you change is written. Everything else follows the shipped default, including when that default improves."
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            wrapMode: Text.WordWrap
        }

        // --- Rail and settings ----------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.lg

            ColumnLayout {
                // Capped as well as preferred. A layout honours a child's
                // minimum over the parent's preference, and this rail was
                // taking the whole panel.
                Layout.preferredWidth: 150
                Layout.maximumWidth: 150
                Layout.alignment: Qt.AlignTop
                spacing: Appearance.spacing.xs

                Repeater {
                    model: root.groups

                    delegate: Rectangle {
                        id: tab
                        required property var modelData
                        required property int index

                        readonly property bool active: root.category === tab.index

                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Appearance.rounding.full
                        color: tab.active ? Theme.accentContainer : tabHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            enabled: Appearance.anim.enabled
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }

                        StyledText {
                            anchors.left: parent.left
                            anchors.leftMargin: Appearance.padding.md
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.title
                            color: tab.active ? Theme.onAccentContainer : Theme.textSecondary
                            font.pixelSize: Appearance.font.size.xs
                        }

                        MouseArea {
                            id: tabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.category = tab.index
                        }
                    }
                }
            }

            Flickable {
                id: scroller

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: column.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                // The list is positioned against a row that scrolls. Rather than
                // track it, close it — a dropdown that follows the content out
                // from under the pointer is worse than one that just goes away.
                onContentYChanged: root.closeSelect()

                ColumnLayout {
                    id: column

                    readonly property var group: root.groups[root.category] ?? root.groups[0]

                    // The FLICKABLE's width, not `parent.width`.
                    //
                    // A Flickable reparents its children onto its contentItem,
                    // whose width is the scrollable content width and defaults to
                    // zero — so `parent.width` sized this column to nothing and
                    // the settings rendered at zero width. The rows were all
                    // there; none of them were visible.
                    width: scroller.width
                    spacing: Appearance.spacing.xs

                    StyledText {
                        Layout.fillWidth: true
                        visible: (column.group.detail ?? "") !== ""
                        text: column.group.detail ?? ""
                        color: Theme.textMuted
                        font.pixelSize: Appearance.font.size.xs
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Appearance.spacing.xs
                        implicitHeight: 1
                        color: Theme.outlineVariant
                    }

                    Repeater {
                        model: column.group.settings

                        delegate: SettingRow {
                            id: settingRow

                            required property var modelData

                            Layout.fillWidth: true
                            spec: modelData
                            revision: root.revision
                            onChanged: root.revision++
                            onSelectRequested: anchor => root.openSelect(settingRow, anchor)
                        }
                    }
                }
            }
        }
    }

    // --- The select list ------------------------------------------------------
    //
    // One list for the whole panel rather than one per row, and it lives out
    // here rather than inside the row that opened it. A row sits inside a
    // clipping Flickable, so a popup drawn there is cut off the moment it
    // extends past the visible area — which for a list that opens downward is
    // most of the time. Declared last so it draws over everything.

    property SettingRow selectRow: null
    property Item selectAnchor: null
    property real selectX: 0
    property real selectY: 0
    property real selectWidth: 0

    function openSelect(row: SettingRow, anchor: Item): void {
        // Clicking the field of an open list closes it, which is what a second
        // click on a dropdown is supposed to do.
        if (root.selectRow === row) {
            root.closeSelect();
            return;
        }

        const p = anchor.mapToItem(selectLayer, 0, 0);
        const count = (row.spec.options ?? []).length;
        const height = count * 32 + Appearance.padding.sm * 2;

        root.selectWidth = anchor.width;
        root.selectX = p.x;
        // Downward normally, upward when there is no room — the panel is a fixed
        // 620 tall and a list of five needs 176 of it, so the bottom rows would
        // otherwise open into nothing.
        root.selectY = p.y + anchor.height + 4 + height > selectLayer.height ? p.y - height - 4 : p.y + anchor.height + 4;
        root.selectAnchor = anchor;
        root.selectRow = row;
    }

    function closeSelect(): void {
        root.selectRow = null;
        root.selectAnchor = null;
    }

    // Nothing open survives the panel closing or the category changing, both of
    // which leave the anchor somewhere the list is no longer pointing at.
    onOpenChanged: if (!root.open) root.closeSelect()
    onCategoryChanged: root.closeSelect()

    Item {
        id: selectLayer

        anchors.fill: parent
        visible: root.selectRow !== null

        // Anywhere else closes it. Below the list, so a click on an option
        // reaches the option.
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeSelect()
        }

        Rectangle {
            x: root.selectX
            y: root.selectY
            width: root.selectWidth
            implicitHeight: options.implicitHeight + Appearance.padding.sm * 2

            radius: Appearance.rounding.small
            color: Theme.layer(3)
            border.width: 1
            border.color: Theme.outlineVariant

            ColumnLayout {
                id: options

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: root.selectRow?.spec?.options ?? []

                    delegate: Rectangle {
                        id: option

                        required property var modelData

                        readonly property bool active: String(root.selectRow?.value ?? "") === String(option.modelData)

                        Layout.fillWidth: true
                        implicitHeight: 32
                        color: optionHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                        StyledText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Appearance.padding.md
                            anchors.rightMargin: Appearance.padding.md
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(option.modelData)
                            color: option.active ? Theme.accent : Theme.text
                            font.pixelSize: Appearance.font.size.sm
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: optionHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectRow.commit(option.modelData);
                                root.closeSelect();
                            }
                        }
                    }
                }
            }
        }
    }
}
