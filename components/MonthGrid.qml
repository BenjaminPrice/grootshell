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

    // Days to mark, as "yyyy-mm-dd". A plain object used as a set so lookup is
    // by key rather than a linear scan per cell — 42 cells against a month of
    // events is small either way, but the shape is the point: the producer
    // writes dates, this reads them.
    property var eventDays: ({})

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
                    readonly property bool hasEvents: root.eventDays[root.key(modelData)] === true

                    Layout.fillWidth: true
                    implicitHeight: Appearance.font.size.lg + Appearance.padding.sm * 2

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
                        font.pixelSize: Appearance.font.size.sm
                    }

                    MouseArea {
                        id: cellHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dayClicked(cell.modelData)
                    }

                    // The event marker. Under the number rather than behind it,
                    // so a day with events is still legible as a date.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        visible: cell.hasEvents
                        width: 4
                        height: 4
                        radius: 2
                        color: cell.isToday ? Theme.onAccentContainer : cell.inMonth ? Theme.accent : Theme.outlineVariant
                    }
                }
            }
        }
    }
}
