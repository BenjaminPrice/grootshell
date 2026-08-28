import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// The wallpaper picker, as a tab in the island.
//
// It used to be a panel of its own, extruded from the bottom edge on SUPER+P.
// That gave it a whole screen width to work with and cost a top-level panel, an
// entry in the exclusive-open list, a mask region and an IPC target — all for a
// thing you reach for once a week. Folding it into the island puts it beside the
// dashboard and the media tab, where it is one of a set of things you open the
// island to look at, which is what it always was.
//
// ## Applying on selection
//
// Moving the selection APPLIES it, after a short pause. There is no confirm
// step, because the only way to judge a wallpaper is to see it on the screen at
// full size with the shell's colours regenerated over it — a 290px thumbnail
// cannot answer that question, and a picker that makes you commit before you can
// tell is asking you to guess.
//
// The pause is what makes that affordable. Every apply regenerates the entire
// Material 3 palette through matugen, which is a subprocess and roughly a
// second of work, so a sweep through twenty images with the arrow keys must not
// be twenty of those. The timer restarts on every move and only the image you
// come to rest on is ever generated.
//
// Hover deliberately does NOT select, which is the one place this departs from
// the panel it replaces. With apply-on-select, hovering would mean dragging the
// pointer across the grid changes the desktop under it — and the reason to move
// a pointer across a grid is usually to get to the other side of it.
//
// Named WallpaperTab rather than Wallpaper: `Wallpapers` is already the service
// singleton next door, and two types one letter apart, one of which is the
// model the other one renders, is a mistake waiting to happen.

Item {
    id: root

    // False for every tab that is not on screen. A StackLayout keeps all of its
    // pages alive, so without this the grid would decode a screenful of
    // photographs the moment the island opened on ANY tab.
    property bool active: false

    // How long the selection has to sit still before it is applied. Long enough
    // to arrow past an image without generating it, short enough that resting on
    // one does not feel like waiting for permission.
    readonly property int debounce: 500

    property int selected: 0

    readonly property int columns: 3
    readonly property int gutter: Appearance.spacing.md

    onActiveChanged: {
        if (!root.active) {
            // Never leave a pending apply behind. Switching tabs or closing the
            // island half a second after the last arrow key would otherwise
            // change the wallpaper from a panel that is no longer on screen.
            apply.stop();
            return;
        }
        // Start from what is actually set rather than from wherever the
        // selection was left last time the tab was open.
        const i = Wallpapers.indexOf(Wallpapers.current);
        root.selected = i >= 0 ? i : 0;
        Qt.callLater(root.reveal);
    }

    function reveal(): void {
        if (root.active)
            grid.positionViewAtIndex(root.selected, GridView.Contain);
    }

    // `immediate` is for a click, which is a decision rather than a browse — it
    // has already cost the deliberate act of aiming at one tile, so there is
    // nothing left to debounce.
    function select(index: int, immediate: bool): void {
        if (Wallpapers.count === 0)
            return;
        root.selected = Math.max(0, Math.min(Wallpapers.count - 1, index));
        grid.positionViewAtIndex(root.selected, GridView.Contain);
        if (immediate) {
            apply.stop();
            root.applyNow();
        } else {
            apply.restart();
        }
    }

    function applyNow(): void {
        const path = Wallpapers.at(root.selected);
        if (path)
            Wallpapers.set(path);
    }

    Timer {
        id: apply
        interval: root.debounce
        onTriggered: root.applyNow()
    }

    // Claims all four arrows, which is why Island.qml reserves Tab and Shift+Tab
    // for leaving a tab regardless of what it takes. A grid without Up and Down
    // is a list drawn in a confusing shape.
    function handleKey(event): bool {
        switch (event.key) {
        case Qt.Key_Left:
            root.select(root.selected - 1, false);
            return true;
        case Qt.Key_Right:
            root.select(root.selected + 1, false);
            return true;
        case Qt.Key_Up:
            root.select(root.selected - root.columns, false);
            return true;
        case Qt.Key_Down:
            root.select(root.selected + root.columns, false);
            return true;
        case Qt.Key_Home:
            root.select(0, false);
            return true;
        case Qt.Key_End:
            root.select(Wallpapers.count - 1, false);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            // Skip the wait. You have already decided.
            apply.stop();
            root.applyNow();
            return true;
        case Qt.Key_M:
            Theming.cycleMode();
            return true;
        }
        return false;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        // --- Header ---------------------------------------------------------
        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            StyledText {
                // The filename of whatever is selected, so the grid is navigable
                // by name as well as by eye.
                Layout.fillWidth: true
                text: {
                    const path = Wallpapers.at(root.selected);
                    return path ? path.slice(path.lastIndexOf("/") + 1) : "";
                }
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
                elide: Text.ElideMiddle
            }

            // Says why the wallpaper has not changed yet, during the half second
            // where it is about to. Without it a fast arrow-key sweep looks like
            // the picker has stopped responding.
            StyledText {
                visible: apply.running
                text: "applying…"
                color: Theme.accent
                font.pixelSize: Appearance.font.size.xs
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
            //
            // Clickable now as well as bound to M. It lived in a keyboard-driven
            // strip before; here it sits in a panel you are as likely to have
            // arrived at with the pointer.
            Rectangle {
                implicitWidth: modeRow.implicitWidth + Appearance.padding.md * 2
                implicitHeight: modeRow.implicitHeight + Appearance.padding.xs * 2
                radius: Appearance.rounding.full
                color: Persist.themeMode === "auto" ? (modeHover.containsMouse ? Theme.surfaceContainerHigh : "transparent") : Theme.accentContainer
                border.width: Persist.themeMode === "auto" ? 1 : 0
                border.color: Theme.outlineVariant

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

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

                MouseArea {
                    id: modeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Theming.cycleMode()
                }
            }
        }

        // --- Empty ----------------------------------------------------------
        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Wallpapers.count === 0
            icon: "wallpaper"
            title: "No wallpapers found"
            detail: `Put images in ${Config.wallpaper.directory.replace(Quickshell.env("HOME"), "~")}`
        }

        // --- Grid -----------------------------------------------------------
        GridView {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Wallpapers.count > 0
            clip: true

            // Sized to fit exactly `columns` across whatever width the island
            // gives us, rather than to a fixed tile size that would leave a
            // ragged strip down one side at any other scale.
            cellWidth: Math.floor(width / root.columns)
            cellHeight: Math.round(cellWidth * 9 / 16) + root.gutter

            model: Wallpapers.model
            // A screenful either side stays rendered, so an arrow-key sweep does
            // not show empty frames where thumbnails should be.
            cacheBuffer: height * 2

            delegate: Item {
                id: tile

                required property int index
                required property string filePath

                readonly property bool isCurrent: filePath === Wallpapers.current
                readonly property bool isSelected: index === root.selected

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: root.gutter
                    anchors.bottomMargin: root.gutter
                    radius: Appearance.rounding.normal
                    color: Theme.surfaceContainerHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Nothing decodes until the tab is on screen. See
                        // `active` above.
                        source: root.active ? `file://${tile.filePath}` : ""
                        // Decoded at the size it is drawn, at 2x for the
                        // scaling knob. This is what the old thumbnail cache
                        // was for, done by the decoder instead.
                        sourceSize.height: grid.cellHeight * 2
                    }

                    // Selection is a ring, not a tint — a tint would
                    // misrepresent the colours of the image you are trying to
                    // judge, which is the entire job of this grid.
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

                    // What is actually SET, as distinct from what is selected.
                    // With apply-on-select the two are the same most of the
                    // time, and differ exactly during the half second that
                    // matters — which is when this earns its place.
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
                    anchors.rightMargin: root.gutter
                    anchors.bottomMargin: root.gutter
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // No onEntered. See the note at the top: with
                    // apply-on-select, hover-to-select would change the desktop
                    // for every tile the pointer crossed on its way somewhere.
                    onClicked: root.select(tile.index, true)
                }
            }
        }
    }
}
