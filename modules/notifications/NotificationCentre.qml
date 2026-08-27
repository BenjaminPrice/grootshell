import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The full notification list, docked to the right edge under the bar.

Panel {
    id: root

    edge: "right"
    open: ShellState.notifications
    implicitWidth: 400
    radius: Appearance.rounding.large

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: "Notifications"
                font.pixelSize: Appearance.font.size.lg
                color: Theme.text
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
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Notifs.count === 0

            Item {
                Layout.fillHeight: true
            }

            Icon {
                Layout.alignment: Qt.AlignHCenter
                text: "check_circle"
                color: Theme.textMuted
                size: Appearance.font.size.xxl
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Nothing to see"
                color: Theme.textMuted
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // --- List -----------------------------------------------------------
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Notifs.count > 0
            clip: true
            spacing: Appearance.spacing.sm
            model: Notifs.list

            delegate: Rectangle {
                id: entry
                required property var notification
                required property int index

                width: ListView.view.width
                implicitHeight: entryBody.implicitHeight + Appearance.padding.md * 2
                radius: Appearance.rounding.normal
                color: hover.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                ColumnLayout {
                    id: entryBody
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.md
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: entry.notification?.summary ?? ""
                            color: Theme.text
                            font.pixelSize: Appearance.font.size.sm
                        }

                        Icon {
                            text: "close"
                            color: hover.containsMouse ? Theme.textSecondary : "transparent"
                            size: Appearance.font.size.sm

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.dismiss(entry.notification)
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: entry.notification?.body ?? ""
                        color: Theme.textSecondary
                        font.pixelSize: Appearance.font.size.xs
                        wrapMode: Text.WordWrap
                        visible: text !== ""
                    }

                    StyledText {
                        text: entry.notification?.appName ?? ""
                        color: Theme.textMuted
                        font.pixelSize: Appearance.font.size.xs
                        visible: text !== ""
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    // Deliberately not click-to-dismiss: the close affordance
                    // above is explicit, and a whole-row click here would make
                    // reading a long notification a way to lose it.
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }

    component Action: Rectangle {
        id: action

        property string icon
        property bool active: false
        property bool interactive: true

        signal activated

        implicitWidth: 30
        implicitHeight: 30
        radius: width / 2
        color: active ? Theme.accentContainer : actionHover.containsMouse ? Theme.surfaceContainerHigh : "transparent"
        opacity: interactive ? 1 : 0.35

        Icon {
            anchors.centerIn: parent
            text: action.icon
            color: action.active ? Theme.accent : Theme.textSecondary
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
