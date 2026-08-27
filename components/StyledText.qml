import QtQuick
import qs.config

// Body text. Exists so no module has to remember the family, and so a font-scale
// change lands everywhere at once.

Text {
    id: root

    property bool mono: false

    font.family: root.mono ? Appearance.font.family.mono : Appearance.font.family.sans
    font.pixelSize: Appearance.font.size.sm
    color: Theme.text

    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    renderType: Text.NativeRendering

    Behavior on color {
        enabled: Appearance.anim.enabled
        ColorAnimation {
            duration: Appearance.anim.fast
        }
    }
}
