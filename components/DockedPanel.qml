import QtQuick
import qs.config
import qs.services

// A panel that grows out of the frame rather than floating above it.
//
// The difference from ./Panel.qml is not decoration. A Panel is a card: its own
// colour, its own outline, a gap between it and everything else. A DockedPanel
// is an *extrusion* of the border — same colour, flush to the screen edge, with
// the junctions filleted so the frame band and the panel read as one surface
// that happens to bulge where the content is.
//
// Three things make that work, and all three matter:
//
//   1. Frame colour, not a surface colour. Any difference at all and the merge
//      becomes a visible seam exactly where the eye is drawn.
//   2. Flush to the edge — it extends past the frame's inner line to the screen
//      edge, so there is no band of wallpaper between panel and frame.
//   3. Inverse corners at the junctions. Where the panel's side meets the frame
//      band the filled region turns through 270°, and without a fillet that
//      reads as two overlapping rectangles. See ./InverseCorner.qml.
//
// Only the inward corners are rounded; the two at the screen edge are square,
// because they are not corners of anything — they are the middle of the frame.
//
// ## The animation
//
// It EXTRUDES. The panel's depth animates from nothing to full while the frame
// stays exactly where it is, so the border appears to stretch outward and the
// contents ride out on the moving edge, like a drawer.
//
// It deliberately does not fade or fly in. Both make it a separate object that
// arrived from somewhere, which is the opposite of the thing the fillets exist
// to sell — and a fade is worse still, because a half-transparent panel over a
// wallpaper shows the border straight through the merge that is supposed to be
// seamless.
//
// The fillets grow with it. At rest there is nothing protruding and therefore
// nothing to fillet; at full extension they are full size. Holding them at full
// size throughout would leave two nubs sticking out of the border before the
// panel had emerged at all.

Item {
    id: root

    // Which screen edge this grows from: "bottom" | "top" | "left" | "right".
    property string edge: "bottom"
    property bool open: false

    // contentWidth runs ALONG the docked edge; contentHeight is the depth away
    // from it. Naming is by the horizontal case and holds for the vertical one.
    property int contentWidth: 400
    property int contentHeight: 300

    property int radius: Appearance.rounding.large
    property color surface: Theme.frame

    // How far the fillet reaches along the frame. Matching the panel's own
    // rounding keeps one curvature across the whole silhouette.
    property int fillet: radius

    property int padding: Appearance.padding.lg

    readonly property int frameThickness: Config.border.thickness
    readonly property bool horizontal: edge === "bottom" || edge === "top"

    default property alias content: inner.data

    // 0 = retracted flush into the frame, 1 = fully extended. Not readonly: a
    // Behavior animates writes, and a read-only property is only ever
    // re-evaluated, so attaching one to it is a load-time error.
    property real progress: open ? 1 : 0

    Behavior on progress {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    readonly property int extension: Math.round(contentHeight * progress)

    // Hidden only once fully retracted, so the closing animation runs to the end
    // instead of the panel vanishing the instant `open` goes false.
    visible: extension > 0

    implicitWidth: horizontal ? contentWidth : frameThickness + extension
    implicitHeight: horizontal ? frameThickness + extension : contentWidth

    // Nothing protrudes at rest, so there is nothing to fillet.
    readonly property int activeFillet: Math.min(fillet, extension)

    // Fillets sit outside the panel's own bounds, in the notch beside it.
    clip: false

    // --- Body and content ---------------------------------------------------
    //
    // Clipped, so content that has not emerged yet is hidden rather than
    // spilling over the wallpaper. The fillets are OUTSIDE this deliberately —
    // they live in the notch beside the panel, which clipping would cut off.
    Item {
        id: clipper

        anchors.fill: parent
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: root.surface
        }

        // Qt rounds all four corners or none, so the pair at the screen edge is
        // squared off by a second rectangle over the outer strip. Cheaper and
        // more predictable than a hand-built path, and invisible because both
        // are the same colour.
        Rectangle {
            color: root.surface
            visible: root.horizontal
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: root.edge === "top" ? parent.top : undefined
            anchors.bottom: root.edge === "bottom" ? parent.bottom : undefined
            height: root.horizontal ? root.radius : 0
        }

        Rectangle {
            color: root.surface
            visible: !root.horizontal
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: root.edge === "left" ? parent.left : undefined
            anchors.right: root.edge === "right" ? parent.right : undefined
            width: root.horizontal ? 0 : root.radius
        }

        // Full size at all times, pinned to the INWARD edge — the one that
        // moves. That is what makes the contents ride out with the panel
        // instead of being squashed into whatever height it currently has, which
        // would reflow the layout on every animation frame.
        Item {
            id: inner

            width: root.horizontal ? clipper.width - root.padding * 2 : root.contentHeight - root.padding * 2
            height: root.horizontal ? root.contentHeight - root.padding * 2 : clipper.height - root.padding * 2

            x: root.edge === "right" ? root.padding : root.horizontal ? root.padding : clipper.width - width - root.padding
            y: root.edge === "bottom" ? root.padding : root.horizontal ? clipper.height - height - root.padding : root.padding
        }
    }

    // --- Junction fillets ---------------------------------------------------
    //
    // One in each notch beside the panel, at the frame's inner line.
    //
    // The corner named is the quarter-disc that gets REMOVED, not the corner the
    // fillet occupies — those are opposites, and conflating them rotates every
    // fillet by 180° and leaves the 90° step it was meant to smooth. The filled
    // quadrant is always the one touching BOTH the panel and the frame band, so
    // the removed one is always diagonally opposite that.
    //
    // Bottom-docked, left notch: the panel is to the right and the frame is
    // below, so the fill hugs bottom-right and the disc comes out of top-left.

    // Horizontal edges: a fillet either side of the panel.
    InverseCorner {
        visible: root.horizontal && root.activeFillet > 0
        size: root.activeFillet
        color: root.surface
        corner: root.edge === "bottom" ? "topLeft" : "bottomLeft"

        x: -root.activeFillet
        y: root.edge === "bottom" ? root.height - root.frameThickness - root.activeFillet : root.frameThickness
    }

    InverseCorner {
        visible: root.horizontal && root.activeFillet > 0
        size: root.activeFillet
        color: root.surface
        corner: root.edge === "bottom" ? "topRight" : "bottomRight"

        x: root.width
        y: root.edge === "bottom" ? root.height - root.frameThickness - root.activeFillet : root.frameThickness
    }

    // Vertical edges: a fillet above and below.
    InverseCorner {
        visible: !root.horizontal && root.activeFillet > 0
        size: root.activeFillet
        color: root.surface
        corner: root.edge === "right" ? "topLeft" : "topRight"

        y: -root.activeFillet
        x: root.edge === "right" ? root.width - root.frameThickness - root.activeFillet : root.frameThickness
    }

    InverseCorner {
        visible: !root.horizontal && root.activeFillet > 0
        size: root.activeFillet
        color: root.surface
        corner: root.edge === "right" ? "bottomLeft" : "bottomRight"

        y: root.height
        x: root.edge === "right" ? root.width - root.frameThickness - root.activeFillet : root.frameThickness
    }
}
