import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// A month grid.
//
// Named MonthGrid and not Calendar: services/Calendar.qml is the singleton that
// FETCHES events, and a component of the same name in a sibling module would be
// ambiguous in any file importing both — which the dashboard does. The same trap
// that State.qml fell into against QtQuick's State.
//
// Six rows always, never five-or-six. A grid that changes height as you page
// through months makes everything below it jump, and on the dashboard that is
// the agenda — so the trailing row is drawn with the next month's days rather
// than left out.
//
// Days carry a marker when something is happening on them. Nothing populates
// that yet: `eventDays` is a plain set of yyyy-mm-dd strings, so whatever ends
// up feeding it — a calendar service, an .ics fetch — only has to produce dates
// and does not have to know anything about this component.

Item {
    id: root

    // The month on display. Paging changes this; it is not bound to today, or
    // the view would snap back at midnight.
    property date shown: Time.now

    // Day key ("yyyy-mm-dd") -> array of colour strings to mark it with. Keyed
    // rather than a list so lookup is by key instead of a scan per cell, and
    // colours rather than calendars so this stays a plain month view: it draws
    // what it is handed and knows nothing about where events come from.
    property var eventDays: ({})

    // Five fits, and five is what this host actually has.
    //
    // The arithmetic, because it is the thing that decides: the grid is 250px
    // across in seven columns with 2px between them, so a cell is about 34px.
    // Five 3px dots with 2px gaps is 23px. Beyond about six the dots stop being
    // countable and start being a smear, which is when the marker should become
    // a count instead.
    readonly property int maxMarkers: 5

    readonly property int firstWeekday: 0 // Sunday

    // The grid does not own the selection: it reports a click and whoever is
    // listening decides what that means. Keeps this reusable as a plain month
    // view rather than tying it to the agenda beside it.
    signal dayClicked(date day)

    implicitWidth: grid.implicitWidth
    implicitHeight: header.implicitHeight + weekdays.implicitHeight + grid.implicitHeight + Appearance.spacing.md * 2

    function key(d: date): string {
        const m = String(d.getMonth() + 1).padStart(2, "0");
        const day = String(d.getDate()).padStart(2, "0");
        return `${d.getFullYear()}-${m}-${day}`;
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function page(months: int): void {
        const d = new Date(root.shown);
        // Anchored to the 1st before adding: adding a month to the 31st lands in
        // the month after next, because there is no 31st in between.
        d.setDate(1);
        d.setMonth(d.getMonth() + months);
        root.shown = d;
    }

    // The 42 cells, computed once per month rather than per cell.
    readonly property var cells: {
        const first = new Date(root.shown.getFullYear(), root.shown.getMonth(), 1);
        const lead = (first.getDay() - root.firstWeekday + 7) % 7;
        const start = new Date(first);
        start.setDate(1 - lead);

        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            out.push(d);
        }
        return out;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        // --- Month, and paging ----------------------------------------------
        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            StyledText {
                Layout.fillWidth: true
                text: Qt.locale().standaloneMonthName(root.shown.getMonth()) + " " + root.shown.getFullYear()
                color: Theme.text
                font.pixelSize: Appearance.font.size.md
            }

            Icon {
                text: "chevron_left"
                color: prevHover.containsMouse ? Theme.accent : Theme.textMuted
                size: Appearance.font.size.md

                MouseArea {
                    id: prevHover
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.page(-1)
                }
            }

            // Only offered when it would do something, so it is not a control
            // that sometimes silently does nothing.
            Icon {
                text: "today"
                visible: !root.sameDay(new Date(root.shown.getFullYear(), root.shown.getMonth(), 1), new Date(Time.now.getFullYear(), Time.now.getMonth(), 1))
                color: todayHover.containsMouse ? Theme.accent : Theme.textMuted
                size: Appearance.font.size.md

                MouseArea {
                    id: todayHover
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shown = Time.now
                }
            }

            Icon {
                text: "chevron_right"
                color: nextHover.containsMouse ? Theme.accent : Theme.textMuted
                size: Appearance.font.size.md

                MouseArea {
                    id: nextHover
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.page(1)
                }
            }
        }

        // --- Weekday initials -----------------------------------------------
        RowLayout {
            id: weekdays
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: 7

                delegate: StyledText {
                    required property int index

                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((index + root.firstWeekday) % 7, Locale.NarrowFormat)
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }
            }
        }

        // --- The grid --------------------------------------------------------
        GridLayout {
            id: grid

            Layout.fillWidth: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
                model: root.cells

                delegate: Item {
                    id: cell

                    required property date modelData

                    readonly property bool inMonth: modelData.getMonth() === root.shown.getMonth()
                    readonly property bool isToday: root.sameDay(modelData, Time.now)
                    readonly property var markers: root.eventDays[root.key(modelData)] ?? []

                    Layout.fillWidth: true
                    // Compact deliberately. Six rows at the large type came to
                    // ~306px of grid, which did not fit the tab and silently
                    // clipped the last fortnight — a calendar missing its bottom
                    // half looks like a rendering fault, not a small panel.
                    implicitHeight: Appearance.font.size.md + Appearance.padding.xs * 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        radius: width / 2
                        color: cell.isToday ? Theme.accentContainer : cellHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: cell.modelData.getDate()
                        // Three states, deliberately distinct: today, this
                        // month, and the leading/trailing days that are only
                        // there to keep the grid six rows tall.
                        color: cell.isToday ? Theme.onAccentContainer : cell.inMonth ? Theme.text : Theme.outlineVariant
                        font.pixelSize: Appearance.font.size.xs
                    }

                    MouseArea {
                        id: cellHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dayClicked(cell.modelData)
                    }

                    // One dot per calendar with something on this day, under the
                    // number rather than behind it so the date stays legible.
                    // Small on purpose: this says WHICH calendars, not how busy.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        spacing: 2

                        Repeater {
                            model: cell.markers.slice(0, root.maxMarkers)

                            delegate: Rectangle {
                                required property string modelData

                                width: 3
                                height: 3
                                radius: 1.5
                                // Days outside the shown month keep their
                                // calendar's hue but dimmed, so the leading and
                                // trailing rows stay visibly secondary.
                                color: modelData
                                opacity: cell.inMonth ? 1 : 0.45
                            }
                        }
                    }
                }
            }
        }
    }
}
