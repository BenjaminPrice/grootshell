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

    // The top edge is flush with the bar, which is the same colour. Without
    // this the panel keeps a convex corner where the two meet, which reads as a
    // rounded box sitting under the bar rather than as one continuous surface.
    abutsStart: true

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

            // NotificationCard already declares `notification` and `time` as
            // required, and a view fills a delegate's required properties from
            // the model roles of the same name — INCLUDING inherited ones.
            //
            // Redeclaring them here was the bug that left every card blank: the
            // redeclaration creates a SECOND property on the delegate, the model
            // fills that one, and the card's own bindings go on reading the base
            // property nobody ever assigned.
            delegate: NotificationCard {
                Layout.fillWidth: true

                // Expandable, and therefore able to show its actions. That is
                // only safe because hovering a toast holds its expiry — without
                // that, a button on something counting down is a target that
                // times out from under the pointer.
                expandable: true

                onDiscarded: Notifs.dismiss(notification)
            }
        }
    }
}
