import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The at-a-glance tab: time and uptime.
//
// Deliberately sparse. The quick-toggles that used to sit at the bottom are gone
// — do-not-disturb has an affordance in the notification centre, wifi has one in
// its own popout, and game mode is a keybind and a Sunshine tile. Three buttons
// duplicating controls that already exist elsewhere is clutter that has to be
// read past every time you open this for the clock.

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        Item {
            Layout.fillHeight: true
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("HH:mm")
            font.pixelSize: Appearance.font.size.xxl
            color: Theme.text
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd, d MMMM")
            color: Theme.textSecondary
            font.pixelSize: Appearance.font.size.md
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
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
    }
}
