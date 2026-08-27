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

    // `span` runs ALONG the docked edge; `depth` is the distance away from it.
    // Named that way rather than width/height because for a left- or
    // right-docked panel the width IS the depth, and a property called
    // span that means vertical extent is a mistake waiting to be made.
    property int span: 400
    property int depth: 300

    property int radius: Appearance.rounding.large
    property color surface: Theme.frame

    // How far the fillet reaches along the frame. Matching the panel's own
    // rounding keeps one curvature across the whole silhouette.
    property int fillet: radius

    property int padding: Appearance.padding.lg

    // A docked panel usually merges with one band — the one it grows from. But
    // it can be flush against a PERPENDICULAR band as well: the toasts grow from
    // the right border while their top edge also meets the bar.
    //
    // "start" is the top for a left/right panel and the left for a top/bottom
    // one; "end" is the opposite. Setting these squares off the corners on that
    // side and moves that side's fillet to the new junction, since the old notch
    // no longer exists — the abutting band fills it.
    property bool abutsStart: false
    property bool abutsEnd: false

    // Depth of the band this merges into, and therefore how far it overlaps
    // that band and where the fillets sit. Defaults to the border, but not every
    // docked panel grows from the screen edge — the island grows from the bottom
    // of the bar, which is already frame-coloured, so it overlaps nothing and
    // sets this to 0.
    property int frameThickness: Config.border.thickness
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

    readonly property int extension: Math.round(depth * progress)

    // Visible the moment it starts opening, and until it has finished closing.
    //
    // `extension > 0` alone was not enough: extension animates up from zero, so
    // on the frame `open` flips there is nothing on screen yet — and an
    // invisible item cannot take active focus, which silently broke keyboard
    // navigation in any panel that grabs focus on open.
    visible: open || extension > 0

    implicitWidth: horizontal ? span : frameThickness + extension
    implicitHeight: horizontal ? frameThickness + extension : span

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

        // Abutted sides are squared off too: a rounded corner against a band
        // that is flush with it would leave a notch of wallpaper in the join.
        Rectangle {
            color: root.surface
            visible: root.abutsStart
            anchors.left: parent.left
            anchors.right: root.horizontal ? undefined : parent.right
            anchors.top: parent.top
            anchors.bottom: root.horizontal ? parent.bottom : undefined
            width: root.horizontal ? root.radius : 0
            height: root.horizontal ? 0 : root.radius
        }

        Rectangle {
            color: root.surface
            visible: root.abutsEnd
            anchors.right: parent.right
            anchors.left: root.horizontal ? undefined : parent.left
            anchors.bottom: parent.bottom
            anchors.top: root.horizontal ? parent.top : undefined
            width: root.horizontal ? root.radius : 0
            height: root.horizontal ? 0 : root.radius
        }

        // Full size at all times, pinned to the INWARD edge — the one that
        // moves. That is what makes the contents ride out with the panel
        // instead of being squashed into whatever height it currently has, which
        // would reflow the layout on every animation frame.
        Item {
            id: inner

            width: root.horizontal ? clipper.width - root.padding * 2 : root.depth - root.padding * 2
            height: root.horizontal ? root.depth - root.padding * 2 : clipper.height - root.padding * 2

            x: root.edge === "right" ? root.padding : root.horizontal ? root.padding : clipper.width - width - root.padding
            y: root.edge === "bottom" ? root.padding : root.horizontal ? clipper.height - height - root.padding : root.padding
        }
    }

    // --- Junction fillets ---------------------------------------------------
    //
    // One per side. The corner named is the quarter-disc that gets REMOVED, not
    // the corner the fillet occupies — those are opposites, and conflating them
    // rotates every fillet by 180° and leaves the 90° step it was meant to
    // smooth. The filled quadrant is always the one touching BOTH filled regions
    // at that junction, so the removed one is diagonally opposite it.
    //
    // Each side has two cases. Normally the notch is between the panel and the
    // band it grew from, out near the screen edge. When that side abuts a
    // perpendicular band, that notch is filled by the band itself and the
    // junction moves to the panel's inward corner instead.

    function filletGeometry(atStart: bool): var {
        const f = root.activeFillet;
        const abuts = atStart ? root.abutsStart : root.abutsEnd;

        if (root.edge === "right") {
            if (abuts)
                return atStart ? { x: -f, y: 0, corner: "bottomLeft" } : { x: -f, y: root.height - f, corner: "topLeft" };
            return atStart ? { x: root.width - root.frameThickness - f, y: -f, corner: "topLeft" } : { x: root.width - root.frameThickness - f, y: root.height, corner: "bottomLeft" };
        }

        if (root.edge === "left") {
            if (abuts)
                return atStart ? { x: root.width, y: 0, corner: "bottomRight" } : { x: root.width, y: root.height - f, corner: "topRight" };
            return atStart ? { x: root.frameThickness, y: -f, corner: "topRight" } : { x: root.frameThickness, y: root.height, corner: "bottomRight" };
        }

        if (root.edge === "bottom") {
            if (abuts)
                return atStart ? { x: 0, y: -f, corner: "topRight" } : { x: root.width - f, y: -f, corner: "topLeft" };
            return atStart ? { x: -f, y: root.height - root.frameThickness - f, corner: "topLeft" } : { x: root.width, y: root.height - root.frameThickness - f, corner: "topRight" };
        }

        // top
        if (abuts)
            return atStart ? { x: 0, y: root.height, corner: "bottomRight" } : { x: root.width - f, y: root.height, corner: "bottomLeft" };
        return atStart ? { x: -f, y: root.frameThickness, corner: "bottomLeft" } : { x: root.width, y: root.frameThickness, corner: "bottomRight" };
    }

    InverseCorner {
        readonly property var geometry: root.filletGeometry(true)

        visible: root.activeFillet > 0
        size: root.activeFillet
        color: root.surface
        corner: geometry.corner
        x: geometry.x
        y: geometry.y
    }

    InverseCorner {
        readonly property var geometry: root.filletGeometry(false)

        visible: root.activeFillet > 0
        size: root.activeFillet
        color: root.surface
        corner: geometry.corner
        x: geometry.x
        y: geometry.y
    }
}
