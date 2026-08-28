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
// Shown two ways: briefly whenever the level or the mute state actually changes
// — which is how the bar's volume icon surfaces it, since that toggles mute and
// the change comes back through PipeWire like any other — and for as long as the
// pointer is on the right border beside it.
//
// A DockedPanel like every other panel, so it extrudes from the border with the
// same inverted corners rather than floating next to it as a separate card. It
// docks mid-edge and abuts nothing, so both of its inward corners get fillets —
// the launcher and the notification centre each abut something and only get one.

Item {
    id: root

    // Raised by a volume change and dropped by the timer below.
    //
    // Named `flash` and not `transient`: that is a reserved word in QML and a
    // property cannot take it. It parses cleanly and fails at load, which is the
    // exact shape of mistake scripts/qml-audit.py exists to catch.
    property bool flash: false
    property bool micMode: false

    readonly property bool hovering: edgeZone.containsMouse || bodyHover.containsMouse
    readonly property bool showing: root.flash || root.hovering || linger.running

    // What shell.qml puts in the input mask. The trigger strip is always live;
    // the body only while the pointer is actually on it, so a readout that
    // flashed up from a keypress never swallows a click.
    readonly property alias trigger: edgeZone
    readonly property bool wantsInput: !GameMode.enabled && (root.hovering || linger.running)

    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    // The ROOT stays visible whenever the shell is not in game mode, and only
    // the panel inside it comes and goes. The trigger strip is a child, and an
    // invisible item receives no hover — binding this to `showing` would have
    // meant hovering the edge could never be what opens it.
    visible: !GameMode.enabled

    Connections {
        target: Volume
        function onChanged(isMic: bool): void {
            root.micMode = isMic;
            root.flash = true;
            hide.restart();
        }
    }

    Timer {
        id: hide
        interval: Config.osd.timeout
        onTriggered: root.flash = false
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

    DockedPanel {
        id: panel

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        edge: "right"
        open: root.showing

        span: 200
        depth: 56
        // Tighter than the default: at this depth the standard padding would
        // leave the level bar a few pixels wide.
        padding: Appearance.padding.sm

        // Sustains the hover once the pointer has crossed onto the body, and
        // nothing else. Declared BEFORE the content above so it sits underneath
        // the mute button — and NoButton besides, so a press falls through to
        // whatever is under it rather than being swallowed here.
        MouseArea {
            id: bodyHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            anchors.fill: parent
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
                    height: parent.height * (root.micMode ? Volume.micLevel : Volume.level)
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

            // Clicking it mutes, matching the tray icon. The mic and the sink
            // are separate mutes and this follows whichever the readout is
            // currently showing, so the button always means the thing on screen.
            Icon {
                id: muteButton

                Layout.alignment: Qt.AlignHCenter
                text: root.micMode ? (Volume.micMuted ? "mic_off" : "mic") : Volume.icon()
                color: (root.micMode ? Volume.micMuted : Volume.muted) ? Theme.error : Theme.text
                size: Appearance.font.size.lg

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.micMode)
                            Volume.toggleMicMute();
                        else
                            Volume.toggleMute();
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: `${Math.round((root.micMode ? Volume.micLevel : Volume.level) * 100)}`
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }
        }
    }

    // The trigger. On the border, spanning exactly the height of the readout it
    // opens — "the right edge, beside the volume control" is the whole gesture,
    // so it should not be findable anywhere else on that edge.
    //
    // Declared after the panel so it stays on top as the panel extrudes past it.
    MouseArea {
        id: edgeZone

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Config.border.thickness + 4
        height: panel.span
        hoverEnabled: true
        // Hover only. This strip is live whenever the shell is, and it sits on
        // the border where a window's resize edge is — taking a button here
        // would quietly break dragging that edge.
        acceptedButtons: Qt.NoButton
        enabled: !GameMode.enabled
    }
}
