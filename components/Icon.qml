import QtQuick
import qs.config

// A Material Symbols glyph.
//
// Text, not an image: the font is variable, so weight and optical size are
// properties rather than separate assets, and a glyph recolours by setting
// `color` instead of regenerating anything.

Text {
    id: root

    property real size: Appearance.font.size.md
    property int weight: 400
    property bool filled: false

    font.family: Appearance.font.family.icon
    font.pixelSize: root.size
    // FILL and GRAD are variable axes on Material Symbols. FILL is what turns an
    // outlined glyph into a solid one, which is how "active" reads without
    // needing a second icon name.
    font.variableAxes: ({
            FILL: root.filled ? 1 : 0,
            wght: root.weight,
            GRAD: 0,
            opsz: root.size
        })

    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering

    Behavior on color {
        enabled: Appearance.anim.enabled
        ColorAnimation {
            duration: Appearance.anim.fast
        }
    }
}
