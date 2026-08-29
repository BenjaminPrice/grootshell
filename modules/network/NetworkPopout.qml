import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The wifi panel.
//
// Everything a person does with wifi, without leaving the shell: join a
// protected network, reconnect to a known one, disconnect, forget, and turn the
// radio off. It used to be a viewer — you could see networks and click one
// NetworkManager already knew — which is the half that does not help on the day
// you are somewhere new.
//
// A network expands in place to ask for its passphrase rather than opening a
// dialog. A dialog would be a second surface competing for the keyboard focus
// this panel already holds, and the thing you are typing into belongs to the row
// you clicked.

Panel {
    id: root

    edge: "top"
    open: ShellState.network
    implicitWidth: 360
    implicitHeight: Math.min(520, body.implicitHeight + Appearance.padding.lg * 2)
    radius: Appearance.rounding.large

    // Which row has its passphrase field open. One at a time: two open fields
    // would be two things claiming to be what Enter submits.
    property string asking: ""

    onOpenChanged: {
        root.asking = "";
        Net.clearError();
    }

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
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Net.ethernet !== "" ? "Wired" : Net.wifi !== "" ? `Wireless · ${Net.strength}%` : "Not connected"
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }
            }

            // Only for wifi. Disconnecting ethernet from a panel you reached
            // over the network is a way to lock yourself out of the machine.
            Action {
                visible: Net.wifi !== ""
                glyph: "link_off"
                tip: "Disconnect"
                onActivated: Net.disconnect()
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

            Action {
                visible: Net.wifiEnabled
                glyph: "refresh"
                tip: "Scan again"
                spinning: Net.scanning
                onActivated: Net.scan()
            }

            Rectangle {
                implicitWidth: 40
                implicitHeight: 22
                radius: height / 2
                color: Net.wifiEnabled ? Theme.accentContainer : Theme.surfaceContainerHighest
                opacity: Net.busy ? 0.5 : 1

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
                    enabled: !Net.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Net.setWifiEnabled(!Net.wifiEnabled)
                }
            }
        }

        // --- What went wrong -------------------------------------------------
        //
        // nmcli's own words. "Secrets were required, but not provided" is what a
        // wrong passphrase looks like, and rewording it would only lose detail
        // that helps.
        Rectangle {
            Layout.fillWidth: true
            visible: Net.error !== ""
            implicitHeight: errorRow.implicitHeight + Appearance.padding.sm * 2
            radius: Appearance.rounding.small
            color: Theme.surfaceContainerHighest

            RowLayout {
                id: errorRow
                anchors.fill: parent
                anchors.margins: Appearance.padding.sm
                spacing: Appearance.spacing.sm

                Icon {
                    text: "error"
                    color: Theme.error
                    size: Appearance.font.size.md
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Net.error
                    color: Theme.textSecondary
                    font.pixelSize: Appearance.font.size.xs
                    wrapMode: Text.WordWrap
                }

                Action {
                    glyph: "close"
                    tip: "Dismiss"
                    onActivated: Net.clearError()
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: !Net.wifiEnabled ? "Wi-Fi is off" : Net.busy ? "Working…" : Net.scanning ? "Scanning…" : Net.networks.count === 0 ? "No networks found" : ""
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            visible: text !== ""
        }

        // --- Available networks ---------------------------------------------
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(280, contentHeight)
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

                readonly property bool known: Net.isSaved(network.ssid)
                readonly property bool asking: root.asking === network.ssid

                width: ListView.view.width
                implicitHeight: row.implicitHeight + (network.asking ? secret.implicitHeight + Appearance.spacing.sm : 0) + Appearance.padding.sm * 2
                radius: Appearance.rounding.small
                color: network.active ? Theme.accentContainer : netHover.containsMouse || network.asking ? Theme.surfaceContainerHigh : "transparent"

                Behavior on implicitHeight {
                    enabled: Appearance.anim.enabled
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                // Clicking the row: join it, or ask for the passphrase first.
                //
                // A saved network and an open one both join outright —
                // NetworkManager holds the secret for the first and there is
                // none for the second. Only a secured network nobody has joined
                // before needs anything typed.
                MouseArea {
                    id: netHover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !Net.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (network.active)
                            return;
                        Net.clearError();
                        if (network.secured && !network.known)
                            root.asking = network.asking ? "" : network.ssid;
                        else
                            Net.connect(network.ssid, "");
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.sm
                    spacing: Appearance.spacing.sm

                    RowLayout {
                        id: row
                        Layout.fillWidth: true
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
                            elide: Text.ElideRight
                        }

                        // Saved, but not connected. Says why this one joins on a
                        // single click when the one below it asks for a password.
                        StyledText {
                            visible: network.known && !network.active
                            text: "saved"
                            color: Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                        }

                        Icon {
                            text: "lock"
                            color: network.active ? Theme.onAccentContainerMuted : Theme.textMuted
                            size: Appearance.font.size.xs
                            visible: network.secured
                        }

                        // Forgetting drops the stored passphrase, so it is only
                        // offered where there is one to drop.
                        Action {
                            visible: network.known
                            glyph: "delete"
                            tip: "Forget this network"
                            onActivated: {
                                root.asking = "";
                                Net.forget(network.ssid);
                            }
                        }
                    }

                    // --- Passphrase ---------------------------------------------
                    RowLayout {
                        id: secret
                        Layout.fillWidth: true
                        visible: network.asking
                        spacing: Appearance.spacing.sm

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: Appearance.rounding.small
                            color: Theme.surfaceContainerHighest
                            border.width: pass.activeFocus ? 1 : 0
                            border.color: Theme.accent

                            TextInput {
                                id: pass

                                anchors.fill: parent
                                anchors.leftMargin: Appearance.padding.sm
                                anchors.rightMargin: Appearance.padding.sm
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Appearance.font.family.sans
                                font.pixelSize: Appearance.font.size.xs
                                color: Theme.text
                                selectionColor: Theme.accentContainer
                                selectedTextColor: Theme.onAccentContainer
                                echoMode: reveal.showing ? TextInput.Normal : TextInput.Password
                                clip: true

                                // Focus follows the row opening, so the keyboard
                                // is already where you are looking. Deferred
                                // because the row is still growing on the frame
                                // `asking` flips.
                                onVisibleChanged: if (visible)
                                    Qt.callLater(pass.forceActiveFocus)

                                onAccepted: {
                                    Net.connect(network.ssid, pass.text);
                                    pass.text = "";
                                    root.asking = "";
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: pass.text === "" && !pass.activeFocus
                                    text: "Password"
                                    color: Theme.textMuted
                                    font.pixelSize: Appearance.font.size.xs
                                }
                            }
                        }

                        // Typing a passphrase you cannot see, on a keyboard you
                        // may be holding at arm's length, is how people end up
                        // blaming the network.
                        Action {
                            id: reveal
                            property bool showing: false
                            glyph: reveal.showing ? "visibility_off" : "visibility"
                            tip: reveal.showing ? "Hide" : "Show"
                            onActivated: reveal.showing = !reveal.showing
                        }

                        Action {
                            glyph: "check"
                            tip: "Join"
                            onActivated: {
                                Net.connect(network.ssid, pass.text);
                                pass.text = "";
                                root.asking = "";
                            }
                        }
                    }
                }
            }
        }
    }

    // A small round icon button. Used for every verb in this panel so they read
    // as the same kind of thing.
    component Action: Rectangle {
        id: control

        property string glyph
        property string tip
        property bool spinning: false

        signal activated

        implicitWidth: 26
        implicitHeight: 26
        radius: width / 2
        color: hover.containsMouse ? Theme.surfaceContainerHighest : "transparent"
        opacity: Net.busy && !control.spinning ? 0.4 : 1

        Icon {
            id: mark
            anchors.centerIn: parent
            text: control.glyph
            color: hover.containsMouse ? Theme.accent : Theme.textSecondary
            size: Appearance.font.size.sm

            RotationAnimator {
                target: mark
                running: control.spinning && Appearance.anim.enabled
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    mark.rotation = 0
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: !Net.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: control.activated()
        }

        StyledToolTipText {
            text: control.tip
            visible: hover.containsMouse
        }
    }

    // The tip itself, as a separate component so the button above stays a
    // button. Positioned below rather than above: these sit near the top of the
    // panel, and a tip drawn upward would leave the surface entirely.
    component StyledToolTipText: StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 2
        color: Theme.textMuted
        font.pixelSize: Appearance.font.size.xs
        z: 10
    }
}
