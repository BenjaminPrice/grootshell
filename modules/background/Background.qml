import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The wallpaper.
//
// Its own layer surface on the Background layer rather than a rectangle inside
// the main overlay, so a fullscreen window covers it exactly the way it covers
// any other window. Painting it into the overlay would put it above the desktop
// but below the shell, which is the wrong side of everything.

PanelWindow {
    id: root

    required property ShellScreen screen

    color: Theme.background

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "grootshell-background"
    // The wallpaper must never take focus; it is the one surface with nothing to
    // interact with.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Two images that swap roles, rather than one whose source changes: changing
    // a source shows a frame of nothing while the new file decodes, and at
    // wallpaper resolutions that frame is very visible.
    //
    // One image is on screen; the other is the staging slot the next wallpaper
    // decodes into. The staging one fades in ON TOP, and only then do the two
    // swap. So the outgoing image is never hidden before its replacement is
    // actually drawn, and no file is ever decoded twice.
    //
    // The version this replaced handed off at the END of the fade: it pointed
    // the back image at the file the front had just finished showing, and hid
    // the front in the same statement. With cache: false that started a second
    // decode of a file already on screen, and hid the copy that was ready in
    // favour of one that was not — leaving a window with nothing drawn at all,
    // through which the layer surface's own background colour showed. Measured
    // at 205ms on a 13MB PNG, arriving exactly as the theme finished landing,
    // which is what made it read as the wallpaper flashing.
    property bool showFirst: true

    readonly property Image visibleLayer: root.showFirst ? first : second
    readonly property Image stagingLayer: root.showFirst ? second : first

    // The screen's LOGICAL size, which is what the wallpaper is decoded at.
    //
    // Mirrored into properties of our own rather than read straight off the
    // screen at the point of use, because a change to it has to be handled
    // rather than merely propagated. See onScreenWidthChanged below.
    readonly property int screenWidth: root.screen.width
    readonly property int screenHeight: root.screen.height

    // Both halves of a load, together: the file and the size to decode it at.
    //
    // sourceSize is set HERE rather than bound on the Image. Bound to the
    // screen — as it was, on both images at once — a resize re-decodes from
    // scratch, and with cache: false that is a fresh read off disk. Assigned to
    // the staging layer only, it becomes just another thing that differs between
    // the outgoing image and the incoming one, no different from the file
    // itself changing, so a resize takes the same crossfade as a new wallpaper.
    //
    // That alone does NOT keep the wallpaper on screen, which is worth being
    // clear about because it looks as though it should. The surface resize costs
    // BOTH images their texture before any of this runs — measured: the flash
    // starts ~24ms after the mode change, long before this fires — so there is
    // no old image left to hold on to. What fills the gap is the thumbnail
    // below; this is what makes the return to full resolution a fade rather than
    // a jump.
    function load(): void {
        paletteTimeout.restart();
        root.stagingLayer.sourceSize = Qt.size(root.screenWidth, root.screenHeight);
        root.stagingLayer.source = Wallpapers.current ? `file://${Wallpapers.current}` : "";
    }

    // A resolution change is a wallpaper change that happens to keep the same
    // file. Sunshine retargets the output on connect and the scaling widget
    // changes the logical size, so this fires in ordinary use rather than only
    // when hardware is plugged in.
    //
    // Debounced only because width and height arrive as two signals for one
    // change, and decoding twice would be wasteful.
    onScreenWidthChanged: resize.restart()
    onScreenHeightChanged: resize.restart()

    Timer {
        id: resize
        // Only long enough to coalesce width and height, which arrive as two
        // signals for one change. NOT a settling delay: the texture is already
        // gone by the time this starts (see the thumbnail below), so every
        // millisecond waited here is a millisecond of not-the-wallpaper.
        interval: 50
        onTriggered: root.load()
    }

    // Start the crossfade once BOTH halves are ready: the image decoded, and the
    // palette for that same image settled. Whichever finishes second calls this,
    // so there is no dependence on which of the two wins — and none on the order
    // the Connections happen to fire in, which QML does not define.
    //
    // Before this, the image landed about a second ahead of its colours on a
    // large file, so a wallpaper change read as two unrelated events.
    function fadeWhenReady(): void {
        if (root.stagingLayer.status !== Image.Ready)
            return;
        if (Theming.settled !== Wallpapers.current)
            return;
        root.startFade();
    }

    function startFade(): void {
        paletteTimeout.stop();
        fade.target = root.stagingLayer;
        fade.restart();
    }

    Component.onCompleted: root.load()

    Connections {
        target: Wallpapers
        function onCurrentChanged(): void {
            root.load();
        }
    }

    Connections {
        target: Theming
        function onSettledChanged(): void {
            root.fadeWhenReady();
        }
    }

    // Never hold the wallpaper hostage to the generator. If the palette has not
    // settled in this long, show the image anyway and let the colours catch up
    // whenever they arrive — a wallpaper that refuses to change is a worse
    // failure than one that changes out of step, and a slow generator is not a
    // fault to punish the user for.
    Timer {
        id: paletteTimeout
        // Measured worst case for the generator is about 1.6 seconds, on a 24MP
        // JPEG, and a cache hit is 46ms. This is a backstop for a generator that
        // is wedged or absent, not a budget for a slow one, so it sits clear of
        // the real numbers.
        interval: 3000
        onTriggered: {
            if (root.stagingLayer.status === Image.Ready)
                root.startFade();
        }
    }

    Item {
        anchors.fill: parent

        // A small copy of the same wallpaper, underneath both layers, whose
        // decode size never changes.
        //
        // Resizing the surface costs both full-size images their texture — not
        // our doing and not avoidable from here; the window keeps rendering, and
        // what shows through is its own `color`, a flat Theme.background where
        // the wallpaper was. Measured at ~250ms of it on a scale change, which
        // is the flash this exists to fill.
        //
        // Nothing here can hold a full-resolution texture across that, so this
        // does the next best thing: it is small enough to come back immediately.
        // 480px wide is about half a megabyte and decodes in single-digit
        // milliseconds, against ~200ms for the real thing, so the gap shows a
        // soft version of the right image instead of a dark rectangle. Stretched
        // over a 4K screen it is visibly blurry, and that is fine — it is on
        // screen for a fifth of a second, and being briefly soft reads as the
        // wallpaper resolving rather than as the wallpaper disappearing.
        //
        // sourceSize is a constant, deliberately: binding it to the screen is
        // exactly the mistake this whole file now avoids, and a fixed decode
        // size means a resize gives it nothing to redo.
        Image {
            id: thumbnail

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // The one image here that IS worth caching. It is tiny, it is wanted
            // again on every resize, and the cost of re-reading it is the gap it
            // exists to close.
            cache: true
            sourceSize.width: 480
            source: Wallpapers.current ? `file://${Wallpapers.current}` : ""

            // Below both layers, so it is only ever seen through them. A
            // wallpaper change points this at the new file at once, while the
            // outgoing full-size image is still opaque on top — so the swap
            // stays a crossfade between the two big layers, and this is not part
            // of it.
            z: -1
        }

        Image {
            id: first

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            // sourceSize is deliberately NOT bound here — root.load() assigns it
            // to the staging layer alone. It still does its original job of
            // decoding at the size we draw rather than holding a 6000px JPEG at
            // full resolution; what it no longer does is discard the image that
            // is currently on screen. See load().

            // Whichever image is staging sits on top, because it is the one that
            // fades in over the other.
            z: root.showFirst ? 0 : 1
            opacity: 1

            onStatusChanged: {
                if (status === Image.Ready && root.stagingLayer === first)
                    root.fadeWhenReady();
            }
        }

        Image {
            id: second

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            // Not bound, for the reason on `first` above.

            z: root.showFirst ? 1 : 0
            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready && root.stagingLayer === second)
                    root.fadeWhenReady();
            }
        }
    }

    NumberAnimation {
        id: fade

        property: "opacity"
        from: 0
        to: 1
        // The same length as the palette cross-fade in config/Theme.qml, and
        // started on the same frame as it — see fadeWhenReady. Matching
        // durations was never the hard part; matching start times was.
        duration: Appearance.anim.enabled ? Appearance.anim.theme : 0
        easing.type: Easing.InOutQuad

        onFinished: {
            // Order matters. The outgoing image is hidden while it is still
            // UNDERNEATH the one that just faded in, so nothing changes on
            // screen; only then do the two swap roles. Swapping first would put
            // a fully opaque outgoing image back on top for a frame.
            root.visibleLayer.opacity = 0;
            root.showFirst = !root.showFirst;
        }
    }
}
