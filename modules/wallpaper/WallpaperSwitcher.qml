import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// A horizontal strip of wallpapers along the bottom edge.
//
// Horizontal because wallpapers are landscape: a vertical list wastes most of
// its width on letterboxing, where a strip shows six at a usable size.
//
// Thumbnails come from the on-disk cache (see services/Wallpapers.qml) and fall
// back to the full image when one has not been generated yet — so the switcher
// is usable immediately on a fresh checkout and merely gets faster once the
// cache fills.

Panel {
    id: root

    edge: "bottom"
    open: ShellState.wallpaper
    implicitWidth: Math.min(1200, strip.implicitWidth + Appearance.padding.lg * 2)
    implicitHeight: Config.wallpaper.thumbnailHeight + header.implicitHeight + Appearance.padding.lg * 2 + Appearance.spacing.md
    radius: Appearance.rounding.large

    onOpenChanged: if (open) list.positionViewAtIndex(root.currentIndex, ListView.Center)

    readonly property int currentIndex: {
        for (let i = 0; i < Wallpapers.model.count; i++)
            if (Wallpapers.model.get(i, "filePath") === Wallpapers.current)
                return i;
        return 0;
    }

    ColumnLayout {
        id: strip
        anchors.fill: parent
        spacing: Appearance.spacing.md

        RowLayout {
            id: header
            Layout.fillWidth: true

            StyledText {
                text: "Wallpaper"
                font.pixelSize: Appearance.font.size.md
                color: Theme.text
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: `${Wallpapers.count} in ${Config.wallpaper.directory.replace(Quickshell.env("HOME"), "~")}`
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Config.wallpaper.thumbnailHeight
            orientation: ListView.Horizontal
            spacing: Appearance.spacing.sm
            clip: true
            model: Wallpapers.model
            // Keep a screen's worth either side rendered so a fast scroll does
            // not show empty frames.
            cacheBuffer: width * 2

            delegate: Item {
                id: tile

                required property int index
                required property string filePath

                readonly property bool selected: filePath === Wallpapers.current

                // 16:9, which is what the output is.
                implicitWidth: Config.wallpaper.thumbnailHeight * 16 / 9
                implicitHeight: Config.wallpaper.thumbnailHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Theme.surfaceContainerHigh
                    clip: true

                    Image {
                        id: thumb
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.height: Config.wallpaper.thumbnailHeight * 2
                        source: `file://${Wallpapers.thumbnail(tile.filePath)}`

                        // No cached thumbnail yet — decode the original instead
                        // rather than showing an empty box.
                        onStatusChanged: if (status === Image.Error) source = `file://${tile.filePath}`
                    }

                    // Selection reads as a ring rather than a tint, so it does
                    // not misrepresent the colours of the image underneath.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: tile.selected ? 3 : hover.containsMouse ? 2 : 0
                        border.color: tile.selected ? Theme.accent : Theme.outline

                        Behavior on border.width {
                            enabled: Appearance.anim.enabled
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpapers.set(tile.filePath)
                }
            }
        }
    }
}
