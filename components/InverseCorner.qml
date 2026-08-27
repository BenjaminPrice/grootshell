import QtQuick
import QtQuick.Shapes
import qs.config

// An inverse — concave — rounded corner.
//
// A normal rounded corner removes material from the outside of a shape. This
// adds material to the *inside* of one, filling the notch where two filled
// regions meet at a reflex angle so the join curves instead of stepping.
//
// It is the primitive the whole "panels grow out of the frame" effect rests on.
// Where a docked panel's side meets the frame band, the filled region turns
// through 270°, and a bare 270° corner reads as two rectangles overlapping. One
// of these in each junction turns it into a single continuous surface.
//
// Geometry: a square with one quarter-disc removed, the disc centred on the
// named corner. Drawn from the far corner around the arc, so the fill is the
// region *between* the arc and the opposite corner:
//
//     removed ┌────╮        the arc is the boundary of the disc;
//     corner  │····╰──╮     everything below and right of it is filled
//             │·······│
//             ╰───────╯
//
// Orientation is a rotation rather than four hand-written paths. Rotating the
// square 90° clockwise about its centre maps the removed corner top-left →
// top-right → bottom-right → bottom-left, which covers every case.

Item {
    id: root

    // Which corner the quarter-disc is removed from, and therefore which way the
    // curve faces: "topLeft" | "topRight" | "bottomRight" | "bottomLeft".
    property string corner: "topLeft"
    property color color: Theme.frame

    // Square by definition — a non-square inverse corner is an ellipse arc and
    // does not match the rounding on anything it joins.
    property int size: Appearance.rounding.normal

    implicitWidth: size
    implicitHeight: size

    rotation: {
        switch (root.corner) {
        case "topRight":
            return 90;
        case "bottomRight":
            return 180;
        case "bottomLeft":
            return 270;
        default:
            return 0;
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Static geometry; re-tessellating per frame is waste on a host that
        // pays for frames twice.
        asynchronous: false

        ShapePath {
            fillColor: root.color
            strokeWidth: 0

            // Qt measures angles from 3 o'clock, positive sweeping clockwise on
            // screen. With the disc centred on the top-left, angle 0 is the
            // square's top-right and angle 90 its bottom-left.
            PathMove {
                x: root.size
                y: 0
            }

            PathAngleArc {
                centerX: 0
                centerY: 0
                radiusX: root.size
                radiusY: root.size
                startAngle: 0
                sweepAngle: 90
            }

            PathLine {
                x: root.size
                y: root.size
            }

            PathLine {
                x: root.size
                y: 0
            }
        }
    }
}
