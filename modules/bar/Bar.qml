import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The top bar, as a row of floating pills rather than a band.
//
// It used to paint Theme.frame edge to edge across its whole height, which put
// 64px of solid chrome along the top of the screen and made the frame look four
// times thicker there than on the other three sides. Now it paints nothing: the
// frame's top band stays the same 10px as everywhere else, and the bar is three
// capsules floating in front of the wallpaper below it.
//
// The window underneath still reserves the full height (see shell.qml), so
// windows tile below the pills rather than sliding under them. The strip is
// transparent, not absent — what changed is that it is no longer painted.
//
// Three independently anchored groups, NOT one RowLayout with spacers. That
// matters: spacers centre a widget in the space left over after its neighbours,
// so the clock drifts by half the difference between the left and right groups
// and is never actually centred. Anchoring the centre group to the bar's own
// horizontalCenter is the only arrangement that survives the sides changing
// width — which they do constantly, as window titles and tray icons come and go.

Item {
    id: root

    required property ShellScreen screen

    readonly property int inset: Config.border.thickness

    clip: true

    // Deliberately no background. See above — the frame's own top band is drawn
    // by modules/border and is all the chrome the top of the screen gets.

    // The content strip, below the frame's top edge.
    Item {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // Clear of the frame's side bands by a little more than their own width,
        // so the pills read as floating in front of the frame rather than as
        // being wedged against it.
        anchors.leftMargin: root.inset + Appearance.spacing.sm
        anchors.rightMargin: root.inset + Appearance.spacing.sm
        anchors.topMargin: root.inset
        anchors.bottom: parent.bottom

        // --- Left -----------------------------------------------------------
        RowLayout {
            id: left

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.sm

            // Its own pill, drawn by the widget itself: the track it already
            // needed as a container for the workspace slots IS the capsule, and
            // wrapping it in another one would be a pill inside a pill.
            Workspaces {}

            // The focused window's title, in a pill of its own.
            //
            // Separate rather than tucked in beside the workspaces, because it
            // is the one thing up here whose width is unbounded — sharing a
            // capsule would make that capsule breathe on every window change.
            // It disappears entirely when there is no title, so an empty
            // workspace does not leave a stub of chrome behind.
            Pill {
                id: titlePill

                readonly property string title: {
                    const t = Hyprland.activeToplevel;
                    if (!t)
                        return "";
                    // Cross-checked against the focused workspace rather than
                    // read straight off activeToplevel. Switching to an empty
                    // workspace left the previous window's title sitting in the
                    // bar: Hyprland clears its own active window, but the
                    // toplevel this side keeps pointing at the last window that
                    // had focus. Asking "is it on the workspace I am actually
                    // looking at" is true regardless of which of the two is
                    // stale.
                    const ws = t.workspace?.id ?? -1;
                    return ws === (Hyprland.focusedWorkspace?.id ?? -1) ? (t.title ?? "") : "";
                }

                visible: titlePill.title !== ""

                StyledText {
                    // Hard-capped rather than fillWidth: this must never grow
                    // into the centre group, which is anchored independently and
                    // would simply be overlapped.
                    Layout.maximumWidth: Math.max(0, (strip.width - centre.width) / 2 - Appearance.spacing.xl * 2)
                    text: titlePill.title
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }
            }
        }

        // --- Centre ---------------------------------------------------------
        RowLayout {
            id: centre

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.sm

            Pill {
                id: clock

                visible: Config.bar.showClock
                hpad: Appearance.padding.xl
                // Fills with the accent while the island is down, so the pill
                // reads as the handle the drawer is hanging from.
                color: ShellState.island ? Theme.accentContainer : clockHover.containsMouse ? Theme.surfaceContainerHigh : Theme.frame

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                StyledText {
                    text: Time.format(Config.bar.clockFormat)
                    color: ShellState.island ? Theme.onAccentContainer : Theme.text
                    font.pixelSize: Appearance.font.size.md
                }

                MouseArea {
                    id: clockHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.toggle("island")
                }
            }
        }

        // --- Right ----------------------------------------------------------
        //
        // One pill for the tray and the status glyphs together. They are all
        // "the state of the machine" and splitting them into two capsules would
        // draw a distinction that is not there.
        Pill {
            id: right

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.md

            RowLayout {
                visible: Config.bar.showTray
                spacing: Appearance.spacing.sm

                Repeater {
                    model: SystemTray.items

                    delegate: MouseArea {
                        id: trayItem
                        required property SystemTrayItem modelData

                        // Larger than the Material Symbols icons beside it on
                        // purpose. IconImage fits its source with
                        // PreserveAspectFit, so a non-square tray icon gets
                        // padded and renders visibly smaller than the box it was
                        // given — matching the numbers made it look mismatched.
                        implicitWidth: Config.bar.trayIconSize
                        implicitHeight: implicitWidth
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: mouse => {
                            // Right-click is the menu, left is the app's own
                            // action. fcitx5 is the main tray citizen on groot
                            // and its right-click menu is how you switch input
                            // method.
                            if (mouse.button !== Qt.RightButton) {
                                const id = trayItem.modelData.id ?? "";
                                const fallback = Config.bar.trayFallback?.[id];

                                // onlyMenu is the compliant way of saying "I
                                // have no primary action"; the fallback covers
                                // the items that simply omit Activate without
                                // saying so.
                                if (fallback)
                                    Apps.launch(fallback);
                                else if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                                    trayItem.modelData.display(QsWindow.window, mouse.x, mouse.y);
                                else
                                    trayItem.modelData.activate();
                                return;
                            }

                            // Coordinates are relative to the WINDOW, not to
                            // this item. Passing local ones put every menu at
                            // the window's top-left corner regardless of which
                            // icon was clicked; mapping to the scene is what
                            // makes it open under the pointer.
                            const at = trayItem.mapToItem(null, mouse.x, mouse.y);
                            trayItem.modelData.display(QsWindow.window, at.x, at.y);
                        }

                        IconImage {
                            anchors.fill: parent
                            implicitSize: trayItem.implicitWidth
                            source: trayItem.modelData.icon
                            asynchronous: true
                        }
                    }
                }
            }

            RowLayout {
                spacing: Appearance.spacing.sm

                // Only visible in game mode — a persistent reminder that the
                // desktop is deliberately stripped, so a missing bar never looks
                // like a crash.
                Icon {
                    visible: GameMode.enabled
                    text: "sports_esports"
                    color: Theme.accent
                    filled: true
                    size: Appearance.font.size.lg
                }

                // No network indicator. groot is wired and has never been
                // anything else, so it was a permanently green icon reporting a
                // fact that cannot change — and the one thing it did report,
                // going down, is not something a status glyph is going to be
                // the way you find out about. The popout still exists and its
                // IPC handler still opens it, for the day this machine is
                // somewhere with wifi.

                Icon {
                    text: Volume.icon()
                    color: Volume.muted ? Theme.error : Theme.textSecondary
                    size: Appearance.font.size.lg

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        // Toggles mute, and the readout on the right edge shows
                        // itself because the service emits a change — the same
                        // path a volume key takes. No special case for "opened
                        // from the bar", so there is one way the OSD appears.
                        onClicked: Volume.toggleMute()
                    }
                }

                Icon {
                    text: Notifs.doNotDisturb ? "notifications_off" : Notifs.count > 0 ? "notifications_active" : "notifications"
                    color: Notifs.count > 0 && !Notifs.doNotDisturb ? Theme.accent : Theme.textSecondary
                    size: Appearance.font.size.lg

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.toggle("notifications")
                    }
                }
            }
        }
    }
}
