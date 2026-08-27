import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The left panel: tools, not status.
//
// Everything else in this shell tells you about the machine. This is the one
// surface that does something for you, which is why it gets the whole left edge
// and a pane switcher rather than being a popout.
//
// Structured as a list of panes from the start so adding one is a new file and a
// line in `panes`. An AI chat pane belongs here and is deliberately absent for
// now — groot has no API access, and doing it properly means going through an
// agent protocol against a subscription rather than pasting a key into a config
// file. LINE, WhatsApp and Messenger are the same shape of problem and slot into
// the same list when they land.

Panel {
    id: root

    edge: "left"
    open: ShellState.sidebar
    implicitWidth: 380
    radius: Appearance.rounding.large

    readonly property var panes: [
        {
            id: "translate",
            icon: "translate",
            label: "Translate"
        }
    ]

    property string pane: "translate"

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        // Pane switcher. Hidden while there is only one — a tab strip with a
        // single tab is furniture.
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs
            visible: root.panes.length > 1

            Repeater {
                model: root.panes

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.pane === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Appearance.rounding.normal
                    color: active ? Theme.accentContainer : "transparent"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.xs

                        Icon {
                            text: modelData.icon
                            filled: active
                            color: active ? Theme.accent : Theme.textSecondary
                            size: Appearance.font.size.md
                        }

                        StyledText {
                            text: modelData.label
                            color: active ? Theme.accent : Theme.textSecondary
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pane = modelData.id
                    }
                }
            }
        }

        Translator {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.pane === "translate"
            active: root.open && root.pane === "translate"
        }
    }
}
