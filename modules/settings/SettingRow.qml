import QtQuick
import QtQuick.Layouts
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
// ## The override marker
//
// Every row can say whether the value is yours or the shipped default, and reset
// it if it is yours. That is not decoration — it is the visible half of how
// settings are stored. Keys you have not set are ABSENT from shell.json and
// follow the default forever after, including when the default improves; a panel
// that could only ever write values would quietly opt you out of that on first
// use. See services/Settings.qml.

Item {
    id: root

    required property var spec

    // Bumped by the panel after any write, because "is this key present in the
    // file" is not a property anything can bind to — it is a question answered by
    // reading the file, and only a write can change the answer.
    property int revision: 0

    readonly property var value: Settings.resolve(root.spec.key)
    readonly property bool overridden: root.revision >= 0 && Settings.has(root.spec.key)

    implicitHeight: Math.max(control.implicitHeight, label.implicitHeight, 36)

    signal changed

    function commit(v: var): void {
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
            Layout.preferredWidth: 260
            Layout.maximumWidth: 260
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
                    default:
                        return textControl;
                    }
                }
            }
        }

        // Only where there is something to undo. A permanently visible reset
        // that is usually a no-op teaches you to ignore it.
        Icon {
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

            implicitHeight: 28

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

            Rectangle {
                id: groove
                anchors.left: parent.left
                anchors.right: readout.left
                anchors.rightMargin: Appearance.spacing.md
                anchors.verticalCenter: parent.verticalCenter
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
