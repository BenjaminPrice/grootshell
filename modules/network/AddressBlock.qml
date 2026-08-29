import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// The IPv4 and IPv6 addresses of one interface.
//
// Shared because both network panels want exactly this, and because the wired
// one has nothing else to offer: it cannot pick a network or hold a passphrase,
// so telling you your address IS the reason to open it.
//
// Monospaced, and wrapped rather than elided. An address is something people
// copy into an ssh command or read down a phone, and both go wrong on a
// proportional font where 1 and l are the same shape. A v6 address does not fit
// the panel's width, and half of one is no use at all — so it takes two lines.

ColumnLayout {
    id: root

    property string v4: ""
    property string v6: ""

    spacing: Appearance.spacing.xs

    component Entry: RowLayout {
        id: entry

        required property string label
        required property string value

        Layout.fillWidth: true
        spacing: Appearance.spacing.md
        visible: entry.value !== ""

        StyledText {
            Layout.preferredWidth: 34
            Layout.alignment: Qt.AlignTop
            text: entry.label
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
        }

        StyledText {
            Layout.fillWidth: true
            text: entry.value
            color: Theme.textSecondary
            mono: true
            font.pixelSize: Appearance.font.size.xs
            wrapMode: Text.WrapAnywhere
        }
    }

    Entry {
        label: "IPv4"
        value: root.v4
    }

    Entry {
        label: "IPv6"
        value: root.v6
    }

    // Said once, rather than as two rows of "—". An interface that is up with no
    // address is a real state — DHCP still trying, or a link with no router
    // behind it — and worth naming rather than leaving blank.
    StyledText {
        Layout.fillWidth: true
        visible: root.v4 === "" && root.v6 === ""
        text: "No address"
        color: Theme.textMuted
        font.pixelSize: Appearance.font.size.xs
    }
}
