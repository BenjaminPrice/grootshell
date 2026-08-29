import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The full notification list, extruded from the right border below the bar.
//
// Same treatment as the toasts, which is the point — the transient version and
// the permanent one should look like one object in two states, not two designs
// that happen to show the same text.
//
// Cards here are expandable. This is where a notification goes to be read
// properly rather than glanced at, so the whole body and any actions the sender
// offered are reachable.

DockedPanel {
    id: root

    edge: "right"
    open: ShellState.notifications

    depth: Math.round(440 * Appearance.font.scale)

    // Filleted at both ends, same as the toasts — it grows out of the right
    // border and nothing else. See the note there for why that changed.

    // Half the usable height, hung below the pills rather than filling the edge.
    // Computed from the same values shell.qml uses to place it, rather than
    // anchoring top and bottom — a DockedPanel sizes itself from span and depth,
    // so anchoring both edges would fight it. Top-aligned because it grows
    // downward as notifications arrive, and a centred panel would push its own
    // contents around every time one did.
    readonly property int topDock: Config.bar.height + Hypr.frameThickness + Hypr.windowInset
    span: Math.round(((parent?.height ?? 1080) - topDock - Hypr.frameThickness) * 0.5)

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        // --- Header ---------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            StyledText {
                text: "Notifications"
                font.pixelSize: Appearance.font.size.lg
                color: Theme.text
            }

            StyledText {
                text: Notifs.count > 0 ? `${Notifs.count}` : ""
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }

            Item {
                Layout.fillWidth: true
            }

            Action {
                icon: Notifs.doNotDisturb ? "notifications_off" : "notifications_active"
                active: Notifs.doNotDisturb
                onActivated: Notifs.doNotDisturb = !Notifs.doNotDisturb
            }

            Action {
                icon: "clear_all"
                interactive: Notifs.count > 0
                onActivated: Notifs.clear()
            }
        }

        // --- Empty ----------------------------------------------------------
        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Notifs.count === 0
            icon: "check_circle"
            title: "Nothing to see"
        }

        // --- List -----------------------------------------------------------
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Notifs.count > 0
            clip: true
            spacing: Appearance.spacing.sm
            model: Notifs.all

            // Required properties are inherited from NotificationCard and filled
            // from the model roles; redeclaring them here would shadow the ones
            // the card actually reads. See the note in Toasts.qml.
            delegate: NotificationCard {
                width: ListView.view.width
                expandable: true

                onDiscarded: Notifs.dismiss(notification)
            }
        }
    }

    component Action: Rectangle {
        id: action

        property string icon
        property bool active: false
        property bool interactive: true

        signal activated

        implicitWidth: Appearance.font.size.xl
        implicitHeight: implicitWidth
        radius: width / 2
        color: active ? Theme.accentContainer : actionHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"
        opacity: interactive ? 1 : 0.35

        Behavior on color {
            enabled: Appearance.anim.enabled
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        Icon {
            anchors.centerIn: parent
            text: action.icon
            color: action.active ? Theme.onAccentContainer : Theme.textSecondary
            size: Appearance.font.size.md
        }

        MouseArea {
            id: actionHover
            anchors.fill: parent
            hoverEnabled: true
            enabled: action.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: action.activated()
        }
    }
}
