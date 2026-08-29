import Quickshell
import Quickshell.Wayland

// Reserves a strip of screen edge so tiled windows move out of a panel's way.
//
// A layer surface can declare an exclusive zone, and the compositor lays tiled
// windows out around it — which is how the bar already keeps windows from
// opening underneath itself. This does the same for a panel, without the panel
// having to become its own surface.
//
// That separation matters. The panels live together in one fullscreen overlay,
// which is what lets them look like they grow out of the frame: they share a
// scene and a clip with it, so the inverted corners line up. Giving a panel its
// own layer surface to carry a zone would break that. So this is a surface that
// carries NOTHING — one transparent pixel whose only job is the reservation.
//
// The zone is a STRIP along one screen edge, not a rectangle. A panel docked
// half-height on the right reserves the full right edge, top to bottom, and
// nothing can use the space above or below it while it is open. That is the
// protocol, not a shortcut: there is no way to reserve a box.
//
// The motion is the compositor's, not ours. The zone snaps between 0 and its
// full depth, and Hyprland animates the windows to their new geometry — see
// hl.animation in the nixos repo's hyprland.lua, set to the same duration and
// curve as Appearance.anim so the two movements agree. Following the panel's own
// animation frame by frame would instead re-lay-out every window on every frame,
// which on a streamed display costs far more than it buys.

PanelWindow {
    id: root

    required property ShellScreen reservationScreen

    // Which edge to reserve against. Matches DockedPanel's own `edge` values, so
    // a panel can be wired to one of these by passing its property through.
    property string edge: "right"

    // How far to reserve, in pixels away from that edge.
    property int depth: 0

    // Whether to reserve at all right now.
    property bool reserve: false

    screen: root.reservationScreen
    color: "transparent"

    anchors {
        left: root.edge === "left"
        right: root.edge === "right"
        top: root.edge === "top"
        bottom: root.edge === "bottom"
    }

    // One pixel. The zone is set explicitly below, so the surface's own size has
    // nothing to do with how much it reserves — it only has to exist.
    implicitWidth: 1
    implicitHeight: 1

    // Normal, not Auto: Auto derives the zone from the anchored size, which here
    // would reserve exactly one pixel.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.reserve ? root.depth : 0

    // Overlay, and that is about ordering rather than stacking.
    //
    // The compositor walks the layers in order — background, bottom, top,
    // overlay — positioning each surface inside the area left by the ones
    // before it, and subtracting each zone as it goes. On Bottom this was
    // applied BEFORE the bar, which lives on Top, so the bar was inset from the
    // edge along with the windows. Layer-shell offers no way for the bar to
    // reserve its own height while ignoring someone else's zone: exclusiveZone
    // is one number, and -1 means "reserve nothing AND ignore everyone".
    //
    // Above the bar, the bar is placed before this exists and keeps the full
    // width, while the window area — computed after every layer — still shrinks.
    //
    // Being on Overlay costs nothing: one transparent pixel that takes no input.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grootshell-reservation"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Empty mask: no input, ever. Without this the pixel would swallow a click
    // at the screen edge, which is exactly where the OSD's hover trigger lives.
    mask: Region {}
}
