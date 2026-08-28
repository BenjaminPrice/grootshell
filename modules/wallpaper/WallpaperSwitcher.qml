import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// A wide strip of wallpaper previews across the bottom of the screen.
//
// Horizontal because wallpapers are landscape: a vertical list spends most of
// its width on letterboxing, where a strip shows several at a size you can
// actually judge. Big previews for the same reason — a 130px tile tells you the
// rough colour of an image and nothing about whether you want to look at it all
// day.
//
// Driven by the keyboard as much as the pointer. Left and right move the
// selection, Enter applies it, Escape closes; clicking a tile applies it
// directly. On a machine reached through a stream the keyboard is usually the
// more reliable of the two.
//
// Selection and current are different things and look different: the ring marks
// what you are pointing at, the filled label marks what is actually set. Without
// that split, arrowing through the strip gives no way to find your way back.

// Docked rather than floating: it is drawn in the frame colour, flush to the
// bottom edge, with its junctions filleted so it reads as the border stretching
// outward to make room for the strip. See components/DockedPanel.qml — the
// notification surfaces will use the same thing.
DockedPanel {
    id: root

    edge: "bottom"
    open: ShellState.wallpaper
    padding: Appearance.padding.xl

    readonly property int tileHeight: Math.round(200 * Appearance.font.scale)
    readonly property int tileWidth: Math.round(tileHeight * 16 / 9)

    // Inset from the screen edges by more than the frame, so the fillets have
    // frame to curve into on both sides rather than running off the corner.
    span: Math.max(0, (parent?.width ?? 1920) - Config.border.thickness * 2 - Appearance.spacing.xl * 4)
    depth: tileHeight + header.implicitHeight + Appearance.spacing.md + Appearance.padding.xl * 2

    property int selected: 0

    onOpenChanged: {
        if (!open)
            return;
        // Start from what is currently set, not from wherever the selection was
        // left last time.
        const i = Wallpapers.indexOf(Wallpapers.current);
        selected = i >= 0 ? i : 0;
        // Deferred: focus cannot be taken until the panel is actually on screen,
        // and it is not yet — the extrusion animates up from zero height, so on
        // this frame there is nothing to focus. callLater runs it once the
        // current pass has settled.
        Qt.callLater(root.grabFocus);
    }

    function grabFocus(): void {
        if (!root.open)
            return;
        strip.positionViewAtIndex(root.selected, ListView.Center);
        strip.forceActiveFocus();
    }

    function move(delta: int): void {
        if (Wallpapers.count === 0)
            return;
        selected = Math.max(0, Math.min(Wallpapers.count - 1, selected + delta));
        strip.positionViewAtIndex(selected, ListView.Contain);
    }

    function apply(): void {
        const path = Wallpapers.at(selected);
        if (path)
            Wallpapers.set(path);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            Icon {
                text: "wallpaper"
                color: Theme.accent
                filled: true
                size: Appearance.font.size.lg
            }

            StyledText {
                text: "Wallpaper"
                font.pixelSize: Appearance.font.size.md
                color: Theme.text
            }

            StyledText {
                // The filename of whatever is selected, so the strip is
                // navigable by name as well as by eye.
                Layout.fillWidth: true
                text: {
                    const path = Wallpapers.at(root.selected);
                    return path ? path.slice(path.lastIndexOf("/") + 1) : "";
                }
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                elide: Text.ElideMiddle
            }

            StyledText {
                text: Wallpapers.count > 0 ? `${root.selected + 1} / ${Wallpapers.count}` : ""
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }

            // The light/dark override, shown rather than hidden behind the key.
            // Brightness detection is a heuristic and gets the occasional image
            // wrong; when it does, this is where you are already standing.
            Rectangle {
                implicitWidth: modeRow.implicitWidth + Appearance.padding.md * 2
                implicitHeight: modeRow.implicitHeight + Appearance.padding.xs * 2
                radius: Appearance.rounding.full
                color: Persist.themeMode === "auto" ? "transparent" : Theme.accentContainer
                border.width: Persist.themeMode === "auto" ? 1 : 0
                border.color: Theme.outlineVariant

                RowLayout {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.xs

                    Icon {
                        text: Persist.themeMode === "light" ? "light_mode" : Persist.themeMode === "dark" ? "dark_mode" : "brightness_auto"
                        color: Persist.themeMode === "auto" ? Theme.textMuted : Theme.onAccentContainer
                        size: Appearance.font.size.xs
                    }

                    StyledText {
                        text: `${Persist.themeMode}  ·  M`
                        color: Persist.themeMode === "auto" ? Theme.textMuted : Theme.onAccentContainer
                        font.pixelSize: Appearance.font.size.xs
                    }
                }
            }
        }

        // --- Empty ----------------------------------------------------------
        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Wallpapers.count === 0
            title: "No wallpapers found"
            detail: `Put images in ${Config.wallpaper.directory.replace(Quickshell.env("HOME"), "~")}`
        }

        // --- Strip ----------------------------------------------------------
        ListView {
            id: strip

            Layout.fillWidth: true
            Layout.preferredHeight: root.tileHeight
            visible: Wallpapers.count > 0

            orientation: ListView.Horizontal
            spacing: Appearance.spacing.md
            clip: true
            model: Wallpapers.model
            // A screen's worth either side stays rendered, so a fast arrow-key
            // sweep does not show empty frames.
            cacheBuffer: width * 2

            // No `focus: true` here: that competes with the focus the overlay
            // Item in shell.qml holds for Escape. Taking active focus explicitly
            // once open leaves Escape to bubble up from here, which is what
            // closes the panel.
            Keys.onLeftPressed: root.move(-1)
            Keys.onRightPressed: root.move(1)
            Keys.onReturnPressed: root.apply()
            Keys.onEnterPressed: root.apply()
            Keys.onSpacePressed: root.apply()

            // M cycles auto -> light -> dark. Not a compositor bind: it only
            // means anything while this panel has focus, and spending a global
            // chord on it would be spending it on something used once a month.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_M) {
                    Theming.cycleMode();
                    event.accepted = true;
                }
            }

            delegate: Item {
                id: tile

                required property int index
                required property string filePath

                readonly property bool isCurrent: filePath === Wallpapers.current
                readonly property bool isSelected: index === root.selected

                implicitWidth: root.tileWidth
                implicitHeight: root.tileHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Theme.surfaceContainerHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        source: `file://${tile.filePath}`
                        // Decoded at the size it is drawn, which is what the
                        // thumbnail cache used to be for.
                        sourceSize.height: root.tileHeight * 2
                    }

                    // Selection is a ring, not a tint — a tint would misrepresent
                    // the colours of the image you are trying to judge.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: tile.isSelected ? 3 : hover.containsMouse ? 2 : 0
                        border.color: Theme.accent

                        Behavior on border.width {
                            enabled: Appearance.anim.enabled
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    // What is actually set, as distinct from what is selected.
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: Appearance.spacing.sm
                        visible: tile.isCurrent
                        implicitWidth: currentRow.implicitWidth + Appearance.padding.md * 2
                        implicitHeight: currentRow.implicitHeight + Appearance.padding.xs * 2
                        radius: Appearance.rounding.full
                        color: Theme.accentContainer

                        RowLayout {
                            id: currentRow
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.xs

                            Icon {
                                text: "check"
                                color: Theme.onAccentContainer
                                size: Appearance.font.size.xs
                            }

                            StyledText {
                                text: "Current"
                                color: Theme.onAccentContainer
                                font.pixelSize: Appearance.font.size.xs
                            }
                        }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selected = tile.index
                    onClicked: Wallpapers.set(tile.filePath)
                }
            }
        }
    }
}
