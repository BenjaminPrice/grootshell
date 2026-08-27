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

Item {
    id: root

    // Which screen edge this grows from: "bottom" | "top" | "left" | "right".
    property string edge: "bottom"
    property bool open: false

    // The panel box itself, excluding the frame band it sits over.
    property int contentWidth: 400
    property int contentHeight: 300

    property int radius: Appearance.rounding.large
    property color surface: Theme.frame

    // How far the fillet reaches along the frame. Matching the panel's own
    // rounding keeps one curvature across the whole silhouette.
    property int fillet: radius

    readonly property int frameThickness: Config.border.thickness
    readonly property bool horizontal: edge === "bottom" || edge === "top"

    default property alias content: inner.data
    property int padding: Appearance.padding.lg

    // Overall size includes the frame band, since the panel extends through it
    // to the screen edge.
    implicitWidth: horizontal ? contentWidth : contentHeight + frameThickness
    implicitHeight: horizontal ? contentHeight + frameThickness : contentWidth

    visible: open || hideDelay.running
    opacity: open ? 1 : 0

    // Fillets sit outside the panel's own bounds, in the notch beside it.
    clip: false

    property int slide: 28

    transform: Translate {
        x: root.open ? 0 : (root.edge === "left" ? -root.slide : root.edge === "right" ? root.slide : 0)
        y: root.open ? 0 : (root.edge === "top" ? -root.slide : root.edge === "bottom" ? root.slide : 0)

        Behavior on x {
            enabled: Appearance.anim.enabled
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.emphasised
            }
        }
        Behavior on y {
            enabled: Appearance.anim.enabled
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.emphasised
            }
        }
    }

    Behavior on opacity {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.fast
        }
    }

    // Keeps the item alive just long enough for the closing animation. With
    // animations off (game mode) there is nothing to wait for.
    Timer {
        id: hideDelay
        interval: Appearance.anim.enabled ? Appearance.anim.normal : 0
    }

    onOpenChanged: if (!open && Appearance.anim.enabled) hideDelay.restart()

    // --- The body -----------------------------------------------------------
    //
    // Rounded on the inward side only. Qt rounds all four corners or none, so
    // the two at the screen edge are squared off by a second rectangle covering
    // the outer half — cheaper and more predictable than a hand-built path, and
    // invisible because both are the same colour.
    Rectangle {
        id: body
        anchors.fill: parent
        radius: root.radius
        color: root.surface
    }

    Rectangle {
        color: root.surface

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.edge === "top" ? parent.top : undefined
        anchors.bottom: root.edge === "bottom" ? parent.bottom : undefined
        height: root.horizontal ? root.radius : 0
        visible: root.horizontal
    }

    Rectangle {
        color: root.surface

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.edge === "left" ? parent.left : undefined
        anchors.right: root.edge === "right" ? parent.right : undefined
        width: root.horizontal ? 0 : root.radius
        visible: !root.horizontal
    }

    // --- Junction fillets ---------------------------------------------------
    //
    // Positioned at the frame's inner line, just outside the panel, one at each
    // side. Their removed quarter faces away from the panel so the curve sweeps
    // from the panel's edge out along the frame.
    InverseCorner {
        visible: root.horizontal
        size: root.fillet
        color: root.surface
        corner: root.edge === "bottom" ? "bottomRight" : "topRight"

        x: -root.fillet
        y: root.edge === "bottom" ? root.height - root.frameThickness - root.fillet : root.frameThickness
    }

    InverseCorner {
        visible: root.horizontal
        size: root.fillet
        color: root.surface
        corner: root.edge === "bottom" ? "bottomLeft" : "topLeft"

        x: root.width
        y: root.edge === "bottom" ? root.height - root.frameThickness - root.fillet : root.frameThickness
    }

    InverseCorner {
        visible: !root.horizontal
        size: root.fillet
        color: root.surface
        corner: root.edge === "right" ? "bottomRight" : "bottomLeft"

        y: -root.fillet
        x: root.edge === "right" ? root.width - root.frameThickness - root.fillet : root.frameThickness
    }

    InverseCorner {
        visible: !root.horizontal
        size: root.fillet
        color: root.surface
        corner: root.edge === "right" ? "topRight" : "topLeft"

        y: root.height
        x: root.edge === "right" ? root.width - root.frameThickness - root.fillet : root.frameThickness
    }

    // --- Content ------------------------------------------------------------
    //
    // Inset past the frame band on the docked side, so nothing is laid out in
    // the strip that overlaps the border.
    Item {
        id: inner

        anchors.fill: parent
        anchors.leftMargin: root.padding + (root.edge === "left" ? root.frameThickness : 0)
        anchors.rightMargin: root.padding + (root.edge === "right" ? root.frameThickness : 0)
        anchors.topMargin: root.padding + (root.edge === "top" ? root.frameThickness : 0)
        anchors.bottomMargin: root.padding + (root.edge === "bottom" ? root.frameThickness : 0)
    }
}
