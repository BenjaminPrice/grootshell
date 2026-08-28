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

        // Fills the panel rather than sitting at its natural size — the island
        // grows for this tab specifically (see Island.qml), and dials floating
        // in the top half of the space it just made would be worse than not
        // having grown at all.
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignCenter
            // One row. Six columns covers the six dials; Swap hides itself on a
            // machine without any, and GridLayout skips an invisible child
            // rather than leaving a hole, so the usual case is a row of five.
            columns: 6
            columnSpacing: Appearance.spacing.lg
            rowSpacing: Appearance.spacing.md

            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "CPU"
                value: Sys.cpu
                detail: `${Math.round(Sys.cpu)}%`
                fill: root.loadColour(Sys.cpu)
            }

            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "GPU"
                value: Sys.gpu
                detail: `${Math.round(Sys.gpu)}%`
                fill: root.loadColour(Sys.gpu)
            }

            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Memory"
                value: Sys.memory
                detail: `${Math.round(Sys.memory)}%`
                // A percentage tells you how close to trouble you are; the
                // absolute figure tells you whether another browser is going to
                // be a problem. They answer different questions, so both.
                //
                // The total reads about 31 rather than the 32 in the machine —
                // MemTotal excludes what the kernel and firmware reserve. That
                // is the same number `free -h` prints, which is what anyone
                // would check it against.
                sub: Sys.memoryTotalKb > 0 ? `${Sys.gib(Sys.memoryUsedKb).toFixed(1)}/${Math.round(Sys.gib(Sys.memoryTotalKb))} GB` : ""
                fill: root.loadColour(Sys.memory)
            }

            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "CPU temp"
                // Scaled against a 100°C ceiling so the sweep means the same
                // thing as the load dials: fraction of the way to trouble.
                value: Math.min(100, Sys.temperature)
                detail: `${Math.round(Sys.temperature)}°`
                fill: root.tempColour(Sys.temperature)
            }

            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "GPU temp"
                value: Math.min(100, Sys.gpuTemperature)
                detail: `${Math.round(Sys.gpuTemperature)}°`
                fill: root.tempColour(Sys.gpuTemperature)
            }

            Gauge {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Swap"
                value: Sys.swap
                detail: `${Math.round(Sys.swap)}%`
                fill: root.loadColour(Sys.swap)
                // A machine with no swap should show nothing rather than a
                // permanently empty dial implying something is wrong.
                visible: Sys.swap > 0
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `up ${Sys.formatUptime()}`
            color: Theme.textMuted
            font.pixelSize: Appearance.font.size.xs
        }
    }
}
