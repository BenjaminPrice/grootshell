import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// The forecast: conditions now, the rest of today by the hour, and the next ten
// days.
//
// Three timescales because they answer three different questions — what to wear
// walking out of the door, whether the afternoon is worth planning around, and
// whether the weekend is. Showing only one of them is what makes most weather
// widgets something you check and then go and look up properly.
//
// Named WeatherTab and not Weather: `Weather` is the service singleton next
// door, and Island.qml imports both qs.services and this module. Same collision
// the wallpaper tab avoids.

Item {
    id: root

    // The week's overall range, so a day's temperature bar can be drawn in
    // proportion to the others rather than to itself. A bar that always spans
    // its own row tells you nothing — every day looks equally variable.
    readonly property real weekMin: {
        let m = Infinity;
        for (let i = 0; i < Weather.daily.length; i++)
            m = Math.min(m, Weather.daily[i].min);
        return isFinite(m) ? m : 0;
    }

    readonly property real weekMax: {
        let m = -Infinity;
        for (let i = 0; i < Weather.daily.length; i++)
            m = Math.max(m, Weather.daily[i].max);
        return isFinite(m) ? m : 1;
    }

    readonly property real weekSpan: Math.max(1, root.weekMax - root.weekMin)

    readonly property bool hasData: Weather.current !== null && Weather.daily.length > 0

    // A stand-in for `current` until the first fetch lands.
    //
    // The panel below is hidden until there is data, but `visible: false` does
    // not stop a binding evaluating — so every reading in the "now" column threw
    // a TypeError on null for the second or two before the network answered.
    // Harmless, and a fistful of warnings in the journal that would train anyone
    // reading it to skim past real ones.
    readonly property var now: Weather.current ?? ({
            temperature: 0,
            apparent: 0,
            humidity: 0,
            precipitation: 0,
            code: 0,
            wind: 0,
            isDay: true
        })

    // --- Nothing to show ----------------------------------------------------
    EmptyState {
        anchors.fill: parent
        visible: !Weather.configured
        icon: "location_off"
        title: "No location set"
        // The one place in the shell that tells you where its own config lives,
        // because this is the only feature that cannot guess a default. A city
        // picked for you is worse than none.
        detail: `Put a place name in weather.location in\n${Config.configDir.replace(Quickshell.env("HOME"), "~")}/shell.json`
    }

    EmptyState {
        anchors.fill: parent
        visible: Weather.configured && Weather.error !== ""
        icon: "cloud_off"
        title: "No forecast"
        detail: Weather.error
    }

    EmptyState {
        anchors.fill: parent
        visible: Weather.configured && Weather.error === "" && !root.hasData
        icon: "sync"
        title: "Fetching the forecast…"
    }

    // --- The forecast -------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md
        visible: root.hasData && Weather.error === ""

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            Icon {
                text: "location_on"
                color: Theme.textMuted
                size: Appearance.font.size.sm
            }

            StyledText {
                Layout.fillWidth: true
                text: Weather.place
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
                elide: Text.ElideRight
            }

            StyledText {
                visible: Weather.loading
                text: "updating…"
                color: Theme.accent
                font.pixelSize: Appearance.font.size.xs
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.xl

            // --- Now --------------------------------------------------------
            ColumnLayout {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                spacing: Appearance.spacing.xs

                Item {
                    Layout.fillHeight: true
                }

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.icon(root.now.code, root.now.isDay)
                    color: Theme.accent
                    filled: true
                    size: Math.round(Appearance.font.size.xxl * 1.6)
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.temp(root.now.temperature) + Weather.tempUnit.slice(1)
                    color: Theme.text
                    font.pixelSize: Math.round(Appearance.font.size.xxl * 1.1)
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.describe(root.now.code)
                    color: Theme.textSecondary
                    font.pixelSize: Appearance.font.size.sm
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: `Feels like ${Weather.temp(root.now.apparent)}`
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }

                Item {
                    Layout.preferredHeight: Appearance.spacing.md
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Appearance.spacing.lg

                    Reading {
                        glyph: "air"
                        value: `${Math.round(root.now.wind)} ${Weather.windUnit}`
                    }

                    Reading {
                        glyph: "humidity_percentage"
                        value: `${Math.round(root.now.humidity)}%`
                    }

                    Reading {
                        glyph: "rainy"
                        value: `${root.now.precipitation.toFixed(1)} ${Weather.precipUnit}`
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // --- Today by the hour, then the next ten days -------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Appearance.spacing.sm

                StyledText {
                    text: "Next 12 hours"
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    orientation: ListView.Horizontal
                    clip: true
                    spacing: Appearance.spacing.xs
                    model: Weather.upcomingHours(12)

                    delegate: ColumnLayout {
                        id: hourCell

                        required property var modelData

                        width: 62
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDateTime(new Date(hourCell.modelData.at), "HH:mm")
                            color: Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                            mono: true
                        }

                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            // Hours are day or night by their own clock, not by
                            // whether it is light out right now — half of a
                            // twelve-hour strip is usually the other one.
                            text: Weather.icon(hourCell.modelData.code, root.daylight(hourCell.modelData.at))
                            color: Theme.textSecondary
                            size: Appearance.font.size.lg
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.temp(hourCell.modelData.temperature)
                            color: Theme.text
                            font.pixelSize: Appearance.font.size.xs
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            // Hidden below 5%, because a column of "0%" under
                            // every hour is a row of noise that makes the one
                            // hour it rains harder to spot.
                            visible: hourCell.modelData.precipitation >= 5
                            text: `${Math.round(hourCell.modelData.precipitation)}%`
                            color: Theme.accent
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }
                }

                StyledText {
                    Layout.topMargin: Appearance.spacing.xs
                    text: `Next ${Weather.daily.length} days`
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: Weather.daily

                    delegate: RowLayout {
                        id: dayRow

                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        spacing: Appearance.spacing.sm

                        StyledText {
                            Layout.preferredWidth: 46
                            text: dayRow.index === 0 ? "Today" : Qt.formatDateTime(new Date(dayRow.modelData.at), "ddd")
                            color: dayRow.index === 0 ? Theme.text : Theme.textSecondary
                            font.pixelSize: Appearance.font.size.xs
                        }

                        Icon {
                            // Always the daytime glyph: a daily summary is not
                            // about a moment, and a moon over Thursday would
                            // suggest it is night all Thursday.
                            text: Weather.icon(dayRow.modelData.code, true)
                            color: Theme.textSecondary
                            size: Appearance.font.size.md
                        }

                        // Fixed width whether or not it shows anything, so the
                        // temperature bars all start at the same x. Ragged bar
                        // starts would destroy the comparison the bars exist to
                        // make.
                        Item {
                            Layout.preferredWidth: 34
                            implicitHeight: 1

                            StyledText {
                                anchors.centerIn: parent
                                visible: dayRow.modelData.precipitation >= 5
                                text: `${Math.round(dayRow.modelData.precipitation)}%`
                                color: Theme.accent
                                font.pixelSize: Appearance.font.size.xs
                            }
                        }

                        StyledText {
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                            text: Weather.temp(dayRow.modelData.min)
                            color: Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                        }

                        // The day's range, positioned within the week's. Where
                        // the bar SITS carries as much as how long it is: a cold
                        // snap on Thursday is a bar shifted left, which reads at
                        // a glance where two numbers do not.
                        Rectangle {
                            id: track

                            Layout.fillWidth: true
                            implicitHeight: 4
                            radius: 2
                            color: Theme.surfaceContainerHighest

                            Rectangle {
                                x: track.width * (dayRow.modelData.min - root.weekMin) / root.weekSpan
                                width: Math.max(4, track.width * (dayRow.modelData.max - dayRow.modelData.min) / root.weekSpan)
                                height: track.height
                                radius: track.radius
                                color: Theme.accent
                            }
                        }

                        StyledText {
                            Layout.preferredWidth: 32
                            text: Weather.temp(dayRow.modelData.max)
                            color: Theme.text
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }
                }
            }
        }
    }

    // Whether a given moment is between that day's sunrise and sunset, so an
    // hourly icon at 21:00 is a night one. Falls back to a plausible daylight
    // window if the day is past the end of the daily forecast.
    function daylight(at: real): bool {
        for (let i = 0; i < Weather.daily.length; i++) {
            const d = Weather.daily[i];
            if (at >= d.at && at < d.at + 86400000)
                return at >= d.sunrise && at < d.sunset;
        }
        const hour = new Date(at).getHours();
        return hour >= 6 && hour < 18;
    }

    component Reading: ColumnLayout {
        id: reading

        property string glyph
        property string value

        spacing: 0

        Icon {
            Layout.alignment: Qt.AlignHCenter
            text: reading.glyph
            color: Theme.textMuted
            size: Appearance.font.size.md
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: reading.value
            color: Theme.textSecondary
            font.pixelSize: Appearance.font.size.xs
        }
    }
}
