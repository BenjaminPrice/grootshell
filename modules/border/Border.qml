import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// The frame.
//
// This is the piece the whole composition hangs off. It draws a solid band
// around the screen edge with rounded inner corners, and every panel docks to
// its inner edge — so panels read as growing out of the frame rather than
// floating above the desktop.
//
// Drawn as a single filled shape with an inner rounded rectangle subtracted from
// an outer plain one, rather than as four rectangles plus corner pieces. Four
// rectangles cannot produce a concave rounded corner, and faking it with rotated
// quarter-circles leaves seams that show up as a hairline against a bright
// wallpaper.
//
// Thickness must match gaps_out in the nixos repo's hyprland.lua. If it does
// not, tiled windows either slide under the frame or leave a dead gap inside it.

Item {
    id: root

    readonly property int thickness: Config.border.thickness
    readonly property int rounding: Config.border.rounding

    // Game mode collapses the frame to nothing. It is chrome, and during a game
    // chrome is bandwidth spent on something nobody is looking at.
    readonly property int effectiveThickness: GameMode.enabled ? 0 : thickness

    Behavior on effectiveThickness {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    visible: effectiveThickness > 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // The frame is static geometry; re-tessellating it every frame is waste
        // on a host that pays for frames twice.
        asynchronous: false

        ShapePath {
            fillColor: Theme.background
            strokeWidth: 0
            fillRule: ShapePath.OddEvenFill

            // Outer boundary: the screen.
            PathMove {
                x: 0
                y: 0
            }
            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }

            // Inner boundary: the rounded cutout. OddEvenFill turns this second
            // closed subpath into a hole rather than more fill.
            PathMove {
                x: root.effectiveThickness + root.rounding
                y: root.effectiveThickness
            }
            PathLine {
                x: root.width - root.effectiveThickness - root.rounding
                y: root.effectiveThickness
            }
            PathArc {
                x: root.width - root.effectiveThickness
                y: root.effectiveThickness + root.rounding
                radiusX: root.rounding
                radiusY: root.rounding
                direction: PathArc.Clockwise
            }
            PathLine {
                x: root.width - root.effectiveThickness
                y: root.height - root.effectiveThickness - root.rounding
            }
            PathArc {
                x: root.width - root.effectiveThickness - root.rounding
                y: root.height - root.effectiveThickness
                radiusX: root.rounding
                radiusY: root.rounding
                direction: PathArc.Clockwise
            }
            PathLine {
                x: root.effectiveThickness + root.rounding
                y: root.height - root.effectiveThickness
            }
            PathArc {
                x: root.effectiveThickness
                y: root.height - root.effectiveThickness - root.rounding
                radiusX: root.rounding
                radiusY: root.rounding
                direction: PathArc.Clockwise
            }
            PathLine {
                x: root.effectiveThickness
                y: root.effectiveThickness + root.rounding
            }
            PathArc {
                x: root.effectiveThickness + root.rounding
                y: root.effectiveThickness
                radiusX: root.rounding
                radiusY: root.rounding
                direction: PathArc.Clockwise
            }
        }
    }
}
