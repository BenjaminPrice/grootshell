import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// The at-a-glance tab: time, uptime, and quick toggles.

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        StyledText {
            text: Time.format("HH:mm")
            font.pixelSize: Appearance.font.size.xxl
            font.family: Appearance.font.family.sans
            color: Theme.text
        }

        StyledText {
            text: Time.format("dddd, d MMMM")
            color: Theme.textSecondary
            font.pixelSize: Appearance.font.size.sm
        }

        StyledText {
            text: `up ${Sys.formatUptime()}`
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            // Uptime comes from the metrics poll, which only runs while the
            // performance tab is open — so this shows the last known value
            // rather than nothing, and simply does not tick here.
            visible: Sys.uptime > 0
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            Toggle {
                icon: Notifs.doNotDisturb ? "notifications_off" : "notifications"
                label: "Do not disturb"
                active: Notifs.doNotDisturb
                onToggled: Notifs.doNotDisturb = !Notifs.doNotDisturb
            }

            Toggle {
                icon: "sports_esports"
                label: "Game mode"
                active: GameMode.enabled
                // Deliberately routed through the same script Sunshine uses
                // rather than flipping the flag here: game mode is a compositor
                // change plus a workspace change, and this service only mirrors
                // it. Flipping the flag alone would desync the shell from the
                // desktop it is describing.
                onToggled: modeProc.running = true
            }

            Toggle {
                icon: Net.wifiEnabled ? "wifi" : "wifi_off"
                label: "Wi-Fi"
                active: Net.wifiEnabled
                onToggled: Net.setWifiEnabled(!Net.wifiEnabled)
            }
        }
    }

    Process {
        id: modeProc
        running: false
        command: ["groot-mode", "toggle"]
    }

    component Toggle: Rectangle {
        id: toggle

        property string icon
        property string label
        property bool active

        signal toggled

        Layout.fillWidth: true
        implicitHeight: 62
        radius: Appearance.rounding.normal
        color: active ? Theme.accentContainer : hover.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        Behavior on color {
            enabled: Appearance.anim.enabled
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Icon {
                Layout.alignment: Qt.AlignHCenter
                text: toggle.icon
                filled: toggle.active
                color: toggle.active ? Theme.accent : Theme.textSecondary
                size: Appearance.font.size.lg
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: toggle.label
                color: toggle.active ? Theme.accent : Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }
}
