import QtQuick
import QtQuick.Layouts
import qs.config

// "There is nothing here", centred in whatever space it is given.
//
// Centred with anchors rather than with Layout.alignment and a pair of
// fillHeight spacers. That arrangement is the obvious one and it does not
// reliably centre horizontally — the column ends up as wide as its widest child
// and the alignment has nothing to centre within, so the text sits against the
// left edge while looking vertically correct. Anchoring a fixed-size column to
// the centre of a filling Item has no such failure mode.
//
// Shared because there were three of these — the notification centre, the
// wallpaper switcher, and the keybind modal — all written the same way, so all
// three were wrong the same way.

Item {
    id: root

    // Optional. Some empty states are a statement ("nothing to see"), which
    // suits a glyph; others are an instruction ("put images here"), which does
    // not need one.
    property string icon
    property string title
    property string detail

    // Optional. When an empty state is empty because of something the user can
    // fix from inside the shell, offer the fix here rather than only describing
    // it — an instruction that ends in a button is one someone will follow.
    // Left unset, nothing is drawn and this is the plain empty state it was.
    property string action
    signal actionTriggered

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: Appearance.spacing.xs

        Icon {
            Layout.alignment: Qt.AlignHCenter
            visible: root.icon !== ""
            text: root.icon
            color: Theme.textMuted
            size: Appearance.font.size.xxl
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            color: Theme.textSecondary
            font.pixelSize: Appearance.font.size.md
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.detail !== ""
            text: root.detail
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.spacing.sm

            visible: root.action !== ""
            implicitWidth: actionText.implicitWidth + Appearance.padding.lg * 2
            implicitHeight: actionText.implicitHeight + Appearance.padding.sm * 2
            radius: Appearance.rounding.full
            color: actionHover.containsMouse ? Theme.accent : Theme.accentContainer

            Behavior on color {
                enabled: Appearance.anim.enabled
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            StyledText {
                id: actionText

                anchors.centerIn: parent
                text: root.action
                color: actionHover.containsMouse ? Theme.onAccent : Theme.text
                font.pixelSize: Appearance.font.size.sm
            }

            MouseArea {
                id: actionHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionTriggered()
            }
        }
    }
}
