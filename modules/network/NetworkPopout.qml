import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The wifi popout, hanging off the network icon in the bar.
//
// groot is a wired host with a static address, so ethernet is shown first and
// wifi is the exception rather than the headline. The scan only runs while this
// is open — see services/Net.qml.

Panel {
    id: root

    edge: "top"
    open: ShellState.network
    implicitWidth: 340
    implicitHeight: Math.min(420, body.implicitHeight + Appearance.padding.lg * 2)
    radius: Appearance.rounding.large

    ColumnLayout {
        id: body
        anchors.fill: parent
        spacing: Appearance.spacing.md

        // --- Current connection ---------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            Icon {
                text: Net.icon()
                filled: true
                color: Net.connected ? Theme.accent : Theme.error
                size: Appearance.font.size.xl
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Net.label()
                    color: Theme.text
                    font.pixelSize: Appearance.font.size.md
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Net.ethernet !== "" ? "Wired" : Net.wifi !== "" ? `Wireless · ${Net.strength}%` : "Not connected"
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        // --- Wifi radio -----------------------------------------------------
        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: "Wi-Fi"
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.sm
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: 40
                implicitHeight: 22
                radius: height / 2
                color: Net.wifiEnabled ? Theme.accentContainer : Theme.surfaceContainerHighest

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Rectangle {
                    y: 3
                    x: Net.wifiEnabled ? parent.width - width - 3 : 3
                    width: 16
                    height: 16
                    radius: 8
                    color: Net.wifiEnabled ? Theme.onAccentContainer : Theme.textMuted

                    Behavior on x {
                        enabled: Appearance.anim.enabled
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Net.setWifiEnabled(!Net.wifiEnabled)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Net.scanning ? "Scanning…" : Net.networks.count === 0 ? "No networks found" : ""
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            visible: text !== ""
        }

        // --- Available networks ---------------------------------------------
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(220, contentHeight)
            visible: Net.wifiEnabled && Net.networks.count > 0
            clip: true
            spacing: 2
            model: Net.networks

            delegate: Rectangle {
                id: network

                required property string ssid
                required property int signal
                required property bool secured
                required property bool active

                width: ListView.view.width
                implicitHeight: 40
                radius: Appearance.rounding.small
                color: active ? Theme.accentContainer : netHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.sm
                    anchors.rightMargin: Appearance.padding.sm
                    spacing: Appearance.spacing.sm

                    Icon {
                        text: network.signal > 66 ? "wifi" : network.signal > 33 ? "wifi_2_bar" : "wifi_1_bar"
                        color: network.active ? Theme.onAccentContainer : Theme.textSecondary
                        size: Appearance.font.size.md
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: network.ssid
                        color: network.active ? Theme.onAccentContainer : Theme.text
                        font.pixelSize: Appearance.font.size.sm
                    }

                    Icon {
                        text: "lock"
                        color: Theme.textMuted
                        size: Appearance.font.size.xs
                        visible: network.secured
                    }
                }

                MouseArea {
                    id: netHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Only networks NetworkManager already has a profile for.
                    // Prompting for a passphrase here would mean a password
                    // field inside a layer surface on a host whose only input
                    // arrives over a game stream; `nmcli` over SSH is the better
                    // place to join a new network for the first time.
                    onClicked: if (!network.active) Net.connect(network.ssid, "")
                }
            }
        }
    }
}
