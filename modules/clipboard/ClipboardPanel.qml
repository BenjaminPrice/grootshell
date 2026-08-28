import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Clipboard history from cliphist.
//
// Rises from the bottom like the launcher and behaves like it — type to filter,
// Enter to copy — because it is the same gesture: find a thing, pick it. The
// filter is client-side over the already-listed entries rather than re-running
// cliphist, since the list is small and already in memory.

Panel {
    id: root

    edge: "bottom"
    open: ShellState.clipboard
    implicitWidth: Config.launcher.width
    implicitHeight: 420
    radius: Appearance.rounding.large

    onOpenChanged: {
        if (open) {
            filter.text = "";
            selected = 0;
            filter.forceActiveFocus();
        }
    }

    property int selected: 0

    readonly property var filtered: {
        const q = filter.text.toLowerCase();
        const out = [];
        for (let i = 0; i < Clipboard.entries.count; i++) {
            const e = Clipboard.entries.get(i);
            if (q === "" || e.preview.toLowerCase().includes(q))
                out.push(e);
        }
        return out;
    }

    onFilteredChanged: selected = 0

    function activate(): void {
        const entry = filtered[selected];
        if (!entry)
            return;
        Clipboard.copy(entry.entryId);
        ShellState.close("clipboard");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            Icon {
                text: "content_paste"
                color: Theme.textSecondary
                size: Appearance.font.size.lg
            }

            TextInput {
                id: filter

                Layout.fillWidth: true
                font.family: Appearance.font.family.sans
                font.pixelSize: Appearance.font.size.md
                color: Theme.text
                selectionColor: Theme.accentContainer
                selectedTextColor: Theme.onAccentContainer
                clip: true

                onAccepted: root.activate()
                Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.filtered.length - 1)
                Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clipboard.loading ? "Loading…" : "Filter clipboard history"
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.md
                    visible: filter.text === ""
                }
            }

            Icon {
                text: "delete_sweep"
                color: wipeHover.containsMouse ? Theme.error : Theme.textMuted
                size: Appearance.font.size.md

                MouseArea {
                    id: wipeHover
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Clipboard.clear()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.filtered
            currentIndex: root.selected
            highlightMoveDuration: Appearance.anim.enabled ? Appearance.anim.fast : 0
            // Keep the selection on screen when navigating by keyboard.
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 40
            preferredHighlightEnd: height - 40

            delegate: Rectangle {
                id: entry

                required property var modelData
                required property int index

                width: ListView.view.width
                implicitHeight: 42
                radius: Appearance.rounding.small
                color: index === root.selected ? Theme.accentContainer : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.sm
                    anchors.rightMargin: Appearance.padding.sm
                    spacing: Appearance.spacing.sm

                    Icon {
                        text: entry.modelData.isImage ? "image" : "notes"
                        color: Theme.textMuted
                        size: Appearance.font.size.md
                    }

                    StyledText {
                        Layout.fillWidth: true
                        // cliphist collapses newlines into its own escape; show
                        // the text on one line either way, because a clipboard
                        // row is an identifier not a document.
                        text: entry.modelData.preview.replace(/\s+/g, " ").trim()
                        color: index === root.selected ? Theme.onAccentContainer : Theme.text
                        font.pixelSize: Appearance.font.size.sm
                        mono: !entry.modelData.isImage
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selected = entry.index
                    onClicked: root.activate()
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "Nothing in the clipboard yet"
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            visible: !Clipboard.loading && root.filtered.length === 0
        }
    }
}
