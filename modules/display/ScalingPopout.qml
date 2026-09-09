import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The display scaling panel.
//
// One question — how big should the desktop be on the screen I am looking at
// now — and the answer is remembered against the resolution the client
// connected with, so it is asked once per client rather than once per session.
//
// Deliberately not the same thing as the Scale group in the settings panel.
// Those four numbers size the SHELL's own type and spacing; this sizes the
// whole desktop, every window in it included, by changing what Hyprland
// considers a pixel. The two multiply rather than duplicate: this one is
// "which screen am I on", the settings ones are "how far away am I sitting".
//
// Which is also why this is in the tray and those are in a modal. Resolution
// here changes without anybody asking — Sunshine retargets the output whenever
// a client connects — so this is something you reach for on arrival, not
// something you go and configure.

Panel {
    id: root

    edge: "top"
    open: ShellState.scaling
    implicitWidth: 340
    implicitHeight: body.implicitHeight + Appearance.padding.lg * 2
    radius: Appearance.rounding.large

    // Asked for every time the panel opens rather than trusted from last time.
    // The resolution can have changed since — that is the normal case here, not
    // an edge one — and a panel that opens showing the previous client's mode is
    // offering scales for a screen that is no longer attached.
    onOpenChanged: if (open)
        Display.refresh()

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: Appearance.spacing.md

        // --- What is on screen now ------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            Icon {
                text: "aspect_ratio"
                filled: true
                color: Display.known ? Theme.accent : Theme.textMuted
                size: Appearance.font.size.xl
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Display.known ? `${Display.width} × ${Display.height}` : "No display"
                    color: Theme.text
                    font.pixelSize: Appearance.font.size.md
                    elide: Text.ElideRight
                }

                // The logical size, which is the one that decides whether a
                // scale is usable. 4K at 2x is a 1080p desktop — obvious once
                // said, and consistently surprising until it is.
                StyledText {
                    Layout.fillWidth: true
                    visible: Display.known
                    text: `${Display.logicalWidth} × ${Display.logicalHeight} of desktop · ${Display.output}`
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        StyledText {
            Layout.fillWidth: true
            visible: !Display.known
            text: "The compositor did not answer. Scaling needs hyprctl and jq on PATH."
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            wrapMode: Text.WordWrap
        }

        // --- The scales this mode can express -------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: Display.known
            spacing: 2

            Repeater {
                model: Display.options

                delegate: Rectangle {
                    id: option

                    required property real modelData

                    // Tolerantly, not exactly — hyprctl reports the scale to two
                    // decimals, so 4/3 comes back as 1.33. See Display.matches.
                    readonly property bool current: Display.matches(option.modelData, Display.scale)

                    Layout.fillWidth: true
                    implicitHeight: row.implicitHeight + Appearance.padding.sm * 2
                    radius: Appearance.rounding.small
                    color: option.current ? Theme.accentContainer : hover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Display.apply(option.modelData)
                    }

                    RowLayout {
                        id: row

                        anchors.fill: parent
                        anchors.leftMargin: Appearance.padding.sm
                        anchors.rightMargin: Appearance.padding.sm
                        spacing: Appearance.spacing.sm

                        StyledText {
                            text: `${Display.label(option.modelData)}×`
                            color: option.current ? Theme.onAccentContainer : Theme.text
                            font.pixelSize: Appearance.font.size.sm
                            font.family: Appearance.font.family.mono
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${Math.round(Display.width / option.modelData)} × ${Math.round(Display.height / option.modelData)}`
                            color: option.current ? Theme.onAccentContainerMuted : Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                            horizontalAlignment: Text.AlignRight
                        }

                        Icon {
                            visible: option.current
                            text: "check"
                            color: Theme.onAccentContainer
                            size: Appearance.font.size.sm
                        }
                    }
                }
            }
        }

        // --- What is remembered ---------------------------------------------
        //
        // The point of the whole widget, made visible. Without this the map is
        // an invisible side effect of clicking a scale, and the first time a
        // client came back at the right size it would be indistinguishable from
        // luck.
        ColumnLayout {
            Layout.fillWidth: true
            visible: Display.remembered.length > 0
            spacing: Appearance.spacing.xs

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.outlineVariant
            }

            StyledText {
                text: "Remembered"
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
            }

            StyledText {
                Layout.fillWidth: true
                text: "Applied on connect, by the resolution the client asks for."
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: Display.remembered

                delegate: RowLayout {
                    id: saved

                    required property var modelData

                    readonly property bool current: saved.modelData.resolution === Display.resolution

                    Layout.fillWidth: true
                    spacing: Appearance.spacing.sm

                    StyledText {
                        Layout.fillWidth: true
                        text: saved.modelData.resolution
                        color: saved.current ? Theme.text : Theme.textMuted
                        font.pixelSize: Appearance.font.size.xs
                        font.family: Appearance.font.family.mono
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: `${Display.label(saved.modelData.scale)}×`
                        color: saved.current ? Theme.accent : Theme.textMuted
                        font.pixelSize: Appearance.font.size.xs
                        font.family: Appearance.font.family.mono
                    }

                    // Forgetting the mode you are looking at is offered like any
                    // other: it drops the entry, and the scale on screen stays
                    // where it is until the next connect brings back 1x. The
                    // alternative — refusing, or silently rescaling underneath
                    // you — would both be stranger than doing what was asked.
                    Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: width / 2
                        color: forget.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            text: "close"
                            color: forget.containsMouse ? Theme.error : Theme.textMuted
                            size: Appearance.font.size.xs
                        }

                        MouseArea {
                            id: forget
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Display.forget(saved.modelData.resolution)
                        }
                    }
                }
            }
        }
    }
}
