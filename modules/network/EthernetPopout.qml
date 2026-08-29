import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The wired panel.
//
// It has no buttons, and that is deliberate rather than unfinished. There is
// nothing to pick — a cable is plugged in or it is not — and the one action a
// wired panel could offer, disconnecting, is a way to lock yourself out of a
// machine you reached over that very cable. This host is driven entirely over
// the network; the button would be a trap with a 100% hit rate.
//
// So it answers questions instead: which interface, at what speed, on what
// address. That last one is why it exists. "What is my IP" is the question
// people actually have about a wired connection, and the alternatives are a
// terminal or a router's web interface.

Panel {
    id: root

    edge: "top"
    open: ShellState.ethernet
    implicitWidth: 360
    implicitHeight: body.implicitHeight + Appearance.padding.lg * 2
    radius: Appearance.rounding.large

    readonly property bool up: Net.ethernet !== ""

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: Appearance.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            Icon {
                text: root.up ? "lan" : "portable_wifi_off"
                filled: true
                color: root.up ? Theme.accent : Theme.textMuted
                size: Appearance.font.size.xl
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    // The connection's NAME, when there is one worth showing.
                    //
                    // Net.ethernet falls back to the interface when
                    // NetworkManager does not manage the link — which is the
                    // case on this machine — and that would put "eno2" in the
                    // title with "eno2 · 1 Gb/s" directly under it. When the
                    // name is only the interface repeated, say "Wired" instead
                    // and let the line below carry the detail.
                    text: {
                        if (!root.up)
                            return "No cable";
                        return Net.ethernet !== Net.wiredDevice ? Net.ethernet : "Wired";
                    }
                    color: Theme.text
                    font.pixelSize: Appearance.font.size.md
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Net.wiredDevice !== ""
                    text: {
                        if (!root.up)
                            return Net.wiredDevice;
                        if (Net.wiredSpeed <= 0)
                            return Net.wiredDevice;
                        // Gb/s past a thousand, because "2500 Mb/s" is a number
                        // you have to convert before it means anything.
                        const rate = Net.wiredSpeed >= 1000 ? `${Net.wiredSpeed / 1000} Gb/s` : `${Net.wiredSpeed} Mb/s`;
                        return `${Net.wiredDevice} · ${rate}`;
                    }
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.up
            implicitHeight: 1
            color: Theme.outlineVariant
        }

        AddressBlock {
            Layout.fillWidth: true
            visible: root.up
            v4: Net.wiredV4
            v6: Net.wiredV6
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.up
            text: "Nothing is plugged in, or the interface is down."
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            wrapMode: Text.WordWrap
        }
    }
}
