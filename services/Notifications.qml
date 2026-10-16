pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Notification daemon (owns org.freedesktop.Notifications, replacing swaync).
// Keeps an in-memory history and drives the toast stack (NotificationToast)
// and the center panel (NotificationCenter).
//
// Lifecycle notes (quickshell 0.3): the arrival handler must set
// `tracked = true` or the server deletes the notification as soon as the
// signal returns. The server's trackedNotifications holds only still-open
// notifications, so the history below is ours; closed entries stay readable
// because holding them retains the underlying object.
Singleton {
    id: root

    // ---- daemon ------------------------------------------------------------

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notif => root.handleNotification(notif)
    }

    // ---- state -------------------------------------------------------------

    PersistentProperties {
        id: props

        reloadableId: "notifications"

        property bool dnd
    }

    readonly property bool dnd: props.dnd

    // Everything ever seen, newest first; capped so a chatty app cannot grow
    // it forever. Entries are plain records (see addHistory), not live
    // Notification objects: the server destroys closed ones when the config
    // reloads, so anything long-lived must not point at them.
    // Record fields: id, appName, summary, body, image, appIcon, at, live,
    // watcher.
    property var history: []
    readonly property int historyLimit: 100

    // Ids already glanced at (badge source). In-memory only, so after a
    // reload everything counts as unread again.
    property var seen: ({})

    readonly property int unreadCount: root.history.filter(e => !root.seen[e.id]).length

    // Ids whose toast already played its entrance animation. The toast
    // Repeater rebuilds every card on each change, so cards seen before skip
    // the animation instead of flickering.
    property var animated: ({})

    // Popup expiry bookkeeping: [{ notif, remaining, since }]. Lives here and
    // not in the toast delegate: the Repeater rebuilds delegates on every
    // stack change, and a toast the cap drops from the stack must still close
    // its notification when the timeout runs out.
    property var pendingExpiry: []

    // Newest first, rendered by the toast stack; capped at five so a chatty
    // app cannot cover the screen.
    property list<Notification> popups: []

    // Which screen hosts the current stack; pinned while non-empty so a
    // burst that spans a focus change stays on one monitor.
    property string popupScreen: ""

    // ---- arrivals ----------------------------------------------------------

    // Flips a history entry to its frozen snapshot when the notification
    // closes, so nothing keeps reading the live object afterwards.
    Component {
        id: closeWatcher

        Connections {
            property var entry

            function onClosed(): void {
                entry.live = null;
                if (entry.watcher) {
                    entry.watcher.destroy();
                    entry.watcher = null;
                }
                root.history = [...root.history]; // poke row bindings
            }
        }
    }

    function handleNotification(notif: Notification): void {
        notif.tracked = true;

        if (notif.lastGeneration) {
            // Carried over a config reload: back into history, no popup
            // replay. Transient ones must not persist anywhere.
            root.history = root.history.filter(e => e.id !== notif.id);
            if (notif.transient)
                notif.tracked = false;
            else
                root.addHistory(notif);
            return;
        }

        if (!notif.transient)
            root.addHistory(notif);

        if (root.dnd && notif.urgency !== NotificationUrgency.Critical)
            return;

        root.addPopup(notif);
    }

    function addHistory(notif: Notification): void {
        // A replaces_id update may re-emit; the first record wins so ids
        // stay unique.
        if (root.history.some(e => e.id === notif.id))
            return;

        const entry = {
            id: notif.id,
            appName: notif.appName,
            summary: notif.summary,
            body: notif.body,
            image: notif.image,
            appIcon: notif.appIcon,
            at: Date.now(),
            live: notif,
            watcher: null,
        };
        entry.watcher = closeWatcher.createObject(root, { target: notif, entry: entry });

        const all = [entry, ...root.history];
        for (const old of all.slice(root.historyLimit)) {
            if (old.watcher)
                old.watcher.destroy();
            if (old.live)
                old.live.dismiss();
        }
        root.history = all.slice(0, root.historyLimit);
    }

    function addPopup(notif: Notification): void {
        if (root.popups.includes(notif)) {
            // replaced in place: bump to front
            root.popups = [notif, ...root.popups.filter(n => n !== notif)];
            return;
        }
        if (root.popups.length === 0)
            root.popupScreen = root.focusedOutputName();
        root.popups = [notif, ...root.popups].slice(0, 5);

        const timeout = root.popupTimeout(notif);
        if (timeout > 0)
            root.pendingExpiry = [...root.pendingExpiry, { notif: notif, remaining: timeout, since: Date.now() }];
    }

    function removePopup(notif: Notification): void {
        root.pendingExpiry = root.pendingExpiry.filter(e => e.notif !== notif);
        root.popups = root.popups.filter(n => n !== notif);
    }

    // Hovering a toast pauses its countdown; the remaining time is kept.
    function setPopupHover(notif: Notification, hovered: bool): void {
        const entry = root.pendingExpiry.find(e => e.notif === notif);
        if (!entry)
            return;
        if (hovered && entry.since) {
            entry.remaining = Math.max(0, entry.remaining - (Date.now() - entry.since));
            entry.since = null;
        } else if (!hovered && !entry.since) {
            entry.since = Date.now();
        }
    }

    function checkPopupExpiry(): void {
        for (const entry of root.pendingExpiry.slice()) {
            if (!root.alive(entry.notif)) {
                // Closed by hand or by the app; nothing left to expire.
                root.pendingExpiry = root.pendingExpiry.filter(e => e !== entry);
                continue;
            }
            if (entry.since && Date.now() - entry.since >= entry.remaining)
                entry.notif.expire(); // closed -> removePopup drops the entry
        }
    }

    // True the first time a toast for this notification is built.
    function markAnimated(notif: Notification): bool {
        if (root.animated[notif.id])
            return false;
        root.animated[notif.id] = true;
        return true;
    }

    // ---- actions -----------------------------------------------------------

    // A config reload can destroy already-closed notification objects that
    // our arrays still reference; property access on those throws. Turns
    // "still open" into a safe read.
    function alive(notif: Notification): bool {
        try {
            return notif.tracked;
        } catch (e) {
            return false;
        }
    }

    // The app's default action, or null; only still-open notifications can
    // take one (the server refuses actions on closed ones).
    function defaultAction(notif: Notification): var {
        if (!root.alive(notif))
            return null;
        return notif.actions.find(a => a.identifier === "default") ?? null;
    }

    // Run the default action of a still-open entry, if any. invoke() closes
    // the notification itself unless it is resident.
    function activate(entry: var): void {
        const notif = entry.live;
        if (!notif)
            return;
        const action = root.defaultAction(notif);
        if (action)
            action.invoke();
    }

    // Center's X: close the notification if still open, then drop it from
    // the history (its watcher releases the live object on the way out).
    // Matching by id, not by reference: rows get a copy of the record from
    // the ListView model, so `e !== entry` would never match.
    function remove(entry: var): void {
        if (entry.live && root.alive(entry.live))
            entry.live.dismiss();
        root.history = root.history.filter(e => e.id !== entry.id);
    }

    function clearAll(): void {
        // Reset first: even if one dismiss misbehaves the list is cleared.
        const all = root.history.slice();
        root.history = [];
        for (const entry of all) {
            if (entry.live && root.alive(entry.live))
                entry.live.dismiss();
        }
    }

    function toggleDnd(): void {
        props.dnd = !props.dnd;
    }

    function markAllSeen(): void {
        const next = ({});
        for (const notif of root.history)
            next[notif.id] = true;
        root.seen = next;
    }

    // ---- timeouts ----------------------------------------------------------

    // Popup lifetime in ms; -1 = stays until closed by hand. The app's
    // expire_timeout hint (ms, 0 = never) wins, then urgency.
    function popupTimeout(notif: Notification): int {
        const hint = notif.expireTimeout;
        if (hint > 0)
            return Math.round(hint);
        if (hint === 0)
            return -1;
        if (notif.urgency === NotificationUrgency.Critical)
            return -1;
        return notif.urgency === NotificationUrgency.Low ? 4000 : 7000;
    }

    // ---- screens -----------------------------------------------------------

    // Output with keyboard focus per niri, falling back to the first screen.
    function focusedOutputName(): string {
        const win = Niri.focusedWindow;
        if (win) {
            const ws = Niri.workspaces.find(w => w.id === win.workspace_id);
            if (ws && ws.output)
                return ws.output;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function arrivalText(entry: var): string {
        return entry.at ? Qt.formatTime(new Date(entry.at), "HH:mm") : "";
    }

    // ---- popup expiry ------------------------------------------------------

    // Drives popup expiry while anything has a pending timeout.
    Timer {
        id: popupTicker

        interval: 100
        repeat: true
        running: root.pendingExpiry.length > 0
        onTriggered: root.checkPopupExpiry()
    }

    // ---- IPC ---------------------------------------------------------------

    IpcHandler {
        target: "notifs"

        function toggleDnd(): void {
            root.toggleDnd();
        }

        function dnd(): bool {
            return root.dnd;
        }

        function clear(): void {
            root.clearAll();
        }
    }
}
