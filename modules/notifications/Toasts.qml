import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Transient notification popups, stacked under the bar on the right.
//
// Docked to the frame's inner edge rather than floating with a margin, so they
// slide out of the border the same way every other panel does.
//
// Hidden entirely in game mode. Sunshine's own hooks emit notifications, and a
// banner appearing over a game is both a distraction and, on a streamed host, a
// re-encode of the whole frame it covers.

Item {
    id: root

    readonly property int inset: Config.border.thickness

    implicitWidth: 380 + inset
    implicitHeight: column.implicitHeight + Appearance.spacing.md
    visible: !GameMode.enabled && Notifs.popups.count > 0 && !ShellState.notifications

    ColumnLayout {
        id: column
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.inset
        anchors.topMargin: Appearance.spacing.sm
        width: 380
        spacing: Appearance.spacing.sm

        Repeater {
            model: Notifs.popups

            // `notification` is a ListModel role, so it arrives as a delegate
            // property directly. Binding it from `modelData` was the bug that
            // made every toast render blank: over a ListModel, modelData is the
            // whole ROW — { notification: ... } — not the notification, so every
            // field read off it was undefined.
            delegate: Toast {
                required property var notification
                Layout.fillWidth: true
            }
        }
    }

    component Toast: Rectangle {
        id: toast

        property var notification

        implicitHeight: body.implicitHeight + Appearance.padding.md * 2
        radius: Appearance.rounding.normal
        color: Theme.layer(2)
        border.width: 1
        border.color: notification?.urgency === 2 ? Theme.error : Theme.outlineVariant

        // Slides in from the right edge it is docked to.
        opacity: 0
        x: 40
        Component.onCompleted: {
            if (Appearance.anim.enabled)
                enter.start();
            else {
                opacity = 1;
                x = 0;
            }
        }

        ParallelAnimation {
            id: enter
            NumberAnimation {
                target: toast
                property: "opacity"
                to: 1
                duration: Appearance.anim.normal
            }
            NumberAnimation {
                target: toast
                property: "x"
                to: 0
                duration: Appearance.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.emphasised
            }
        }

        RowLayout {
            id: body
            anchors.fill: parent
            anchors.margins: Appearance.padding.md
            spacing: Appearance.spacing.md

            Icon {
                Layout.alignment: Qt.AlignTop
                text: toast.notification?.urgency === 2 ? "error" : "notifications"
                color: toast.notification?.urgency === 2 ? Theme.error : Theme.accent
                filled: true
                size: Appearance.font.size.lg
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: toast.notification?.summary ?? ""
                    color: Theme.text
                    font.pixelSize: Appearance.font.size.sm
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: toast.notification?.body ?? ""
                    color: Theme.textSecondary
                    font.pixelSize: Appearance.font.size.xs
                    // Two lines, then elide. A notification is a summary; if it
                    // needs more room it belongs in the centre, which has it.
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                StyledText {
                    text: toast.notification?.appName ?? ""
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                    visible: text !== ""
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                // Middle-click discards outright; left-click just dismisses the
                // popup and leaves it in the centre to read later.
                if (mouse.button === Qt.MiddleButton)
                    Notifs.dismiss(toast.notification);
                else
                    Notifs.dismissPopup(toast.notification);
            }
        }
    }
}
