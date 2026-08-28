import QtQuick
import qs.config

// A spectrum ring: bars radiating outward from a circle.
//
// Meant to sit around the album art, which is why it is a ring and not a strip.
// A strip has to go somewhere — under the title, beside the transport — and
// wherever you put it, it is a second rectangle competing with the artwork. A
// ring has no such problem: it belongs to the thing it encircles, and the empty
// space it occupies was already empty.
//
// ## Mirrored, deliberately
//
// cava hands over bands in frequency order, low to high. Wrapping those straight
// around a circle puts the lowest band next to the highest, so the one place the
// ring is guaranteed to be discontinuous is the one place the eye is drawn — the
// top. Mirroring instead: bass at the top, sweeping down BOTH sides to treble at
// the bottom. The ring is then symmetric about the vertical axis, which reads as
// designed rather than as an array that happened to be drawn in a circle.
//
// ## Why bars and not a path
//
// A smooth closed curve through the band values is prettier in a screenshot and
// worse here. It has to be retessellated every frame — thirty times a second, on
// a host that pays for every frame twice, once to draw and once to encode — and
// at the size this is actually viewed the curve reads as a wobbling blob whereas
// discrete bars stay legible.

Item {
    id: root

    // 0..1 per band, low frequency first. Short or empty is fine and is the
    // normal state when nothing is playing.
    property var levels: []

    // Distance from the centre at which the bars START. The artwork sits inside
    // this, with a gap.
    property real innerRadius: 80

    // Bar length at silence and at full scale. The resting length is not zero:
    // a ring that vanishes when the music stops looks like a bug, where a ring
    // of short even ticks looks like an instrument at rest.
    //
    // It has to be long enough to READ as a ring, though. It was not — at rest
    // the bars were barely longer than they were wide, which looked like nothing
    // at all, so a missing visualiser and a silent one were indistinguishable.
    property real minLength: 6
    property real maxLength: 26

    property real barWidth: 4
    property color color: Theme.accent

    // How many bands to expect before any have arrived. Only used to shape the
    // resting ring: without it the ring drew a different NUMBER of bars when
    // idle than when running, so the first frame of audio visibly reshuffled it.
    property int bands: 16

    // Each band appears twice, once down each side.
    readonly property int segments: (root.levels.length > 0 ? root.levels.length : root.bands) * 2

    function lengthAt(index: int): real {
        const bands = root.segments / 2;
        // Fold the segment index back onto a band: 0 at the top, running down
        // to the last band at the bottom, then back up the other side.
        const band = index < bands ? index : root.segments - 1 - index;
        const level = root.levels[band] ?? 0;
        return root.minLength + level * (root.maxLength - root.minLength);
    }

    Repeater {
        model: root.segments

        delegate: Rectangle {
            id: bar

            required property int index

            // Straight up is the top of the ring, so the whole thing is offset
            // by a quarter turn from the maths convention where zero is east.
            readonly property real theta: bar.index * 2 * Math.PI / root.segments - Math.PI / 2

            width: root.barWidth
            height: root.lengthAt(bar.index)
            radius: width / 2
            color: root.color

            // Rotating about the bar's own inner end is what keeps it pointing
            // outward as it grows. With the default centre origin, a bar that
            // got longer would grow in both directions and creep inward over
            // the artwork.
            transformOrigin: Item.Bottom
            rotation: bar.index * 360 / root.segments

            // Placed by its inner end, then rotated into position. The bar
            // points up before rotation, so its inner end is the bottom edge —
            // hence subtracting the full height from y and half the width from x.
            x: root.width / 2 + Math.cos(bar.theta) * root.innerRadius - width / 2
            y: root.height / 2 + Math.sin(bar.theta) * root.innerRadius - height

            // Roughly one cava frame. Long enough to smooth the step between
            // samples into motion, short enough not to lag behind the audio —
            // past about 80ms the ring visibly trails what you are hearing,
            // which is worse than it being slightly jumpy.
            Behavior on height {
                enabled: Appearance.anim.enabled
                NumberAnimation {
                    duration: 40
                }
            }
        }
    }
}
