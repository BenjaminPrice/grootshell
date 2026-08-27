import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Transient notification popups, extruded from the right border.
//
// Docked rather than floating, for the same reason as the wallpaper strip: a
// card hovering near the frame reads as a separate thing that arrived, where an
// extrusion of the frame reads as the shell telling you something. The border
// bulges out to make room and retracts when the last one goes.
//
// Hidden entirely in game mode. Sunshine's own hooks emit notifications, and a
// banner over a game is both a distraction and, on a streamed host, a re-encode
// of every frame it covers.
//
// Also hidden while the centre is open — the same notifications would otherwise
// be on screen twice, a few hundred pixels apart.

DockedPanel {
    id: root

    edge: "right"
    open: !GameMode.enabled && Notifs.popups.count > 0 && !ShellState.notifications

    depth: Math.round(420 * Appearance.font.scale)

    // Along the edge: as tall as the stack, so the frame bulges to exactly the
    // notifications present rather than to a fixed box with gaps in it.
    span: stack.implicitHeight + padding * 2

    Behavior on span {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    ColumnLayout {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.sm

        Repeater {
            model: Notifs.popups

            // `notification` and `time` are ListModel roles, so they arrive as
            // delegate properties directly. Binding them from `modelData` was
            // the bug that made every toast render blank — over a ListModel,
            // modelData is the whole row rather than the role.
            delegate: NotificationCard {
                required property var notification
                required property real time

                Layout.fillWidth: true

                // A toast is on a timer. A chevron it will vanish out from under
                // belongs in the centre, where things stay put.
                expandable: false

                onDiscarded: Notifs.dismiss(notification)
            }
        }
    }
}
