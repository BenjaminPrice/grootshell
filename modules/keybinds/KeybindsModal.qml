import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The keybind cheatsheet, on SUPER+/ or SUPER+?.
//
// This replaces a keybind list that used to be baked into the wallpaper as a
// generated PNG. That worked — it needed no keypress, which was the point on a
// host nobody sat at — but it also meant the wallpaper could never be a picture,
// and it capped the list at what fits legibly on one screen.
//
// Centred rather than docked to an edge like the other panels: this is a modal
// reference, not part of the furniture, and centring is what says "read me, then
// dismiss me".
//
// Laid out in fixed columns because the list is ~40 entries. A single scrolling
// column would defeat the purpose — you open this to scan for one thing, and
// scanning beats scrolling.

Panel {
    id: root

    edge: "none"
    open: ShellState.keybinds
    surface: Theme.layer(2)
    radius: Appearance.rounding.large

    readonly property int columnCount: 3
    readonly property int columnWidth: 400

    // Width is FIXED, derived from the column count rather than from the
    // content. Deriving it from the grid instead would be a binding loop: the
    // grid's height depends on its width, and its width would depend on the
    // panel that is reading its height.
    implicitWidth: columnCount * columnWidth + (columnCount - 1) * Appearance.spacing.xl + Appearance.padding.xl * 2

    implicitHeight: Math.min(900, header.implicitHeight + grid.implicitHeight + footnote.implicitHeight + Appearance.padding.xl * 2 + Appearance.spacing.lg * 2)

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.lg

        // --- Header ---------------------------------------------------------
        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            Icon {
                text: "keyboard"
                color: Theme.accent
                filled: true
                size: Appearance.font.size.xl
            }

            StyledText {
                text: "Keybinds"
                font.pixelSize: Appearance.font.size.xl
                color: Theme.text
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: "Esc to close"
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
            }
        }

        // --- Nothing to show ------------------------------------------------
        //
        // Only happens on a dev checkout with no NixOS module behind it. Say why
        // rather than showing an empty box.
        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Keybinds.available
            title: "No keybind list found"
            detail: `Expected ${Keybinds.path}, which the NixOS module generates.`
        }

        // --- Categories -----------------------------------------------------
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Keybinds.available
            contentHeight: grid.implicitHeight
            clip: true
            // Only scrolls if the clamp above actually bit; usually it does not.
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: grid

                width: parent.width
                columns: root.columnCount
                columnSpacing: Appearance.spacing.xl
                rowSpacing: Appearance.spacing.lg

                Repeater {
                    model: Keybinds.groups

                    delegate: ColumnLayout {
                        id: group
                        required property var modelData

                        Layout.preferredWidth: root.columnWidth
                        // Top-aligned so short categories do not stretch their
                        // rows to match the tallest one beside them.
                        Layout.alignment: Qt.AlignTop
                        spacing: Appearance.spacing.xs

                        StyledText {
                            text: group.modelData.name
                            color: Theme.accent
                            font.pixelSize: Appearance.font.size.sm
                            bottomPadding: Appearance.spacing.xs
                        }

                        Repeater {
                            model: group.modelData.binds

                            delegate: RowLayout {
                                id: bindRow
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Appearance.spacing.sm

                                // Each key as its own cap. A single
                                // "SUPER + SHIFT + V" string is a wall of text at
                                // a glance; discrete caps are shaped like the
                                // thing you actually press.
                                RowLayout {
                                    spacing: 3

                                    Repeater {
                                        model: Keybinds.keys(bindRow.modelData)

                                        delegate: Rectangle {
                                            id: cap
                                            required property string modelData

                                            implicitWidth: capText.implicitWidth + Appearance.padding.sm * 2
                                            implicitHeight: capText.implicitHeight + Appearance.padding.xs * 2
                                            radius: Appearance.rounding.small
                                            color: Theme.surfaceContainerHighest
                                            border.width: 1
                                            border.color: Theme.outlineVariant

                                            StyledText {
                                                id: capText
                                                anchors.centerIn: parent
                                                text: cap.modelData
                                                color: Theme.text
                                                font.pixelSize: Appearance.font.size.xs
                                                mono: true
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: bindRow.modelData.description ?? ""
                                    color: Theme.textSecondary
                                    font.pixelSize: Appearance.font.size.xs
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Footnote -------------------------------------------------------
        StyledText {
            id: footnote

            Layout.fillWidth: true
            visible: Keybinds.available
            text: "Moonlight's \"Capture system keyboard shortcuts\" must be on or none of these arrive. Ctrl+Alt+Shift+K toggles it mid-stream."
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            wrapMode: Text.WordWrap
        }
    }
}
