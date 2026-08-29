import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// One setting: a label, a control, and whether it is overridden.
//
// The control is chosen from the schema entry's `type` rather than each setting
// bringing its own widget, which is what keeps the panel a list of data instead
// of a screenful of hand-placed sliders. Adding a setting is one line in
// SettingsPanel's schema.
//
// ## Two stores
//
// Most settings are CONFIG — they live in shell.json, they have a shipped
// default, and not setting one is meaningfully different from setting it to the
// same value. A few are STATE: the light/dark override is something you chose at
// runtime, it has no default to fall back to, and it lives in state.json beside
// the current wallpaper. `store: "state"` switches a row over; see
// services/Persist.qml for why the two files are separate.
//
// ## The override marker
//
// A config row can say whether the value is yours or the shipped default, and
// reset it if it is yours. That is not decoration — it is the visible half of how
// settings are stored. Keys you have not set are ABSENT from shell.json and
// follow the default forever after, including when the default improves; a panel
// that could only ever write values would quietly opt you out of that on first
// use. State rows have no such marker, because for them there is no default to
// be different from.

Item {
    id: root

    required property var spec

    // Bumped by the panel after any write, because "is this key present in the
    // file" is not a property anything can bind to — it is a question answered by
    // reading the file, and only a write can change the answer.
    property int revision: 0

    readonly property bool stateBacked: (root.spec.store ?? "") === "state"

    readonly property var value: root.stateBacked ? Persist[root.spec.key] : Settings.resolve(root.spec.key)
    readonly property bool overridden: !root.stateBacked && root.revision >= 0 && Settings.has(root.spec.key)

    implicitHeight: Math.max(control.implicitHeight, label.implicitHeight, 36)

    signal changed

    // "Open a list of my options, anchored to this item." The list itself is the
    // panel's, not this row's: a row lives inside a clipping Flickable, so a
    // popup drawn here would be cut off at the first scroll boundary it crossed.
    signal selectRequested(Item anchor)

    function commit(v: var): void {
        if (root.stateBacked)
            Persist[root.spec.key] = v;
        else
            Settings.set(root.spec.key, v);
        root.changed();
    }

    function reset(): void {
        Settings.unset(root.spec.key);
        root.changed();
    }

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.lg

        ColumnLayout {
            id: label

            // Capped, not merely preferred.
            //
            // A wrapping Text reports its full UNWRAPPED width as its minimum,
            // and a layout honours a minimum over a preference — so any row with
            // a detail line pushed this column as wide as that sentence and
            // squeezed the control beside it down to nothing. The font-scale
            // slider collapsed to a handle jammed against its own readout while
            // the rows below it, which had no detail, were fine.
            Layout.preferredWidth: 240
            Layout.maximumWidth: 240
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            RowLayout {
                spacing: Appearance.spacing.xs

                StyledText {
                    text: root.spec.label
                    color: Theme.text
                    font.pixelSize: Appearance.font.size.sm
                }

                // A dot, not a word. It marks the handful of rows that differ
                // from stock without turning every other row into a sentence
                // saying "default".
                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: Theme.accent
                    visible: root.overridden
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: (root.spec.detail ?? "") !== ""
                text: root.spec.detail ?? ""
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                wrapMode: Text.WordWrap
            }
        }

        // --- The control -----------------------------------------------------
        Item {
            id: control

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: loader.implicitHeight

            Loader {
                id: loader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: {
                    switch (root.spec.type) {
                    case "bool":
                        return toggleControl;
                    case "int":
                    case "real":
                        return sliderControl;
                    case "choice":
                        return choiceControl;
                    case "select":
                        return selectControl;
                    case "apps":
                        return appsControl;
                    default:
                        return textControl;
                    }
                }
            }
        }

        // Only where there is something to undo. A permanently visible reset
        // that is usually a no-op teaches you to ignore it.
        Icon {
            Layout.alignment: Qt.AlignVCenter
            text: "restart_alt"
            color: resetHover.containsMouse ? Theme.accent : Theme.textMuted
            size: Appearance.font.size.md
            opacity: root.overridden ? 1 : 0

            MouseArea {
                id: resetHover
                anchors.fill: parent
                anchors.margins: -4
                enabled: root.overridden
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reset()
            }
        }
    }

    // --- Controls ------------------------------------------------------------

    Component {
        id: toggleControl

        Item {
            implicitHeight: 28

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 46
                implicitHeight: 26
                radius: height / 2
                color: root.value === true ? Theme.accentContainer : Theme.surfaceContainerHighest

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Rectangle {
                    y: 3
                    x: root.value === true ? track.width - width - 3 : 3
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: 10
                    color: root.value === true ? Theme.onAccentContainer : Theme.textMuted

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
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.commit(root.value !== true)
                }
            }
        }
    }

    Component {
        id: sliderControl

        Item {
            id: slider

            // Taller than the other controls, because the range labels sit above
            // the groove rather than beside it — beside would cost width the
            // groove itself needs, and the groove is the thing being aimed at.
            implicitHeight: 40

            readonly property real min: root.spec.min ?? 0
            readonly property real max: root.spec.max ?? 100
            readonly property real step: root.spec.step ?? 1
            readonly property real current: Number(root.value ?? slider.min)
            readonly property real fraction: slider.max > slider.min ? Math.max(0, Math.min(1, (slider.current - slider.min) / (slider.max - slider.min))) : 0

            // Rounded to the step, then to the type. Writing 1.0500000000000003
            // into a config file is the sort of thing that makes a generated
            // file look untrustworthy.
            function quantise(f: real): var {
                const raw = slider.min + f * (slider.max - slider.min);
                const snapped = Math.round(raw / slider.step) * slider.step;
                const clamped = Math.max(slider.min, Math.min(slider.max, snapped));
                return root.spec.type === "int" ? Math.round(clamped) : Math.round(clamped * 1000) / 1000;
            }

            // The number is editable, and is the same value as the slider.
            //
            // A slider is good for "a bit more than that" and bad for "exactly
            // 1.15", which is precisely what a scale factor wants. Neither is
            // the master: dragging updates the field, typing moves the handle,
            // because both are just views of the one config key.
            Rectangle {
                id: readout

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 58
                implicitHeight: 26
                radius: Appearance.rounding.small
                color: entry.activeFocus ? Theme.surfaceContainerHighest : "transparent"
                border.width: entry.activeFocus ? 1 : 0
                border.color: Theme.accent

                TextInput {
                    id: entry

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.xs
                    horizontalAlignment: TextInput.AlignRight
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Appearance.font.family.mono
                    font.pixelSize: Appearance.font.size.xs
                    color: Theme.textSecondary
                    selectionColor: Theme.accentContainer
                    selectedTextColor: Theme.onAccentContainer
                    // Digits, a decimal point and a leading minus. Rejecting the
                    // rest at the keystroke beats validating a mess afterwards.
                    validator: RegularExpressionValidator {
                        regularExpression: /-?\d*\.?\d*/
                    }

                    Component.onCompleted: text = String(slider.current)

                    // Follows the slider whenever it is not being typed into —
                    // dragging with the caret parked in the field must not fight
                    // the person holding the mouse.
                    Connections {
                        target: slider
                        function onCurrentChanged(): void {
                            if (!entry.activeFocus)
                                entry.text = String(slider.current);
                        }
                    }

                    function submit(): void {
                        const n = parseFloat(entry.text);
                        if (isNaN(n)) {
                            // Unparseable goes back to what it was rather than
                            // writing a NaN into the config file.
                            entry.text = String(slider.current);
                            return;
                        }
                        const clamped = Math.max(slider.min, Math.min(slider.max, n));
                        const v = root.spec.type === "int" ? Math.round(clamped) : Math.round(clamped * 1000) / 1000;
                        entry.text = String(v);
                        if (v !== slider.current)
                            root.commit(v);
                    }

                    onAccepted: submit()
                    onActiveFocusChanged: if (!activeFocus)
                        submit()
                }
            }

            // The ends of the range, above the ends of the track.
            //
            // Without them a slider is a position with no scale: you can see
            // that the handle is a third of the way along and have no idea a
            // third of what. Small and muted, because they are a reference you
            // glance at once rather than part of the value.
            StyledText {
                anchors.left: groove.left
                anchors.bottom: groove.top
                anchors.bottomMargin: 4
                text: String(slider.min)
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }

            StyledText {
                anchors.right: groove.right
                anchors.bottom: groove.top
                anchors.bottomMargin: 4
                text: String(slider.max)
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }

            Rectangle {
                id: groove

                anchors.left: parent.left
                anchors.right: readout.left
                anchors.rightMargin: Appearance.spacing.md
                // Below centre, to leave room for the range labels above.
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                implicitHeight: 4
                radius: 2
                color: Theme.surfaceContainerHighest

                Rectangle {
                    width: groove.width * slider.fraction
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }

                Rectangle {
                    x: groove.width * slider.fraction - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    // A 4px groove is not a pointer target across a network.
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    function apply(mouse): void {
                        const f = Math.max(0, Math.min(1, (mouse.x + 10) / groove.width));
                        root.commit(slider.quantise(f));
                    }

                    onPressed: mouse => apply(mouse)
                    // Dragging writes the file on every frame it moves, which is
                    // fine: the write is a few hundred bytes and Config
                    // hot-reloads, so the shell resizes under the pointer and you
                    // can see what you are choosing.
                    onPositionChanged: mouse => {
                        if (pressed)
                            apply(mouse);
                    }
                }
            }
        }
    }

    // A closed list, for when the options outgrow a row of pills. Same data as
    // "choice" — the difference is only how many will fit.
    Component {
        id: selectControl

        Item {
            implicitHeight: 32

            Rectangle {
                id: selectField

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Math.min(parent.width, 260)
                implicitHeight: 32
                radius: Appearance.rounding.small
                color: selectHover.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.md
                    anchors.rightMargin: Appearance.padding.sm
                    spacing: Appearance.spacing.xs

                    StyledText {
                        Layout.fillWidth: true
                        text: String(root.value)
                        color: Theme.text
                        font.pixelSize: Appearance.font.size.sm
                        elide: Text.ElideRight
                    }

                    Icon {
                        text: "expand_more"
                        color: Theme.textMuted
                        size: Appearance.font.size.md
                    }
                }

                MouseArea {
                    id: selectHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectRequested(selectField)
                }
            }
        }
    }

    Component {
        id: choiceControl

        RowLayout {
            spacing: Appearance.spacing.xs

            Repeater {
                model: root.spec.options ?? []

                delegate: Rectangle {
                    id: option
                    required property var modelData

                    readonly property bool active: String(root.value) === String(option.modelData)

                    implicitWidth: optionText.implicitWidth + Appearance.padding.md * 2
                    implicitHeight: 28
                    radius: Appearance.rounding.full
                    color: option.active ? Theme.accentContainer : optionHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    border.width: option.active ? 0 : 1
                    border.color: Theme.outlineVariant

                    StyledText {
                        id: optionText
                        anchors.centerIn: parent
                        text: String(option.modelData)
                        color: option.active ? Theme.onAccentContainer : Theme.textSecondary
                        font.pixelSize: Appearance.font.size.xs
                    }

                    MouseArea {
                        id: optionHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.commit(option.modelData)
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    // Media players: a catalogue, filtered to what is actually installed.
    //
    // Toggles rather than free text because the value is a list of objects — a
    // label, an icon, the desktop-entry names to try and a fallback command —
    // and asking someone to write that by hand in a settings panel is asking
    // them to edit JSON with extra steps. The catalogue carries the awkward
    // parts; the panel only has to ask which ones you want.
    //
    // Anything not installed is not offered, because a button that launches
    // nothing is worse than no button.
    Component {
        id: appsControl

        ColumnLayout {
            id: apps

            spacing: Appearance.spacing.xs

            readonly property int chosen: SettingsCatalogue.chosenCount(root.value)
            readonly property bool full: apps.chosen >= SettingsCatalogue.maxMediaApps

            StyledText {
                text: `${apps.chosen} of ${SettingsCatalogue.maxMediaApps} chosen` + (apps.full ? " — deselect one to swap" : "")
                color: apps.full ? Theme.textMuted : Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
            }

            Repeater {
                model: SettingsCatalogue.installedMediaApps()

                delegate: RowLayout {
                    id: appRow
                    required property var modelData

                    readonly property bool on: {
                        for (const a of root.value ?? [])
                            if ((a.id ?? "") === appRow.modelData.id)
                                return true;
                        return false;
                    }

                    // Dimmed once the cap is reached, so the ones you cannot add
                    // look unavailable rather than merely unresponsive.
                    readonly property bool available: appRow.on || !apps.full

                    spacing: Appearance.spacing.sm
                    opacity: appRow.available ? 1 : 0.4

                    Rectangle {
                        implicitWidth: 18
                        implicitHeight: 18
                        radius: Appearance.rounding.small
                        color: appRow.on ? Theme.accent : "transparent"
                        border.width: appRow.on ? 0 : 1
                        border.color: Theme.outlineVariant

                        Icon {
                            anchors.centerIn: parent
                            visible: appRow.on
                            text: "check"
                            color: Theme.onAccent
                            size: Appearance.font.size.xs
                        }
                    }

                    Icon {
                        text: appRow.modelData.icon
                        color: Theme.textSecondary
                        size: Appearance.font.size.md
                    }

                    StyledText {
                        text: appRow.modelData.label
                        color: appRow.on ? Theme.text : Theme.textSecondary
                        font.pixelSize: Appearance.font.size.xs
                    }

                    // Music, video or audiobooks. Said rather than filtered on:
                    // two video players for local files and for streaming is a
                    // perfectly sensible pair, and so is one of each.
                    StyledText {
                        text: appRow.modelData.kind ?? ""
                        color: Theme.textMuted
                        font.pixelSize: Appearance.font.size.xs
                    }

                    // The first one enabled is the one Space reaches and the one
                    // the empty state offers first, so it is worth saying which.
                    StyledText {
                        visible: appRow.on && ((root.value ?? [])[0]?.id ?? "") === appRow.modelData.id
                        text: "default"
                        color: Theme.accent
                        font.pixelSize: Appearance.font.size.xs
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: appRow.available
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.commit(SettingsCatalogue.toggleMediaApp(root.value ?? [], appRow.modelData.id))
                    }
                }
            }

            StyledText {
                visible: SettingsCatalogue.installedMediaApps().length === 0
                text: "No known media players found on this machine"
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
            }
        }
    }

    Component {
        id: textControl

        Rectangle {
            implicitHeight: 30
            radius: Appearance.rounding.small
            color: Theme.surfaceContainerHighest
            border.width: field.activeFocus ? 1 : 0
            border.color: Theme.accent

            TextInput {
                id: field

                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.sm
                anchors.rightMargin: Appearance.padding.sm
                verticalAlignment: TextInput.AlignVCenter
                font.family: Appearance.font.family.sans
                font.pixelSize: Appearance.font.size.xs
                color: Theme.text
                selectionColor: Theme.accentContainer
                selectedTextColor: Theme.onAccentContainer
                clip: true

                // Set rather than bound, so typing is not fighting the config
                // file reloading underneath the cursor. Re-synced when the value
                // changes from elsewhere and this field is not being edited.
                Component.onCompleted: text = String(root.value ?? "")

                Connections {
                    target: root
                    function onValueChanged(): void {
                        if (!field.activeFocus)
                            field.text = String(root.value ?? "");
                    }
                }

                // On Enter and on losing focus, not on every keystroke — a write
                // per character would rewrite the file a dozen times for one
                // word, and Config reloads on each.
                onAccepted: root.commit(field.text)
                onActiveFocusChanged: if (!activeFocus && field.text !== String(root.value ?? ""))
                    root.commit(field.text)
            }
        }
    }
}
