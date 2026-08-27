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
// Caelestia's is vertical down the left. This one is horizontal along the top,
// which changes more than it sounds like: workspace pips read left-to-right as a
// strip, the window title gets real width instead of being truncated to an icon,
// and the centre becomes a natural place to hang the island off.

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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.inset + Appearance.padding.md
        anchors.rightMargin: root.inset + Appearance.padding.md
        anchors.topMargin: root.inset
        spacing: Appearance.spacing.md

        // --- Workspaces -----------------------------------------------------
        RowLayout {
            spacing: Appearance.spacing.xs
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: Config.bar.workspaces

                delegate: Item {
                    id: pip
                    required property int index

                    readonly property int wsId: index + 1
                    readonly property var ws: Hyprland.workspaces.values.find(w => w.id === pip.wsId) ?? null
                    readonly property bool occupied: (ws?.lastIpcObject?.windows ?? 0) > 0
                    readonly property bool active: Hyprland.focusedWorkspace?.id === pip.wsId

                    implicitWidth: active ? 30 : 14
                    implicitHeight: 14

                    Behavior on implicitWidth {
                        enabled: Appearance.anim.enabled
                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.emphasised
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.implicitWidth
                        height: 6
                        radius: height / 2
                        // Three states worth distinguishing: where you are, where
                        // there is something to go back to, and empty.
                        color: pip.active ? Theme.accent : pip.occupied ? Theme.outline : Theme.outlineVariant

                        Behavior on color {
                            enabled: Appearance.anim.enabled
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        // A 14px target is too small to hit reliably with a
                        // pointer that has crossed a network.
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`workspace ${pip.wsId}`)
                    }
                }
            }
        }

        // --- Active window --------------------------------------------------
        StyledText {
            Layout.fillWidth: true
            Layout.maximumWidth: root.width / 4
            text: Hyprland.activeToplevel?.title ?? ""
            color: Theme.textSecondary
            font.pixelSize: Appearance.font.size.sm
            elide: Text.ElideRight
        }

        Item {
            Layout.fillWidth: true
        }

        // --- Clock: the island's handle -------------------------------------
        Rectangle {
            id: clock
            visible: Config.bar.showClock
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: clockText.implicitWidth + Appearance.padding.lg * 2
            implicitHeight: Config.bar.height - Appearance.padding.xs * 2
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
                font.pixelSize: Appearance.font.size.sm
            }

            MouseArea {
                id: clockHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggle("island")
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // --- Tray -----------------------------------------------------------
        RowLayout {
            visible: Config.bar.showTray
            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.spacing.sm

            Repeater {
                model: SystemTray.items

                delegate: MouseArea {
                    required property SystemTrayItem modelData

                    implicitWidth: 20
                    implicitHeight: 20
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: mouse => {
                        // Right-click is the menu, left is the app's own action.
                        // fcitx5 is the main tray citizen on groot and its
                        // right-click menu is how you switch input method.
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

        // --- Status ---------------------------------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.spacing.sm

            // Only visible in game mode — a persistent reminder that the desktop
            // is deliberately stripped, so a missing bar never looks like a
            // crash. (The bar is collapsed in game mode, so in practice this is
            // seen during the transition and on the game workspace's edges.)
            Icon {
                visible: GameMode.enabled
                text: "sports_esports"
                color: Theme.accent
                filled: true
                size: Appearance.font.size.md
            }

            Icon {
                text: Net.icon()
                color: Net.connected ? Theme.textSecondary : Theme.error
                size: Appearance.font.size.md

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
                size: Appearance.font.size.md
            }

            Icon {
                text: Notifs.doNotDisturb ? "notifications_off" : Notifs.count > 0 ? "notifications_active" : "notifications"
                color: Notifs.count > 0 && !Notifs.doNotDisturb ? Theme.accent : Theme.textSecondary
                size: Appearance.font.size.md

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
