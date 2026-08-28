import QtQuick
import qs.config

// Body text. Exists so no module has to remember the family, and so a font-scale
// change lands everywhere at once.
//
// linkColor is set here rather than per use because Text's default is a fixed
// blue that knows nothing about the palette. Any text containing markup gets
// rendered as rich text by AutoText — a calendar description from Google is
// HTML, so its links came out in that blue against a wallpaper-derived dark
// background and could not be read.

Text {
    id: root

    property bool mono: false

    font.family: root.mono ? Appearance.font.family.mono : Appearance.font.family.sans
    font.pixelSize: Appearance.font.size.sm
    color: Theme.text
    linkColor: Theme.accent

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
