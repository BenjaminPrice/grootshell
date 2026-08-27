import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Window switcher: every open window across every desktop workspace, in one
// grid.
//
// Centred rather than docked, because unlike the other panels this is not about
// a screen edge — it is a modal "where is everything" view, and centring is what
// makes it read as one.
//
// Workspace 10 is excluded. That is where games live (see groot-mode in the
// nixos repo), and the entire point of the game workspace is that it is separate
// — surfacing a running game here would undo the split.

Panel {
    id: root

    edge: "none"
    open: ShellState.switcher
    implicitWidth: Math.min(900, grid.implicitWidth + Appearance.padding.lg * 2)
    implicitHeight: Math.min(600, grid.implicitHeight + header.implicitHeight + Appearance.padding.lg * 2 + Appearance.spacing.md)
    radius: Appearance.rounding.large
    surface: Theme.layer(2)

    readonly property var windows: {
        if (!open)
            return [];
        return Hyprland.toplevels.values.filter(t => {
            const ws = t.workspace?.id ?? 0;
            return ws >= 1 && ws <= Config.bar.workspaces;
        });
    }

    function focus(toplevel): void {
        // address is the stable handle; title changes under you and class is
        // not unique when two windows of the same app are open.
        Hyprland.dispatch(`focuswindow address:${toplevel.address}`);
        ShellState.close("switcher");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        RowLayout {
            id: header
            Layout.fillWidth: true

            StyledText {
                text: "Windows"
                font.pixelSize: Appearance.font.size.md
                color: Theme.text
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: `${root.windows.length} open`
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "Nothing open on the desktop"
            color: Theme.textMuted
            visible: root.windows.length === 0
        }

        GridView {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.windows.length > 0
            clip: true
            cellWidth: 200
            cellHeight: 120
            model: root.windows

            delegate: Item {
                id: cell
                required property var modelData

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.xs
                    radius: Appearance.rounding.normal
                    color: cellHover.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                    border.width: 1
                    border.color: Hyprland.activeToplevel?.address === cell.modelData.address ? Theme.accent : "transparent"

                    Behavior on color {
                        enabled: Appearance.anim.enabled
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.padding.md
                        spacing: Appearance.spacing.sm

                        // No live thumbnail: capturing one per window means a
                        // screencopy request per frame per window, which on a
                        // host that is already encoding its whole output for the
                        // network is a poor trade for a 200px preview.
                        IconImage {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            source: Quickshell.iconPath(cell.modelData.lastIpcObject?.class ?? "", "application-x-executable")
                            asynchronous: true
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: cell.modelData.title ?? ""
                            color: Theme.text
                            font.pixelSize: Appearance.font.size.xs
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `Workspace ${cell.modelData.workspace?.id ?? "?"}`
                            color: Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: cellHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focus(cell.modelData)
                    }
                }
            }
        }
    }
}
