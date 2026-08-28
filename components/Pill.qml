import QtQuick
import QtQuick.Layouts
import qs.config

// One of the floating capsules that make up the top bar.
//
// The bar used to be a solid frame-coloured band across the whole width, which
// made the top of the screen read as 64px of chrome. Pills instead: the border
// stays thin the whole way round, and the bar becomes three small objects
// floating in front of the wallpaper.
//
// Frame-coloured, and not a surface colour, on purpose. These float against the
// wallpaper a few pixels below the frame's top band, and painting them the same
// colour as that band is what makes them read as pieces of the frame that have
// come loose rather than as widgets someone dropped on the desktop.
//
// The hairline outline is what keeps that working over a bright photograph,
// where frame-on-wallpaper can otherwise be nearly no contrast at all.

Rectangle {
    id: root

    // Content is laid out in a row, because every pill in the bar is one.
    default property alias content: inner.data

    property int spacing: Appearance.spacing.md
    property int hpad: Appearance.padding.lg

    implicitWidth: inner.implicitWidth + root.hpad * 2

    // Fixed, not sized to content. A row of capsules whose heights follow their
    // own text is a row of subtly different objects, and the eye reads that as
    // sloppy long before it works out why — the title pill, being text only,
    // came out visibly shorter than the workspace track beside it.
    implicitHeight: Math.round(Config.bar.pillHeight * Appearance.font.scale)

    radius: Appearance.rounding.full
    color: Theme.frame

    border.width: 1
    border.color: Theme.outlineVariant

    RowLayout {
        id: inner
        anchors.centerIn: parent
        spacing: root.spacing
    }
}
