pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// The notification server. Replaces mako, which groot used to run.
//
// TWO models, not one with a `popup` flag. That is not a style choice — a
// ListModel notifies on count, and on nothing else. A `var` property computed by
// walking a ListModel and filtering on a role re-evaluates when rows are added
// or removed and never when a role changes, so flipping a `popup` flag updated
// the data and left every binding on it stale. Toasts appeared and then stayed
// forever, because the thing that was supposed to hide them changed a value
// nothing was watching.
//
// Removing a row from `popups` changes its count, which every binding does see.
//
// `keepOnReload` matters more here than on a normal desktop: the dev loop
// hot-reloads this shell constantly, and without it every save would drop the
// notification list on the floor.

Singleton {
    id: root

    // Everything received, newest first. The notification centre shows this.
    readonly property alias all: allModel
    // Currently on screen as a toast. A subset, and transient.
    readonly property alias popups: popupModel

    readonly property int count: allModel.count
    property bool doNotDisturb: false

    ListModel {
        id: allModel
    }

    ListModel {
        id: popupModel
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;

            // Arrival time is recorded here because Notification carries none,
            // and it cannot be attached to the object itself — it is a C++
            // QObject. A model role is the only place it can live.
            const now = Date.now();

            allModel.insert(0, {
                notification: notif,
                time: now
            });

            if (root.doNotDisturb)
                return;

            popupModel.insert(0, {
                notification: notif,
                time: now
            });

            // Oldest first, so a burst does not push the newest off screen.
            while (popupModel.count > Config.notifications.maxVisible)
                popupModel.remove(popupModel.count - 1);

            // Urgency Critical means "do not silently expire" — a failing
            // service or a full disk should stay up until acknowledged.
            if (notif.urgency !== NotificationUrgency.Critical)
                expire.createObject(root, {
                    notif: notif
                });
        }
    }

    // One timer per notification rather than a sweep: each has its own deadline,
    // and a shared tick would either fire late or need sorting.
    property Component expire: Component {
        Timer {
            required property var notif
            running: true
            interval: notif.expireTimeout > 0 ? notif.expireTimeout : Config.notifications.expireTimeout
            onTriggered: {
                root.dismissPopup(notif);
                destroy();
            }
        }
    }

    function indexIn(model, notif): int {
        for (let i = 0; i < model.count; i++)
            if (model.get(i).notification === notif)
                return i;
        return -1;
    }

    // Hide the toast but keep it in the centre — dismissing a popup is "I saw
    // it", not "delete it".
    function dismissPopup(notif): void {
        const i = indexIn(popupModel, notif);
        if (i >= 0)
            popupModel.remove(i);
    }

    function dismiss(notif): void {
        dismissPopup(notif);

        const i = indexIn(allModel, notif);
        if (i >= 0)
            allModel.remove(i);

        notif.dismiss();
    }

    function clear(): void {
        popupModel.clear();
        while (allModel.count > 0) {
            allModel.get(0).notification.dismiss();
            allModel.remove(0);
        }
    }

    // Turning DND on should clear what is already on screen, otherwise it only
    // applies to notifications that have not arrived yet.
    onDoNotDisturbChanged: if (doNotDisturb) popupModel.clear()
}
