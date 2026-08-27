import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The top bar.
//
// Inset by the border thickness so it sits *inside* the frame rather than on top
// of it — the bar is the top edge of the content area, not a separate strip
// above it.
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

    implicitHeight: GameMode.enabled ? 0 : Config.bar.height + inset
    visible: implicitHeight > 0
    clip: true

    Behavior on implicitHeight {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    // The content strip, below the frame's top edge.
    Item {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.inset + Appearance.padding.lg
        anchors.rightMargin: root.inset + Appearance.padding.lg
        anchors.topMargin: root.inset
        height: Config.bar.height

        // --- Left -----------------------------------------------------------
        RowLayout {
            id: left

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.md

            Workspaces {}

            StyledText {
                // Hard-capped rather than fillWidth: this must never grow into
                // the centre group, which is anchored independently and would
                // simply be overlapped.
                Layout.maximumWidth: Math.max(0, (strip.width - centre.width) / 2 - Appearance.spacing.xl)
                text: Hyprland.activeToplevel?.title ?? ""
                color: Theme.textSecondary
                elide: Text.ElideRight
            }
        }

        // --- Centre ---------------------------------------------------------
        RowLayout {
            id: centre

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.sm

            Rectangle {
                id: clock
                visible: Config.bar.showClock
                implicitWidth: clockText.implicitWidth + Appearance.padding.xl * 2
                implicitHeight: Config.bar.height - Appearance.padding.sm * 2
                radius: Appearance.rounding.full
                color: ShellState.island ? Theme.accentContainer : clockHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                StyledText {
                    id: clockText
                    anchors.centerIn: parent
                    text: Time.format(Config.bar.clockFormat)
                    color: ShellState.island ? Theme.accent : Theme.text
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
        RowLayout {
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
                        required property SystemTrayItem modelData

                        implicitWidth: Appearance.font.size.lg
                        implicitHeight: implicitWidth
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: mouse => {
                            // Right-click is the menu, left is the app's own
                            // action. fcitx5 is the main tray citizen on groot
                            // and its right-click menu is how you switch input
                            // method.
                            if (mouse.button === Qt.RightButton)
                                modelData.display(QsWindow.window, width / 2, height);
                            else
                                modelData.activate();
                        }

                        IconImage {
                            anchors.fill: parent
                            source: modelData.icon
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

                Icon {
                    text: Net.icon()
                    color: Net.connected ? Theme.textSecondary : Theme.error
                    size: Appearance.font.size.lg

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Net.scan();
                            ShellState.toggle("network");
                        }
                    }
                }

                Icon {
                    text: Audio.icon()
                    color: Audio.muted ? Theme.error : Theme.textSecondary
                    size: Appearance.font.size.lg
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
