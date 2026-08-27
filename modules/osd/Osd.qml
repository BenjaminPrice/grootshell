import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Volume feedback on the right edge.
//
// Purely an observer. The volume keys run `wpctl` directly (see keybinds.nix in
// the nixos repo) and this appears because PipeWire changed, not because
// anything called into the shell. That means volume still works when the shell
// is dead, and this is a readout rather than a control surface — which is also
// why it is absent from the input mask in shell.qml. It appears exactly where a
// pointer might be doing something else, and stealing that click would be rude.

Item {
    id: root

    readonly property int inset: Config.border.thickness

    property bool showing: false
    property bool micMode: false

    implicitWidth: 56 + inset
    implicitHeight: 200
    visible: showing && !GameMode.enabled
    opacity: showing ? 1 : 0

    Behavior on opacity {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.fast
        }
    }

    Connections {
        target: Audio
        function onChanged(isMic: bool): void {
            root.micMode = isMic;
            root.showing = true;
            hide.restart();
        }
    }

    Timer {
        id: hide
        interval: Config.osd.timeout
        onTriggered: root.showing = false
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: root.inset
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: parent.height
        radius: Appearance.rounding.large
        color: Theme.layer(2)
        border.width: 1
        border.color: Theme.outlineVariant

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
                    height: parent.height * (root.micMode ? Audio.micVolume : Audio.volume)
                    radius: parent.radius
                    color: (root.micMode ? Audio.micMuted : Audio.muted) ? Theme.textMuted : Theme.accent

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
                text: root.micMode ? (Audio.micMuted ? "mic_off" : "mic") : Audio.icon()
                color: Theme.text
                size: Appearance.font.size.lg
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: `${Math.round((root.micMode ? Audio.micVolume : Audio.volume) * 100)}`
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
                mono: true
            }
        }
    }
}
