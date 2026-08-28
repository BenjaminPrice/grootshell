import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// What is coming up, and what a thing actually is when you click it.
//
// Two states in one item rather than two panels: the list, and the detail for a
// selected event drawn over it. The island is 360px tall and already shares that
// with a clock and a month grid — a detail view that opened a second surface
// would be a popup over a popup, on a display being watched through a video
// stream. Replacing the list in place keeps it to one thing at a time.

Item {
    id: root

    // Which day the list is for. The dashboard binds this to the month grid's
    // selection so clicking a day changes what is listed.
    property date day: Time.now

    // The event whose detail is showing, or null for the list.
    property var selected: null

    // Keyboard cursor into `items`. Separate from `selected`, which is the thing
    // being READ — you move through a list and then open something, and
    // conflating the two means arrowing past an entry counts as opening it.
    property int cursor: 0

    readonly property bool isToday: Calendar.sameDay(root.day, Time.now)

    // Today lists what is LEFT of today; any other day lists all of it. "Today
    // from midnight" is a history lesson, not an agenda.
    //
    // Note that the today list runs PAST today — upcoming() takes the next
    // events whenever they are, so a quiet week shows next Tuesday's standup.
    // Which is why the rows carry date headers below: an entry reading 09:00
    // with nothing else is a promise about the wrong day.
    readonly property var items: root.isToday ? Calendar.upcoming(20) : Calendar.on(root.day)

    // Whether row `i` opens a new day, and so needs a date above it. The first
    // row is compared against the day being listed, so an "Up next" list that
    // starts tomorrow says so rather than looking like today.
    function startsNewDay(i: int): bool {
        const items = root.items;
        if (i < 0 || i >= items.length)
            return false;
        const day = new Date(items[i].start);
        if (i === 0)
            return !Calendar.sameDay(day, root.day);
        return !Calendar.sameDay(day, new Date(items[i - 1].start));
    }

    // Today and tomorrow are named; anything further out gets its date, because
    // "Thursday" stops being useful once it could be either of two Thursdays.
    function dayLabel(when: date): string {
        const today = Time.now;
        const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
        if (Calendar.sameDay(when, today))
            return "Today";
        if (Calendar.sameDay(when, tomorrow))
            return "Tomorrow";
        const sixDays = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 6);
        if (when <= sixDays)
            return Qt.formatDateTime(when, "dddd d MMM");
        return Qt.formatDateTime(when, "ddd d MMM yyyy");
    }

    function timeOf(event): string {
        if (event.allDay)
            return "all day";
        return Qt.formatDateTime(new Date(event.start), "HH:mm");
    }

    function rangeOf(event): string {
        if (event.allDay)
            return "All day";
        const start = Qt.formatDateTime(new Date(event.start), "HH:mm");
        const end = Qt.formatDateTime(new Date(event.end), "HH:mm");
        return start === end ? start : `${start} – ${end}`;
    }

    // Material Symbols has no Zoom or Teams glyph, so the kind becomes a label
    // rather than an icon nobody would recognise.
    function labelFor(link): string {
        switch (link.kind) {
        case "zoom":
            return "Zoom";
        case "meet":
            return "Google Meet";
        case "teams":
            return "Teams";
        case "webex":
            return "Webex";
        case "jitsi":
            return "Jitsi";
        default:
            return "Open link";
        }
    }

    onDayChanged: {
        root.selected = null;
        root.cursor = 0;
    }

    // Keys the agenda claims. Returns true when it consumed one, so the island
    // knows not to treat it as a tab switch.
    //
    // Left and Right are NOT claimed, in either state. They belong to the island
    // for moving between tabs, and claiming Right to open an entry meant arrowing
    // from the dashboard towards Media opened whatever the cursor was sitting on
    // first. Vertical keys move within a tab, horizontal keys move between them,
    // and nothing here gets to blur that.
    //
    // Escape is claimed ONLY while a detail is open, where it means "back to the
    // list". Everywhere else it falls through to shell.qml, which closes the
    // panel — a modal that swallows Escape on a host with no local console is
    // the one thing that must never happen.
    function handleKey(event): bool {
        if (root.selected) {
            switch (event.key) {
            case Qt.Key_Escape:
            case Qt.Key_Backspace:
                root.selected = null;
                return true;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                return root.join(0);
            }
            // 1..9 pick a specific link, for an invite carrying more than one.
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
                return root.join(event.key - Qt.Key_1);
            return false;
        }

        switch (event.key) {
        case Qt.Key_Down:
            root.moveCursor(1);
            return true;
        case Qt.Key_Up:
            root.moveCursor(-1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.items.length > 0) {
                root.selected = root.items[Math.min(root.cursor, root.items.length - 1)];
                return true;
            }
            return false;
        }
        return false;
    }

    function moveCursor(delta: int): void {
        if (root.items.length === 0)
            return;
        root.cursor = Math.max(0, Math.min(root.items.length - 1, root.cursor + delta));
        list.positionViewAtIndex(root.cursor, ListView.Contain);
    }

    function join(index: int): bool {
        const links = root.selected?.links ?? [];
        if (index < 0 || index >= links.length)
            return false;
        Apps.launch(["xdg-open", links[index].url]);
        ShellState.close("island");
        return true;
    }

    // --- The list -----------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.xs
        visible: !root.selected

        StyledText {
            Layout.fillWidth: true
            text: root.isToday ? "Up next" : Qt.formatDateTime(root.day, "dddd d MMMM")
            color: Theme.textSecondary
            font.pixelSize: Appearance.font.size.xs
        }

        // Three distinct empty states, because they mean different things and
        // "nothing here" for all of them would hide a broken feed.
        StyledText {
            Layout.fillWidth: true
            visible: root.items.length === 0
            text: !Calendar.configured ? "No calendar configured" : Calendar.error ? "Calendar unavailable" : root.isToday ? "Nothing left today" : "Nothing scheduled"
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.items

            delegate: Column {
                id: rowWrap

                required property var modelData
                required property int index

                width: ListView.view.width
                spacing: 2

                // The date, but only where the day actually changes. Repeating
                // it on every row would be noise on the common case of several
                // things in one afternoon.
                StyledText {
                    width: parent.width
                    visible: root.startsNewDay(rowWrap.index)
                    topPadding: rowWrap.index === 0 ? 0 : Appearance.spacing.xs
                    text: root.dayLabel(new Date(rowWrap.modelData.start))
                    color: Theme.textSecondary
                    font.pixelSize: Appearance.font.size.xs
                }

                Rectangle {
                    id: row

                    readonly property var modelData: rowWrap.modelData

                    width: parent.width
                    implicitHeight: rowLayout.implicitHeight + Appearance.padding.sm * 2
                    radius: Appearance.rounding.normal
                    // The keyboard cursor reads the same as hover: this is one
                    // selection with two ways to move it, not two selections.
                    color: rowHover.containsMouse || rowWrap.index === root.cursor ? Theme.surfaceContainerHigh : "transparent"

                    RowLayout {
                        id: rowLayout
                        anchors.fill: parent
                        anchors.margins: Appearance.padding.sm
                        spacing: Appearance.spacing.sm

                        // Which calendar, as a bar rather than a label. With several
                        // feeds merged the question is "is that work or not", and a
                        // name per row would cost more width than the title has.
                        Rectangle {
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: rowLayout.implicitHeight
                            radius: 1.5
                            color: Calendar.colourFor(row.modelData.calendar ?? "")
                            visible: Calendar.calendars.length > 1
                        }

                        StyledText {
                            text: root.timeOf(row.modelData)
                            color: Theme.textMuted
                            font.pixelSize: Appearance.font.size.xs
                            mono: true
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.summary
                            color: Theme.text
                            font.pixelSize: Appearance.font.size.xs
                            elide: Text.ElideRight
                        }

                        // A marker rather than the link itself: the row is a summary,
                        // and one that renders a button per meeting service would be
                        // wider than the title it is describing.
                        Icon {
                            visible: (row.modelData.links?.length ?? 0) > 0
                            text: "videocam"
                            color: Theme.accent
                            size: Appearance.font.size.xs
                        }
                    }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                        root.cursor = rowWrap.index;
                        root.selected = row.modelData;
                    }
                    }
                            }
            }
        }
    }

    // --- The detail ---------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.xs
        visible: !!root.selected

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            Icon {
                text: "arrow_back"
                color: backHover.containsMouse ? Theme.accent : Theme.textMuted
                size: Appearance.font.size.md

                MouseArea {
                    id: backHover
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected = null
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.selected?.summary ?? ""
                color: Theme.text
                font.pixelSize: Appearance.font.size.md
                elide: Text.ElideRight
            }
        }

        // Named here, unlike in the list. There is room for it on a detail view,
        // and "which calendar is this on" is a real question once several are
        // merged — the bar in the list only distinguishes, it does not tell you.
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs
            visible: Calendar.calendars.length > 1 && (root.selected?.calendar ?? "") !== ""

            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                radius: 3
                color: Calendar.colourFor(root.selected?.calendar ?? "")
            }

            StyledText {
                Layout.fillWidth: true
                text: root.selected?.calendar ?? ""
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                elide: Text.ElideRight
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.selected ? `${Qt.formatDateTime(new Date(root.selected.start), "ddd d MMM")}  ·  ${root.rangeOf(root.selected)}` : ""
            color: Theme.textSecondary
            font.pixelSize: Appearance.font.size.xs
        }

        StyledText {
            Layout.fillWidth: true
            visible: (root.selected?.location ?? "") !== ""
            text: root.selected?.location ?? ""
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            elide: Text.ElideRight
        }

        // Joining the call is the one thing anyone opens a calendar entry to do,
        // so the links are buttons directly under the time rather than something
        // to find in the description.
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.xs
            spacing: Appearance.spacing.xs

            Repeater {
                model: root.selected?.links ?? []

                delegate: Rectangle {
                    id: joinButton

                    required property var modelData

                    implicitWidth: joinRow.implicitWidth + Appearance.padding.md * 2
                    implicitHeight: joinRow.implicitHeight + Appearance.padding.xs * 2
                    radius: Appearance.rounding.full
                    color: joinHover.containsMouse ? Theme.accent : Theme.accentContainer

                    RowLayout {
                        id: joinRow
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.xs

                        Icon {
                            text: joinButton.modelData.kind === "link" ? "open_in_new" : "videocam"
                            color: joinHover.containsMouse ? Theme.onAccent : Theme.onAccentContainer
                            size: Appearance.font.size.xs
                        }

                        StyledText {
                            text: root.labelFor(joinButton.modelData)
                            color: joinHover.containsMouse ? Theme.onAccent : Theme.onAccentContainer
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }

                    MouseArea {
                        id: joinHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Through Apps.launch, so the call outlives a shell
                        // restart — a meeting killed because the bar reloaded
                        // would be the worst possible time for that to happen.
                        onClicked: {
                            Apps.launch(["xdg-open", joinButton.modelData.url]);
                            ShellState.close("island");
                        }
                    }
                }
            }
        }

        // The description last and scrollable: it is usually boilerplate from
        // whoever sent the invite, and the useful parts of it — the links — have
        // already been lifted out above.
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: description.implicitHeight
            visible: (root.selected?.description ?? "") !== ""

            StyledText {
                id: description
                width: parent.width
                text: root.selected?.description ?? ""
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                wrapMode: Text.Wrap
                // Inherited from StyledText, where it is elide-right by default.
                // Wrapping text that also elides loses the last line to an
                // ellipsis it does not need.
                elide: Text.ElideNone

                // A legible link may as well be a working one. The join buttons
                // above remain the primary route — they are lifted out precisely
                // so nobody has to find the link in here — but anything the
                // pattern list did not recognise is still reachable this way.
                onLinkActivated: link => Apps.launch(["xdg-open", link])

                HoverHandler {
                    // Only over an actual link, so the cursor does not promise
                    // something clickable across a paragraph of boilerplate.
                    cursorShape: description.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
    }
}
