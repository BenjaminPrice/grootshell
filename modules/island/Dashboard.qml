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

            // No uptime. The performance tab already carries it, and here it was
            // doubly awkward: the metrics poll only runs while THAT tab is open,
            // so this showed a stale value or nothing at all depending on where
            // you had been.

            // Weather, in the space that left. Conditions now and the next few
            // hours — the two things worth knowing without opening anything.
            // Anything more (the ten days, the full hourly run) is a tab away,
            // which is where it belongs: this row is read in passing.
            //
            // Absent entirely when there is no location set or nothing fetched
            // yet, rather than showing a placeholder. An empty state here would
            // be permanent furniture for anyone who never configures it.
            RowLayout {
                spacing: Appearance.spacing.md
                visible: Weather.current !== null

                RowLayout {
                    spacing: Appearance.spacing.xs

                    Icon {
                        text: Weather.current ? Weather.icon(Weather.current.code, Weather.current.isDay) : ""
                        color: Theme.accent
                        filled: true
                        size: Appearance.font.size.lg
                    }

                    StyledText {
                        text: Weather.current ? Weather.temp(Weather.current.temperature) : ""
                        color: Theme.text
                        font.pixelSize: Appearance.font.size.md
                    }
                }

                Repeater {
                    model: Weather.upcomingHours(3)

                    delegate: ColumnLayout {
                        id: soon
                        required property var modelData
                        spacing: 0

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDateTime(new Date(soon.modelData.at), "HH")
                            color: Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                            mono: true
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.temp(soon.modelData.temperature)
                            color: Theme.textSecondary
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }
                }
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
