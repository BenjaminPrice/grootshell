import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The at-a-glance tab: time, date, and the month.
//
// Still no quick-toggles. The ones that used to sit at the bottom are gone —
// do-not-disturb has an affordance in the notification centre, wifi has one in
// its own popout, and game mode is a keybind and a Sunshine tile. Three buttons
// duplicating controls that already exist elsewhere is clutter that has to be
// read past every time you open this for the clock.
//
// A calendar is a different proposition: it answers a question the clock cannot
// ("what is next Tuesday"), which is why it earns the space the toggles did not.
//
// The grid and the agenda are one control: clicking a day lists it, and clicking
// an entry opens its detail in place. Side by side rather than stacked — the
// island is 360px tall and a stacked pair would give the agenda four rows.

Item {
    id: root

    // Everything the dashboard does with a key, the agenda does — the month
    // grid is a display, and paging it is not worth a chord when clicking a day
    // is right there.
    function handleKey(event): bool {
        return agenda.handleKey(event);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            StyledText {
                text: Time.format("HH:mm")
                font.pixelSize: Appearance.font.size.xl
                color: Theme.text
            }

            StyledText {
                Layout.fillWidth: true
                text: Time.format("dddd, d MMMM")
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
                elide: Text.ElideRight
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
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.md

            MonthGrid {
                id: month

                Layout.preferredWidth: 250
                Layout.alignment: Qt.AlignTop
                eventDays: Calendar.eventDays
                onDayClicked: day => agenda.day = day
            }

            Agenda {
                id: agenda
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
