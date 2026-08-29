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

    // How many toasts the pointer is currently over. Expiry is held while this
    // is non-zero, which is what makes action buttons on a transient toast
    // usable at all — otherwise the thing you are reaching for times out from
    // under the cursor. Incremented by NotificationCard.
    property int hovering: 0

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

            // A notification can go away without us dismissing it: the sender
            // closes it, or the server expires it. Both emit `closed`, and
            // without this the models keep a reference to an object that is on
            // its way out — which is what made some rows unclearable, and made
            // Clear all abort partway through when it hit one.
            notif.closed.connect(() => root.forget(notif));

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

            // Stops while a toast is hovered and restarts from zero when the
            // pointer leaves. Restarting rather than resuming is deliberate: you
            // have just read it, so a full fresh window is more useful than
            // whatever remained of the old one.
            running: root.hovering === 0

            interval: notif.expireTimeout > 0 ? notif.expireTimeout : Config.notifications.expireTimeout
            onTriggered: {
                root.dismissPopup(notif);
                destroy();
            }
        }
    }

    // Drop it from both models WITHOUT dismissing. Used when the notification
    // has already gone — dismissing something that is already closed is at best
    // redundant and at worst a call into a dead object.
    function forget(notif): void {
        const p = root.indexIn(popupModel, notif);
        if (p >= 0)
            popupModel.remove(p);

        const a = root.indexIn(allModel, notif);
        if (a >= 0)
            allModel.remove(a);
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

    // Rows come out of the models FIRST, then the notification is dismissed.
    //
    // The other order does not work: dismiss() emits `closed`, whose handler
    // removes the row, so the model mutates underneath whatever loop is walking
    // it. Removing first makes the handler a no-op and leaves nothing to trip
    // over.
    function dismiss(notif): void {
        root.forget(notif);
        root.tell(notif);
    }

    // One dismissal that cannot take the rest down with it. A notification whose
    // sender has gone leaves an object that throws on any call, and a throw here
    // used to abandon every row after it.
    function tell(notif): void {
        try {
            if (notif)
                notif.dismiss();
        } catch (e) {
            // Already gone. The row is out of the model either way, which is the
            // part that matters.
        }
    }

    function clear(): void {
        popupModel.clear();

        // Snapshot, empty the model, then dismiss. Reading `get(0)` in a loop
        // that also removes rows means every dismissal shifts the ground under
        // the next read, and one bad object ended the whole operation.
        const pending = [];
        for (let i = 0; i < allModel.count; i++) {
            const row = allModel.get(i);
            if (row?.notification)
                pending.push(row.notification);
        }

        allModel.clear();

        for (let i = 0; i < pending.length; i++)
            root.tell(pending[i]);
    }

    // Turning DND on should clear what is already on screen, otherwise it only
    // applies to notifications that have not arrived yet.
    onDoNotDisturbChanged: if (doNotDisturb) popupModel.clear()
}
