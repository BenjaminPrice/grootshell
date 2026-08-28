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

    // Japanese first because that is what groot's fcitx5/Mozc setup is for; the
    // interesting direction is usually reading something, not writing it.
    property string from: "auto"
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

    // Deferred, for the same reason as the wallpaper picker: the panel extrudes
    // from zero size, so on the frame `active` flips there is nothing on screen
    // yet, and an invisible item cannot take active focus.
    onActiveChanged: if (active) Qt.callLater(root.grabFocus)

    function grabFocus(): void {
        if (root.active)
            source.forceActiveFocus();
    }

    function translate(): void {
        const text = source.text.trim();
        if (!text) {
            root.result = "";
            root.status = "";
            return;
        }

        root.status = "Translating…";

        const url = "https://translate.googleapis.com/translate_a/single" + "?client=gtx" + `&sl=${encodeURIComponent(root.from)}` + `&tl=${encodeURIComponent(root.to)}` + "&dt=t" + `&q=${encodeURIComponent(text)}`;

        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status !== 200) {
                root.status = `Failed (${xhr.status})`;
                return;
            }

            try {
                // Shape is [[[chunk, original, …], …], …] — long input comes
                // back split into sentences, so the chunks have to be rejoined
                // rather than just taking the first.
                const parsed = JSON.parse(xhr.responseText);
                root.result = parsed[0].map(part => part[0]).join("");
                root.status = "";
            } catch (e) {
                root.status = "Could not read the response";
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

            Icon {
                text: "arrow_forward"
                color: Theme.textMuted
                size: Appearance.font.size.sm
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
                    visible: source.text === ""
                }
            }
        }

        Timer {
            id: debounce
            interval: 600
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
