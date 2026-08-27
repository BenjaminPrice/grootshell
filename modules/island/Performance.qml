import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Machine health, as a panel of dials.
//
// The only tab that costs anything to display — see the subscribe/unsubscribe
// handling in Island.qml and the reasoning in services/Sys.qml. That matters
// more here than it looks: the GPU readings come from amdgpu sysfs attributes,
// and touching those wakes a runtime-suspended card. A tab that polled while
// closed would keep the GPU awake to ask whether it was busy.
//
// Ordered by what you actually look at on a machine that streams games: the two
// processors first, then their temperatures, then memory.

Item {
    id: root

    // Colour carries the warning so the number does not have to be read.
    // Thresholds are deliberately high — a box that streams games sits at 70%
    // CPU as a matter of course, and a dial that is orange all evening teaches
    // you to ignore it.
    function loadColour(value: real): color {
        if (value > 90)
            return Theme.error;
        if (value > 75)
            return Theme.warning;
        return Theme.accent;
    }

    // Silicon runs hot by design; 80°C is warm, not alarming, and thermal
    // throttling starts well above that.
    function tempColour(celsius: real): color {
        if (celsius > 90)
            return Theme.error;
        if (celsius > 80)
            return Theme.warning;
        return Theme.accent;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.md

        GridLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            columnSpacing: Appearance.spacing.lg
            rowSpacing: Appearance.spacing.md

            Gauge {
                label: "CPU"
                value: Sys.cpu
                detail: `${Math.round(Sys.cpu)}%`
                fill: root.loadColour(Sys.cpu)
            }

            Gauge {
                label: "GPU"
                value: Sys.gpu
                detail: `${Math.round(Sys.gpu)}%`
                fill: root.loadColour(Sys.gpu)
            }

            Gauge {
                label: "Memory"
                value: Sys.memory
                detail: `${Math.round(Sys.memory)}%`
                fill: root.loadColour(Sys.memory)
            }

            Gauge {
                label: "CPU temp"
                // Scaled against a 100°C ceiling so the sweep means the same
                // thing as the load dials: fraction of the way to trouble.
                value: Math.min(100, Sys.temperature)
                detail: `${Math.round(Sys.temperature)}°`
                fill: root.tempColour(Sys.temperature)
            }

            Gauge {
                label: "GPU temp"
                value: Math.min(100, Sys.gpuTemperature)
                detail: `${Math.round(Sys.gpuTemperature)}°`
                fill: root.tempColour(Sys.gpuTemperature)
            }

            Gauge {
                label: "Swap"
                value: Sys.swap
                detail: `${Math.round(Sys.swap)}%`
                fill: root.loadColour(Sys.swap)
                // A machine with no swap should show nothing rather than a
                // permanently empty dial implying something is wrong.
                visible: Sys.swap > 0
            }
        }

        Item {
            Layout.fillHeight: true
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `up ${Sys.formatUptime()}`
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
        }
    }
}
