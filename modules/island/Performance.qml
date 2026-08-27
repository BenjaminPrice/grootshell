import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Machine health. The only tab that costs anything to display — see the
// subscribe/unsubscribe handling in Island.qml and the reasoning in
// services/Sys.qml.

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.sm

        Meter {
            label: "CPU"
            value: Sys.cpu
            detail: `${Math.round(Sys.cpu)}%`
        }

        Meter {
            label: "Memory"
            value: Sys.memory
            detail: `${Math.round(Sys.memory)}%`
        }

        Meter {
            label: "Swap"
            value: Sys.swap
            detail: `${Math.round(Sys.swap)}%`
            // A machine with no swap should show nothing rather than a
            // permanently empty bar implying something is wrong.
            visible: Sys.swap > 0
        }

        Meter {
            label: "Disk"
            value: Sys.disk
            detail: `${Math.round(Sys.disk)}%`
        }

        Meter {
            label: "CPU temp"
            // Scaled against a 100°C ceiling so the bar means the same thing as
            // the others: fraction of the way to trouble.
            value: Math.min(100, Sys.temperature)
            detail: `${Math.round(Sys.temperature)}°C`
            visible: Sys.temperature > 0
        }

        Item {
            Layout.fillHeight: true
        }

        StyledText {
            text: `up ${Sys.formatUptime()}`
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
        }
    }

    component Meter: ColumnLayout {
        id: meter

        property string label
        property real value: 0
        property string detail

        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: meter.label
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: meter.detail
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.surfaceContainerHighest

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.value / 100))
                height: parent.height
                radius: parent.radius
                // Colour carries the warning so the number does not have to be
                // read. Thresholds are deliberately high — a box that streams
                // games sits at 70% CPU as a matter of course, and a bar that is
                // orange all evening teaches you to ignore it.
                color: meter.value > 90 ? Theme.error : meter.value > 75 ? Theme.warning : Theme.accent

                Behavior on width {
                    enabled: Appearance.anim.enabled
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on color {
                    enabled: Appearance.anim.enabled
                    ColorAnimation {
                        duration: Appearance.anim.normal
                    }
                }
            }
        }
    }
}
