import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// Translation.
//
// Uses XMLHttpRequest rather than shelling out to curl: it is built into QML, so
// there is one fewer process spawn and one fewer runtime dependency, and the
// response arrives as a string we were going to parse anyway.
//
// The endpoint is Google's unauthenticated translate_a/single, which is what
// every small translator front-end uses. It needs no key — which is the point,
// since groot has no credentials for anything — but it is also unofficial, so it
// is treated as best-effort: a failure shows a message, it does not throw.

Item {
    id: root

    property bool active: false

    // Japanese to English by default, not Detect. This machine's fcitx5/Mozc
    // setup exists for Japanese and the usual job is reading it, so naming the
    // source outright is both what you want and one less thing for the endpoint
    // to get wrong on a short string — "detect" on two kana is a guess.
    property string from: "ja"
    property string to: "en"

    readonly property var languages: [
        {
            code: "auto",
            label: "Detect"
        },
        {
            code: "en",
            label: "English"
        },
        {
            code: "ja",
            label: "日本語"
        },
        {
            code: "fr",
            label: "Français"
        },
        {
            code: "es",
            label: "Español"
        }
    ]

    property string result: ""
    property string status: ""

    // What the endpoint reported the source to be. Only meaningful while `from`
    // is "auto", and only used to give the swap a concrete language to put in
    // the target slot.
    property string detected: ""

    // The endpoint is Google's unofficial gtx one, and it throttles by IP. A
    // 600ms debounce while someone types is enough to earn a 429, and once
    // earned it persists for a while — so the defence is to ask less often
    // rather than to ask again harder.
    //
    // What was last SENT, so an unchanged string is never sent twice. Committing
    // an IME candidate can fire textChanged without changing the text.
    property string lastSent: ""

    // Backoff after a 429, in milliseconds. Doubles per rejection up to a
    // ceiling, resets on success.
    readonly property int backoffFloor: 5000
    readonly property int backoffCeiling: 120000
    property int backoff: 0

    // Deferred, for the same reason as the wallpaper picker: the panel extrudes
    // from zero size, so on the frame `active` flips there is nothing on screen
    // yet, and an invisible item cannot take active focus.
    onActiveChanged: if (active) Qt.callLater(root.grabFocus)

    function grabFocus(): void {
        if (root.active)
            source.forceActiveFocus();
    }

    // Swap the two languages, and the two texts with them.
    //
    // Moving the result into the input is the point: swapping mid-task almost
    // always means "now go back the other way with what I just got", and
    // leaving the box holding the original would translate the wrong string.
    //
    // Detect cannot be a target, so swapping out of it would produce an invalid
    // pair. It resolves to whatever the endpoint just reported instead, and
    // falls back to English when nothing has been translated yet.
    function swap(): void {
        const nextTo = root.from === "auto" ? (root.detected || "en") : root.from;

        root.from = root.to;
        root.to = nextTo;

        if (root.result) {
            const carried = root.result;
            root.result = "";
            source.text = carried;
            // Straight through rather than via the debounce: this is a
            // deliberate press, not typing.
            root.translate();
        } else if (source.text.trim()) {
            // Nothing to carry back — a failure, or a swap before the first
            // result landed — but the input is now pointed the other way and
            // still needs translating.
            root.translate();
        }
    }

    function translate(): void {
        const text = source.text.trim();
        if (!text) {
            root.result = "";
            root.status = "";
            root.lastSent = "";
            return;
        }

        // Nothing changed, so there is nothing to ask. Cheap, and it removes the
        // most common source of duplicate requests.
        if (text === root.lastSent && root.result !== "")
            return;

        if (retry.running) {
            // Still serving a rejection. The pending retry will pick up whatever
            // the text is by then, so this does not need to queue anything.
            return;
        }

        root.lastSent = text;
        root.status = "Translating…";

        const url = "https://translate.googleapis.com/translate_a/single" + "?client=gtx" + `&sl=${encodeURIComponent(root.from)}` + `&tl=${encodeURIComponent(root.to)}` + "&dt=t" + `&q=${encodeURIComponent(text)}`;

        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status !== 200) {
                // 0 means no HTTP response at all — the request never left, or
                // never came back. That is a different problem from the endpoint
                // saying no, and conflating the two under "Failed" is what made
                // this undiagnosable from the panel.
                if (xhr.status === 429) {
                    // Rate limited. Back off, say so with the wait visible, and
                    // retry by itself — a rejection you have to notice and act
                    // on is worse than one that resolves while you keep typing.
                    root.backoff = Math.min(root.backoffCeiling, Math.max(root.backoffFloor, root.backoff * 2));
                    root.lastSent = "";
                    retry.interval = root.backoff;
                    retry.restart();
                    root.status = `Rate limited — retrying in ${Math.round(root.backoff / 1000)}s`;
                } else {
                    // 0 means no HTTP response at all — the request never left,
                    // or never came back. That is a different problem from the
                    // endpoint saying no.
                    root.status = xhr.status === 0 ? "No response — check the network" : `Rejected (${xhr.status})`;
                }

                // To the journal as well, because the panel has room for a
                // phrase and this needs a status line.
                console.warn("grootshell: translate failed —", "status:", xhr.status, "statusText:", xhr.statusText || "(none)", "body:", (xhr.responseText || "").slice(0, 200));
                return;
            }

            try {
                // Shape is [[[chunk, original, …], …], …] — long input comes
                // back split into sentences, so the chunks have to be rejoined
                // rather than just taking the first.
                const parsed = JSON.parse(xhr.responseText);
                root.result = parsed[0].map(part => part[0]).join("");
                root.status = "";
                root.backoff = 0;
                // Index 2 is the detected source language.
                root.detected = parsed[2] ?? "";
            } catch (e) {
                root.status = "Could not read the response";
                console.warn("grootshell: translate parse failed —", e, "body:", (xhr.responseText || "").slice(0, 200));
            }
        };
        xhr.send();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs

            Picker {
                Layout.fillWidth: true
                model: root.languages
                current: root.from
                onPicked: code => {
                    root.from = code;
                    root.translate();
                }
            }

            // The arrow is the swap control. It already points from one
            // language to the other, so making it the thing that reverses them
            // needs no new affordance — just a cursor and a hover state to say
            // it is pressable.
            Icon {
                text: "swap_horiz"
                color: swapHover.containsMouse ? Theme.accent : Theme.textMuted
                size: Appearance.font.size.md

                MouseArea {
                    id: swapHover
                    anchors.fill: parent
                    anchors.margins: -Appearance.padding.xs
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.swap()
                }
            }

            Picker {
                Layout.fillWidth: true
                // "Detect" is meaningless as a target.
                model: root.languages.filter(l => l.code !== "auto")
                current: root.to
                onPicked: code => {
                    root.to = code;
                    root.translate();
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: Appearance.rounding.normal
            color: Theme.surfaceContainer

            TextEdit {
                id: source
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                font.family: Appearance.font.family.sans
                font.pixelSize: Appearance.font.size.sm
                color: Theme.text
                selectionColor: Theme.accentContainer
                selectedTextColor: Theme.onAccentContainer
                wrapMode: TextEdit.Wrap
                clip: true

                // Debounced rather than translated per keystroke — each one is
                // a network round trip against someone else's endpoint.
                onTextChanged: debounce.restart()

                StyledText {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    text: "Text to translate"
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.sm
                    // Hidden while the IME is composing, not just when text has
                    // been committed. A preedit string is not `text` yet — it is
                    // drawn over the field by the input method — so binding this
                    // to text alone left the placeholder sitting underneath half
                    // a Japanese word until the first Enter.
                    visible: source.text === "" && !source.inputMethodComposing
                }
            }
        }

        // 1200ms rather than 600. Every keystroke that survives the debounce is
        // a request against an endpoint that counts them, and half a second of
        // extra latency on a panel you opened deliberately costs less than the
        // minutes of "Rate limited" that the faster setting bought.
        Timer {
            id: debounce
            interval: 1200
            onTriggered: root.translate()
        }

        // Fires once the backoff has elapsed, translating whatever is in the
        // box by then.
        Timer {
            id: retry
            repeat: false
            onTriggered: root.translate()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.normal
            color: Theme.surfaceContainer

            Flickable {
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                contentHeight: output.implicitHeight
                clip: true

                StyledText {
                    id: output
                    width: parent.width
                    text: root.status || root.result
                    color: root.status ? Theme.textMuted : Theme.text
                    font.pixelSize: Appearance.font.size.sm
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: copyRow.implicitWidth + Appearance.padding.md * 2
                implicitHeight: 30
                radius: Appearance.rounding.full
                color: copyHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                visible: root.result !== ""

                RowLayout {
                    id: copyRow
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.xs

                    Icon {
                        text: "content_copy"
                        color: Theme.textSecondary
                        size: Appearance.font.size.sm
                    }

                    StyledText {
                        text: "Copy"
                        color: Theme.textSecondary
                        font.pixelSize: Appearance.font.size.xs
                    }
                }

                MouseArea {
                    id: copyHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["bash", "-c", `printf '%s' ${JSON.stringify(root.result)} | wl-copy`])
                }
            }
        }
    }

    component Picker: Rectangle {
        id: picker

        property var model: []
        property string current

        signal picked(string code)

        implicitHeight: 30
        radius: Appearance.rounding.normal
        color: pickerHover.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        StyledText {
            anchors.centerIn: parent
            text: (picker.model.find(l => l.code === picker.current) ?? {
                    label: picker.current
                }).label
            color: Theme.text
            font.pixelSize: Appearance.font.size.xs
        }

        // Cycles rather than opening a menu. With a handful of languages a
        // click-through is faster than a popup, and a popup inside a layered
        // panel needs its own input region to be clickable at all.
        MouseArea {
            id: pickerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const i = picker.model.findIndex(l => l.code === picker.current);
                picker.picked(picker.model[(i + 1) % picker.model.length].code);
            }
        }
    }
}
