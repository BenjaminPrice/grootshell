import QtQuick
import qs.config

// The base every panel is built on: a rounded surface that slides out of the
// screen edge it is anchored to.
//
// Direction matters to the illusion. Panels should look like they are emerging
// from the frame, not fading in on top of it, so the slide always travels along
// the axis of the edge they dock to — the launcher rises from the bottom, the
// sidebar comes in from the left. Setting `edge` is all a module has to do.
//
// `visible` is driven off `open` with a delay on the way out, so the exit
// animation has time to run before the item stops being rendered. Binding
// visible directly to open makes panels vanish instantly and only animate on
// the way in, which reads as broken.

Item {
    id: root

    // "top" | "bottom" | "left" | "right" | "none"
    property string edge: "bottom"
    property bool open: false
    property int radius: Appearance.rounding.large
    property color surface: Theme.layer(1)
    property int slide: 24

    // Content goes here; the panel sizes itself to it.
    default property alias content: inner.data
    property alias padding: inner.anchors.margins

    visible: open || hideDelay.running
    opacity: open ? 1 : 0

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

    // Keeps the item alive just long enough for the closing animation. When
    // animations are off (game mode) there is nothing to wait for.
    Timer {
        id: hideDelay
        interval: Appearance.anim.enabled ? Appearance.anim.normal : 0
    }

    onOpenChanged: if (!open && Appearance.anim.enabled) hideDelay.restart()

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.surface
        border.width: 1
        border.color: Theme.outlineVariant

        Behavior on color {
            enabled: Appearance.anim.enabled
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: Appearance.padding.lg
    }
}
