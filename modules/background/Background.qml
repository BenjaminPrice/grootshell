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

    // Start the crossfade once BOTH halves are ready: the image decoded, and the
    // palette for that same image settled. Whichever finishes second calls this,
    // so there is no dependence on which of the two wins — and none on the order
    // the Connections happen to fire in, which QML does not define.
    function fadeWhenReady(): void {
        if (front.status !== Image.Ready)
            return;
        if (Theming.settled !== Wallpapers.current)
            return;
        paletteTimeout.stop();
        fade.restart();
    }

    Connections {
        target: Theming
        function onSettledChanged(): void {
            root.fadeWhenReady();
        }
    }

    Connections {
        target: Wallpapers
        function onCurrentChanged(): void {
            paletteTimeout.restart();
        }
    }

    // Never hold the wallpaper hostage to the generator. If the palette has not
    // settled in this long, show the image anyway and let the colours catch up
    // whenever they arrive — a wallpaper that refuses to change is a worse
    // failure than one that changes out of step, and matugen on a slow machine
    // with a large image is not a fault to punish the user for.
    Timer {
        id: paletteTimeout
        // Measured worst case for the generator is about 1.6 seconds, on a 24MP
        // JPEG. This is a backstop for a generator that is wedged or absent, not
        // a budget for a slow one, so it sits clear of the real numbers.
        interval: 3000
        onTriggered: {
            if (front.status === Image.Ready)
                fade.restart();
        }
    }

    // Two images crossfaded rather than one whose source changes: swapping a
    // source mid-fade shows a frame of nothing while the new file decodes, and
    // at wallpaper resolutions that frame is very visible.
    Item {
        anchors.fill: parent

        Image {
            id: back
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            // Decode at the size we actually draw. Without this a 6000px JPEG is
            // held in memory at full resolution for a 1080p output.
            sourceSize.width: root.screen.width
            sourceSize.height: root.screen.height
        }

        Image {
            id: front
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: root.screen.width
            sourceSize.height: root.screen.height
            opacity: 0

            source: Wallpapers.current ? `file://${Wallpapers.current}` : ""

            // Decoded and waiting for its palette. The image is loaded the
            // instant the wallpaper changes — decoding a large photograph takes
            // a few hundred milliseconds and there is no reason to spend them
            // twice — but it is not shown until the colours are ready to move
            // with it.
            //
            // Measured before this existed: on a 13MB PNG the image finished
            // fading 680ms before the palette even began, so the wallpaper
            // changed, settled, and then the entire shell changed colour around
            // it. Two events where there should be one.
            onStatusChanged: {
                if (status === Image.Ready)
                    root.fadeWhenReady();
            }

            NumberAnimation {
                id: fade
                target: front
                property: "opacity"
                from: 0
                to: 1
                // The same length as the palette cross-fade in config/Theme.qml,
                // and now started at the same moment as it — see fadeWhenReady
                // above. Matching durations was already here; matching start
                // times is what actually made the two read as one gesture.
                duration: Appearance.anim.enabled ? Appearance.anim.theme : 0
                easing.type: Easing.InOutQuad
                onFinished: {
                    // Hand off to the back image and reset, so the next change
                    // has a clean slate to fade in over.
                    back.source = front.source;
                    front.opacity = 0;
                }
            }
        }
    }
}
