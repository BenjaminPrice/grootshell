import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services

// One notification. Used by both the toast stack and the notification centre,
// so the two cannot drift into looking like different things.
//
// Collapsed it is a summary and one line of body; expanded it adds the rest of
// the body and whatever actions the sender offered. Expanding rather than always
// showing everything matters because notification bodies are unbounded — a build
// failure will happily send you forty lines, and a stack of those is a wall.
//
// Two ways out, because a notification you cannot get rid of is worse than one
// you never saw: middle-click, or drag it off to the side. Drag is there for the
// pointer-only case, since this host is often driven with a trackpad across a
// network and a middle button is not always available.

Rectangle {
    id: root

    required property var notification
    required property real time

    // The centre lists everything and has room; a toast is transient and should
    // not grow a chevron it will disappear before you can press.
    property bool expandable: true
    property bool expanded: false

    readonly property bool urgent: notification?.urgency === 2
    readonly property var actions: notification?.actions ?? []
    readonly property bool hasActions: actions.length > 0

    // Emitted by the close button and by a completed drag. What it MEANS is the
    // consumer's business: the centre removes the row, a toast dismisses the
    // notification outright — which is what dragging a toast away has always
    // done, so the button matching it keeps one gesture from meaning two things.
    signal discarded

    // Holds expiry while the pointer is over this card. Balanced on destruction
    // because a card can be removed mid-hover — by a drag, by an action, or by
    // the centre being cleared — and an unbalanced increment would freeze every
    // future notification on screen permanently.
    readonly property bool hovered: hover.containsMouse
    onHoveredChanged: Notifs.hovering += hovered ? 1 : -1
    Component.onDestruction: if (hovered) Notifs.hovering -= 1

    implicitHeight: body.implicitHeight + Appearance.padding.md * 2
    radius: Appearance.rounding.normal
    color: hover.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
    border.width: urgent ? 1 : 0
    border.color: Theme.error

    Behavior on color {
        enabled: Appearance.anim.enabled
        ColorAnimation {
            duration: Appearance.anim.fast
        }
    }

    Behavior on implicitHeight {
        enabled: Appearance.anim.enabled
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasised
        }
    }

    // Drag-to-dismiss. Opacity falls off with distance so it is obvious the
    // gesture is doing something before you have committed to it.
    readonly property int dismissAt: width / 3
    opacity: 1 - Math.min(0.75, Math.abs(x) / (width || 1))

    Behavior on x {
        enabled: Appearance.anim.enabled && !hover.drag.active
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutQuad
        }
    }

    // Declared BEFORE the content, and that ordering is load-bearing.
    //
    // Two sibling items at the same z both covering the same pixel: the one
    // declared LATER is on top and gets the event. This used to come last, so it
    // covered the whole card and swallowed every left click before the buttons
    // underneath it saw one — pressing close toggled `expanded` instead of
    // closing, the chevron did nothing, and the action buttons were unreachable.
    // The close icon never even turned red, because its own MouseArea never saw
    // the pointer either.
    //
    // Underneath, it now catches only what the buttons do not: background clicks
    // to expand, middle-click to dismiss, and the drag.
    //
    // The cost is that `containsMouse` goes false while the pointer is precisely
    // over one of those small buttons, which releases the expiry hold. That is
    // harmless and slightly helpful: `running: hovering === 0` restarts the timer
    // rather than resuming it, so aiming at close buys a fresh five seconds
    // instead of racing the old ones.
    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        drag.target: root
        drag.axis: Drag.XAxis
        drag.minimumX: -root.width
        drag.maximumX: root.width

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.discarded();
            else if (root.expandable)
                root.expanded = !root.expanded;
        }

        onReleased: {
            if (Math.abs(root.x) > root.dismissAt)
                root.discarded();
            else
                root.x = 0;
        }
    }

    RowLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.md
        spacing: Appearance.spacing.md

        // --- Icon -----------------------------------------------------------
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: Appearance.font.size.xxl
            implicitHeight: implicitWidth
            radius: width / 2
            color: root.urgent ? Theme.error : Theme.accentContainer

            // The sender's own image if it sent one, its app icon if not, and a
            // glyph if neither — most notifications provide nothing.
            IconImage {
                id: senderImage
                anchors.fill: parent
                anchors.margins: Appearance.padding.xs
                implicitSize: parent.width - Appearance.padding.xs * 2
                asynchronous: true
                visible: status === Image.Ready
                source: {
                    const image = root.notification?.image ?? "";
                    if (image)
                        return image;
                    const appIcon = root.notification?.appIcon ?? "";
                    return appIcon ? Quickshell.iconPath(appIcon, "dialog-information") : "";
                }
            }

            Icon {
                anchors.centerIn: parent
                visible: !senderImage.visible
                text: root.urgent ? "priority_high" : "notifications"
                color: root.urgent ? Theme.onError : Theme.onAccentContainer
                filled: true
                size: Appearance.font.size.md
            }
        }

        // --- Text -----------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xs

                StyledText {
                    text: root.notification?.appName ?? ""
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                    visible: text !== ""
                }

                StyledText {
                    text: "•"
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }

                StyledText {
                    text: Time.since(root.time)
                    color: Theme.textMuted
                    font.pixelSize: Appearance.font.size.xs
                }

                Item {
                    Layout.fillWidth: true
                }

                Icon {
                    visible: root.expandable
                    text: root.expanded ? "expand_less" : "expand_more"
                    color: Theme.textSecondary
                    size: Appearance.font.size.md

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Appearance.padding.xs
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }

                // Always shown, not revealed on hover. A toast is counting down
                // while you decide, and a control you have to go looking for is
                // one you will not reach in time — which is the whole reason
                // drag-to-dismiss existed as the only way out.
                Icon {
                    id: closeButton

                    text: "close"
                    color: closeHover.containsMouse ? Theme.error : Theme.textSecondary
                    size: Appearance.font.size.md

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        anchors.margins: -Appearance.padding.xs
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.discarded()
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                color: Theme.text
                font.pixelSize: Appearance.font.size.sm
                elide: root.expanded ? Text.ElideNone : Text.ElideRight
                wrapMode: root.expanded ? Text.WordWrap : Text.NoWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.notification?.body ?? ""
                color: Theme.textSecondary
                font.pixelSize: Appearance.font.size.xs
                visible: text !== ""
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                // One line collapsed. Unbounded expanded — that is what the
                // chevron is for.
                maximumLineCount: root.expanded ? 100 : 1
            }

            // --- Actions ----------------------------------------------------
            //
            // Only when expanded. A row of buttons on a transient toast is a
            // target that moves away while you are reaching for it.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.xs
                visible: root.expanded && root.hasActions
                spacing: Appearance.spacing.sm

                Repeater {
                    model: root.expanded ? root.actions : []

                    delegate: Rectangle {
                        id: action
                        required property var modelData

                        implicitWidth: actionText.implicitWidth + Appearance.padding.lg * 2
                        implicitHeight: actionText.implicitHeight + Appearance.padding.sm * 2
                        radius: Appearance.rounding.full
                        color: actionHover.containsMouse ? Theme.accentContainer : Theme.surfaceContainerHighest

                        Behavior on color {
                            enabled: Appearance.anim.enabled
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }

                        StyledText {
                            id: actionText
                            anchors.centerIn: parent
                            text: action.modelData?.text ?? ""
                            color: actionHover.containsMouse ? Theme.onAccentContainer : Theme.text
                            font.pixelSize: Appearance.font.size.xs
                        }

                        MouseArea {
                            id: actionHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                action.modelData.invoke();
                                // invoke() dismisses the notification itself
                                // unless it is resident, but the card has to go
                                // either way — leaving it up after you have
                                // answered it is the thing that makes a
                                // notification centre feel stale.
                                root.discarded();
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

}
