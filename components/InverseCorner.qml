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

            // PathArc rather than PathAngleArc: it names the END POINT, so the
            // path is closed and well-formed no matter what the direction flag
            // does. With a swept angle the endpoint is implied by a sweep
            // convention, and getting that backwards puts the arc outside the
            // square entirely.
            //
            // Start at the square's top-right and finish at its bottom-left,
            // along the circle of radius `size` centred on the top-left. That
            // arc passes through the middle of the square, which is the boundary
            // of the disc being removed.
            PathMove {
                x: root.size
                y: 0
            }

            PathArc {
                x: 0
                y: root.size
                radiusX: root.size
                radiusY: root.size
                // Clockwise on screen, where y increases downward.
                direction: PathArc.Clockwise
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
