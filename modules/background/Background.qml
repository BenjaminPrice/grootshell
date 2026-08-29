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

    function load(): void {
        root.stagingLayer.source = Wallpapers.current ? `file://${Wallpapers.current}` : "";
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
            paletteTimeout.restart();
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

        Image {
            id: first

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            // Decode at the size we actually draw. Without this a 6000px JPEG is
            // held in memory at full resolution for a 1080p output.
            sourceSize.width: root.screen.width
            sourceSize.height: root.screen.height

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
            sourceSize.width: root.screen.width
            sourceSize.height: root.screen.height

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
