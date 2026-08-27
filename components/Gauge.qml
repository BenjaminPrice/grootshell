import QtQuick
import QtQuick.Shapes
import qs.config

// A circular gauge: a 270° arc with the value in the middle.
//
// Rounded arcs rather than linear bars because a row of bars all reading "some
// fraction of the way along" is hard to scan — every one looks the same at a
// glance. A ring has a distinct shape at 20% and at 80%, so a panel of them
// reads as a picture of the machine rather than as a list of numbers.
//
// 270° with the gap at the bottom, so the open end points away from the label
// and the ring reads as a dial rather than as a broken circle.

Item {
    id: root

    property real value: 0        // 0-100
    property string label
    property string detail
    property color fill: Theme.accent
    property int thickness: Math.max(6, Math.round(9 * Appearance.font.scale))

    // Where the arc starts, and how far it sweeps. Qt measures clockwise from
    // 3 o'clock, so 135° is the lower-left.
    readonly property real startAngle: 135
    readonly property real fullSweep: 270

    readonly property real fraction: Math.max(0, Math.min(1, value / 100))

    // A floor, not a fixed size: inside a filling GridLayout these are handed a
    // cell and should use it, but they must not collapse to nothing in a layout
    // that does not offer one.
    readonly property int minDial: Math.round(96 * Appearance.font.scale)

    implicitWidth: minDial
    implicitHeight: minDial + labelText.implicitHeight + Appearance.spacing.xs

    Item {
        id: dial

        // Square, and as large as the cell allows once the label has its row.
        readonly property int available: Math.min(root.width, root.height - labelText.implicitHeight - Appearance.spacing.xs)
        width: Math.max(root.minDial, available)
        height: width
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // The arcs redraw on every metrics tick; asynchronous tessellation
            // would show a frame of nothing each time.
            asynchronous: false

            // Track — the full sweep, dimmed.
            ShapePath {
                strokeColor: Theme.surfaceContainerHighest
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - root.thickness / 2
                    radiusY: dial.height / 2 - root.thickness / 2
                    startAngle: root.startAngle
                    sweepAngle: root.fullSweep
                }
            }

            // Value.
            ShapePath {
                strokeColor: root.fill
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    id: valueArc

                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - root.thickness / 2
                    radiusY: dial.height / 2 - root.thickness / 2
                    startAngle: root.startAngle
                    sweepAngle: root.fullSweep * root.fraction

                    Behavior on sweepAngle {
                        enabled: Appearance.anim.enabled
                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: root.detail
            color: Theme.text
            font.pixelSize: Appearance.font.size.md
            mono: true
        }
    }

    StyledText {
        id: labelText

        anchors.top: dial.bottom
        anchors.topMargin: Appearance.spacing.xs
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        color: Theme.textSecondary
        font.pixelSize: Appearance.font.size.xs
    }
}
