pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// The notification server. Replaces mako, which groot used to run.
//
// `keepOnReload` matters more here than on a normal desktop: the dev loop
// hot-reloads this shell constantly, and without it every save would drop the
// notification list on the floor.

Singleton {
    id: root

    readonly property alias list: store
    readonly property int count: store.count
    property bool doNotDisturb: false

    // Popups are the transient toasts; the full list lives in the centre.
    readonly property var popups: {
        const out = [];
        for (let i = 0; i < store.count && out.length < Config.notifications.maxVisible; i++) {
            const n = store.get(i);
            if (n.popup)
                out.push(n);
        }
        return out;
    }

    ListModel {
        id: store
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

            store.insert(0, {
                notification: notif,
                popup: !root.doNotDisturb
            });

            // Urgency Critical means "do not silently expire" — a failing
            // service or a full disk should stay up until acknowledged.
            if (notif.urgency !== NotificationUrgency.Critical && !root.doNotDisturb)
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

    function indexOf(notif): int {
        for (let i = 0; i < store.count; i++)
            if (store.get(i).notification === notif)
                return i;
        return -1;
    }

    // Hide the toast but keep it in the centre — dismissing a popup is "I saw
    // it", not "delete it".
    function dismissPopup(notif): void {
        const i = indexOf(notif);
        if (i >= 0)
            store.setProperty(i, "popup", false);
    }

    function dismiss(notif): void {
        const i = indexOf(notif);
        if (i < 0)
            return;
        store.remove(i);
        notif.dismiss();
    }

    function clear(): void {
        while (store.count > 0) {
            store.get(0).notification.dismiss();
            store.remove(0);
        }
    }
}
