import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// Whatever is playing. Defaults to YouTube Music rather than Spotify — see
// Config.services.preferredPlayers and the selection rules in services/Players.qml.

Item {
    id: root

    // Keys the media tab claims. Returns true when it consumed one.
    //
    // Space is play/pause with something loaded and "start the player" without,
    // which is the same intent either way: the button under your thumb should
    // make music happen. n and p rather than the arrow keys — those belong to
    // the island for moving between tabs, and a transport that stole them would
    // trap you on this one.
    function handleKey(event): bool {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (Players.hasActive)
                Players.playPause();
            else
                root.launchDefault();
            return true;
        case Qt.Key_N:
            Players.next();
            return true;
        case Qt.Key_P:
            Players.previous();
            return true;
        }
        return false;
    }

    // Prefers the .desktop entry so the app starts with whatever environment
    // its packager intended, and falls back to the bare command for anything
    // with no entry to find. Through Apps.launch either way, so it survives the
    // shell restarting — the dev loop does that constantly and killing the music
    // with it would be its own small tragedy.
    function launchApp(app): void {
        const names = app?.names ?? [];
        for (let i = 0; i < names.length; i++) {
            let entry = null;
            try {
                entry = DesktopEntries.heuristicLookup(String(names[i]));
            } catch (e) {}
            if (entry) {
                Apps.launchEntry(entry);
                return;
            }
        }
        if (app?.command)
            Apps.launch(app.command);
    }

    // The default is the first configured app — what Space reaches, and what the
    // open button falls back to when nothing is playing to raise.
    function launchDefault(): void {
        const apps = Config.services.mediaApps ?? [];
        if (apps.length > 0)
            root.launchApp(apps[0]);
    }

    // --- Nothing playing ----------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.sm
        visible: !Players.hasActive

        Icon {
            Layout.alignment: Qt.AlignHCenter
            text: "music_off"
            color: Theme.textMuted
            size: Appearance.font.size.xxl
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Nothing playing"
            color: Theme.textMuted
        }

        // One button per configured app, because there is more than one thing
        // "play something" could mean now. The first is styled as the default;
        // the rest are outlined, so the row reads as a primary choice with
        // alternatives rather than as a set of equals.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.spacing.sm
            spacing: Appearance.spacing.sm

            Repeater {
                model: Config.services.mediaApps ?? []

                delegate: Rectangle {
                    id: launchButton

                    required property var modelData
                    required property int index

                    readonly property bool isDefault: index === 0

                    implicitWidth: launchRow.implicitWidth + Appearance.padding.lg * 2
                    implicitHeight: launchRow.implicitHeight + Appearance.padding.sm * 2
                    radius: Appearance.rounding.full
                    color: launchButton.isDefault ? (launchHover.containsMouse ? Theme.accent : Theme.accentContainer) : (launchHover.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                    border.width: launchButton.isDefault ? 0 : 1
                    border.color: Theme.outlineVariant

                    readonly property color ink: launchButton.isDefault ? (launchHover.containsMouse ? Theme.onAccent : Theme.onAccentContainer) : Theme.textSecondary

                    RowLayout {
                        id: launchRow
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.xs

                        Icon {
                            text: launchButton.modelData.icon ?? "play_circle"
                            color: launchButton.ink
                            size: Appearance.font.size.md
                        }

                        StyledText {
                            text: launchButton.modelData.label ?? ""
                            color: launchButton.ink
                            font.pixelSize: Appearance.font.size.xs
                        }
                    }

                    MouseArea {
                        id: launchHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchApp(launchButton.modelData)
                    }
                }
            }
        }
    }

    // --- Playing ------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.lg
        visible: Players.hasActive

        // Album art. Fixed square so the layout does not jump between tracks
        // with different aspect ratios.
        Rectangle {
            Layout.preferredWidth: 128
            Layout.preferredHeight: 128
            Layout.alignment: Qt.AlignVCenter
            radius: Appearance.rounding.normal
            color: Theme.surfaceContainerHigh
            clip: true

            Image {
                anchors.fill: parent
                source: Players.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 256
                sourceSize.height: 256
                visible: status === Image.Ready
            }

            Icon {
                anchors.centerIn: parent
                text: "album"
                color: Theme.textMuted
                size: Appearance.font.size.xxl
                visible: Players.artUrl === ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.spacing.xs

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.sm

                StyledText {
                    Layout.fillWidth: true
                    text: Players.title
                    font.pixelSize: Appearance.font.size.lg
                    color: Theme.text
                    elide: Text.ElideRight
                }

                // Raises the player's own window. Small and unlabelled here,
                // unlike the buttons in the empty state: with something already
                // playing this is a way back to the app, not the main thing you
                // came to the tab to do.
                //
                // Asks MPRIS to raise the app that is actually playing, rather
                // than launching whichever one the shell would have picked —
                // with two media apps configured those are no longer the same
                // thing. Falls back to launching only if the player says it
                // cannot be raised.
                Icon {
                    text: "open_in_new"
                    color: openHover.containsMouse ? Theme.accent : Theme.textMuted
                    size: Appearance.font.size.md

                    MouseArea {
                        id: openHover
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!Players.raise())
                                root.launchDefault();
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Players.artist
                color: Theme.textSecondary
            }

            StyledText {
                Layout.fillWidth: true
                text: Players.album
                color: Theme.textMuted
                font.pixelSize: Appearance.font.size.xs
                visible: Players.album !== "" && Players.album !== Players.title
            }

            Item {
                Layout.fillHeight: true
            }

            // --- Progress ---------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Theme.surfaceContainerHighest
                visible: Players.length > 0

                Rectangle {
                    width: parent.width * Players.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent

                    // No Behavior: position updates once a second, and easing
                    // between two one-second-apart samples makes the bar lag
                    // visibly behind the audio.
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (Players.active?.canSeek)
                            Players.active.position = (mouse.x / width) * Players.length;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Players.length > 0

                StyledText {
                    text: Players.formatTime(Players.position)
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                    mono: true
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: Players.formatTime(Players.length)
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                    mono: true
                }
            }

            // --- Transport --------------------------------------------------
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Appearance.spacing.md

                Control {
                    icon: "skip_previous"
                    interactive: Players.active?.canGoPrevious ?? false
                    onActivated: Players.previous()
                }

                Control {
                    icon: Players.playing ? "pause" : "play_arrow"
                    primary: true
                    interactive: Players.active?.canTogglePlaying ?? false
                    onActivated: Players.playPause()
                }

                Control {
                    icon: "skip_next"
                    interactive: Players.active?.canGoNext ?? false
                    onActivated: Players.next()
                }
            }
        }
    }

    component Control: Rectangle {
        id: control

        property string icon
        property bool primary: false
        property bool interactive: true

        signal activated

        implicitWidth: primary ? 44 : 34
        implicitHeight: implicitWidth
        radius: width / 2
        color: primary ? Theme.accentContainer : hover.containsMouse ? Theme.surfaceContainerHigh : "transparent"
        opacity: interactive ? 1 : 0.35

        Behavior on color {
            enabled: Appearance.anim.enabled
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        Icon {
            anchors.centerIn: parent
            text: control.icon
            filled: true
            color: control.primary ? Theme.onAccentContainer : Theme.text
            size: control.primary ? Appearance.font.size.lg : Appearance.font.size.md
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: control.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: control.activated()
        }
    }
}
