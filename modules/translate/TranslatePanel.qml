import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Translation, pulled out of the left border.
//
// This was a "sidebar" with a pane switcher, on the assumption that AI chat and
// messaging panes would join it. They are not going to — an agent protocol
// against a subscription is a different shape of thing, and messaging apps have
// their own windows. What is left is one tool, so it is named for that instead
// of for a container it does not need.
//
// Half height and vertically centred rather than filling the edge: a translation
// box is a small amount of text in and a small amount out, and a full-height
// panel to hold two paragraphs reads as something that failed to load.

DockedPanel {
    id: root

    edge: "left"
    open: ShellState.translate

    depth: Math.round(400 * Appearance.font.scale)

    // Half the usable height, which is the screen less the bar and the bottom
    // border.
    span: Math.round(((parent?.height ?? 1080) - Config.bar.height - Config.border.thickness * 2) * 0.5)

    Translator {
        anchors.fill: parent
        active: root.open
    }
}
