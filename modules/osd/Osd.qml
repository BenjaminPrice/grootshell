import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Volume feedback on the right edge.
//
// Still driven by PipeWire rather than by the shell: the volume keys run `wpctl`
// directly (see keybinds.nix in the nixos repo) and this appears because the
// server changed, not because anything called in. Volume keeps working when the
// shell is dead.
//
// Shown three ways: transiently when the volume actually changes, while the
// pointer is on the right border beside it, and pinned open by the bar's volume
// icon. The transient case takes NO pointer input — it appears where a pointer
// might be doing something else and stealing that click would be rude. Only the
// trigger strip on the border itself is permanently live, and it is as narrow as
// the border it sits on.

Item {
    id: root

    readonly property int inset: Config.border.thickness

    // Raised by a volume change and dropped by the timer below.
    property bool transient: false
    property bool micMode: false

    readonly property bool hovering: edgeZone.containsMouse || bodyHover.containsMouse
    readonly property bool showing: root.transient || ShellState.volume || root.hovering || linger.running

    // What shell.qml puts in the input mask. The trigger strip is always live;
    // the body only once something has deliberately opened it, so a readout that
    // flashed up from a keypress never swallows a click.
    readonly property alias trigger: edgeZone
    readonly property bool wantsInput: !GameMode.enabled && (ShellState.volume || root.hovering || linger.running)

    implicitWidth: 56 + inset
    implicitHeight: 200

    // The ROOT stays visible whenever the shell is not in game mode, and only
    // the readout inside it comes and goes. The trigger strip is a child, and an
    // invisible item receives no hover — binding this to `showing` would have
    // meant hovering the edge could never be what opens it.
    visible: !GameMode.enabled

    Connections {
        target: Volume
        function onChanged(isMic: bool): void {
            root.micMode = isMic;
            root.transient = true;
            hide.restart();
        }
    }

    Timer {
        id: hide
        interval: Config.osd.timeout
        onTriggered: root.transient = false
    }

    // Keeps the panel up for a moment after the pointer leaves. Without it,
    // crossing the gap from the trigger strip to the body closes the thing you
    // are reaching for: the body is only in the input mask once open, so there
    // is a frame where neither contains the pointer.
    Timer {
        id: linger
        interval: 400
    }

    onHoveringChanged: {
        if (root.hovering)
            linger.stop();
        else
            linger.restart();
    }

    // The trigger. On the border, spanning exactly the height of the readout it
    // opens — "the right edge, beside the volume control" is the whole gesture,
    // so it should not be findable anywhere else on that edge.
    MouseArea {
        id: edgeZone

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.inset + 4
        height: parent.height
        hoverEnabled: true
        // Hover only. This strip is live whenever the shell is, and it sits on
        // the border where a window's resize edge is — taking a button here
        // would quietly break dragging that edge.
        acceptedButtons: Qt.NoButton
        enabled: !GameMode.enabled
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: root.inset
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: parent.height
        radius: Appearance.rounding.large

        opacity: root.showing ? 1 : 0
        // Driven by the animated opacity rather than by `showing` directly, so
        // the fade out plays to the end instead of being cut off at the frame
        // the value changes.
        visible: opacity > 0

        Behavior on opacity {
            enabled: Appearance.anim.enabled
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
        color: Theme.layer(2)
        border.width: 1
        border.color: Theme.outlineVariant

        // Sustains the hover once the pointer has crossed onto the body, and
        // nothing else — this is a readout, and the volume keys remain the way
        // volume is set. No buttons, so it cannot swallow a click either.
        MouseArea {
            id: bodyHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.sm
            spacing: Appearance.spacing.sm

            // Fill rises from the bottom, which is the direction the value moves.
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Theme.surfaceContainerHighest
                clip: true

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * (root.micMode ? Volume.micVolume : Volume.volume)
                    radius: parent.radius
                    color: (root.micMode ? Volume.micMuted : Volume.muted) ? Theme.textMuted : Theme.accent

                    Behavior on height {
                        enabled: Appearance.anim.enabled
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }

            Icon {
                Layout.alignment: Qt.AlignHCenter
                text: root.micMode ? (Volume.micMuted ? "mic_off" : "mic") : Volume.icon()
                color: Theme.text
                size: Appearance.font.size.lg
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: `${Math.round((root.micMode ? Volume.micVolume : Volume.volume) * 100)}`
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }
        }
    }
}
