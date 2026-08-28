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

            onStatusChanged: {
                if (status === Image.Ready)
                    fade.restart();
            }

            NumberAnimation {
                id: fade
                target: front
                property: "opacity"
                from: 0
                to: 1
                // The same length as the palette cross-fade in config/Theme.qml.
                // The two are not simultaneous — matugen runs after the image is
                // already on screen — but giving them the same duration makes
                // them read as one gesture in two parts rather than as an image
                // change followed by an unrelated colour change.
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
