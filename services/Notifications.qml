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

    // The history and the muted-app list outlive the process: a closed
    // notification's object is gone after a restart, so only the plain record
    // fields are written and the restored rows come back with `live: null`.
    FileView {
        id: storeFile

        path: Qt.resolvedUrl("../notifications.json")
        preload: false
        blockAllReads: true
        blockWrites: true
        blockLoading: true
        printErrors: false

        Component.onCompleted: text()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: store

            property var entries: []
            property var mutedApps: []
        }
    }

    readonly property var mutedApps: store.mutedApps ?? []

    // Everything ever seen, newest first; capped so a chatty app cannot grow
    // it forever. Entries are plain records (see addHistory), not live
    // Notification objects: the server destroys closed ones when the config
    // reloads, so anything long-lived must not point at them.
    // Record fields: id, appName, summary, body, image, appIcon, desktopEntry,
    // at, live, watcher.
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

    // Ids of notifications whose toast is playing its exit animation.
    // removePopupById marks an id, leaveTimer commits the removal, so the
    // card gets to fade and collapse instead of vanishing. Keyed by id, not
    // by reference: a closed notification's object is freed by the server
    // while the toast still has to render for another instant.
    property var leavingIds: ({})

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

            // replaces_id updates the object in place, without a new arrival.
            function onSummaryChanged(): void { root.refreshEntry(entry); }
            function onBodyChanged(): void { root.refreshEntry(entry); }
            function onImageChanged(): void { root.refreshEntry(entry); }
        }
    }

    function handleNotification(notif: Notification): void {
        // A muted app is dropped before tracking, so the server discards it;
        // critical notifications still come through.
        if (notif.urgency !== NotificationUrgency.Critical && root.isMuted(notif.appName))
            return;

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
        // The first record for an id wins; the watcher below applies later
        // replaces_id updates to it.
        if (root.history.some(e => e.id === notif.id))
            return;

        const entry = {
            id: notif.id,
            appName: notif.appName,
            summary: notif.summary,
            body: notif.body,
            image: notif.image,
            appIcon: notif.appIcon,
            desktopEntry: notif.desktopEntry,
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

    function refreshEntry(entry: var): void {
        const notif = entry.live;
        if (!notif || !root.alive(notif))
            return;
        entry.summary = notif.summary;
        entry.body = notif.body;
        entry.image = notif.image;
        root.history = [...root.history]; // poke row bindings
    }

    // ---- persistence -------------------------------------------------------

    function restore(): void {
        const saved = store.entries ?? [];
        // Server ids restart at 1 every process; a saved id would collide with
        // a fresh notification and make addHistory drop it. Negative ids are
        // unique and never handed out by the server.
        root.history = saved.slice(0, root.historyLimit).map((e, i) => ({
            id: -1 - i,
            appName: e.appName ?? "",
            summary: e.summary ?? "",
            body: e.body ?? "",
            image: e.image ?? "",
            appIcon: e.appIcon ?? "",
            desktopEntry: e.desktopEntry ?? "",
            at: e.at ?? 0,
            live: null,
            watcher: null
        }));
        // Restored rows are old news; the badge counts only this session.
        root.markAllSeen();
    }

    function persist(): void {
        store.entries = root.history.slice(0, root.historyLimit).map(e => ({
            id: e.id,
            appName: e.appName,
            summary: e.summary,
            body: e.body,
            image: e.image,
            appIcon: e.appIcon,
            desktopEntry: e.desktopEntry,
            at: e.at
        }));
    }

    onHistoryChanged: {
        // Keep the seen map bounded: unreadCount is its only consumer and
        // only asks about ids still in history.
        const liveSeen = {};
        for (const entry of root.history) {
            if (root.seen[entry.id] === true)
                liveSeen[entry.id] = true;
        }
        root.seen = liveSeen;
        root.persist();
    }

    Component.onCompleted: Qt.callLater(root.restore)

    // Quickshell.screens is a model, not a JS array; check by loop.
    function hasScreen(name: string): bool {
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name)
                return true;
        }
        return false;
    }

    function addPopup(notif: Notification): void {
        if (root.popups.includes(notif)) {
            // replaced in place: bump to front
            root.popups = [notif, ...root.popups.filter(n => n !== notif)];
            return;
        }
        // Freed entries read as -1; drop them before the emptiness check (a
        // toast on an unplugged screen never reports its close). Re-pick the
        // screen when the latched one is gone, or no toast would ever show.
        root.popups = root.popups.filter(n => root.liveId(n) >= 0);
        if (root.popups.length === 0 || !root.hasScreen(root.popupScreen))
            root.popupScreen = root.focusedOutputName();
        root.popups = [notif, ...root.popups].slice(0, 5);

        const timeout = root.popupTimeout(notif);
        if (timeout > 0)
            root.pendingExpiry = [...root.pendingExpiry, { notif: notif, remaining: timeout, since: Date.now() }];
        root.armPopupTicker();
    }

    // Id of a stack entry, or -1 when the underlying object is already freed.
    // A closed notification's object is released before its card is gone, so
    // property access on it throws; ids are plain values and survive that.
    function liveId(entry: var): int {
        try {
            return entry.id !== undefined ? entry.id : -1;
        } catch (e) {
            return -1;
        }
    }

    // The toast calls this with the id it captured while the object was alive;
    // the actual removal happens in leaveTimer, so the card gets to animate
    // out before it is dropped from the stack.
    function removePopupById(id: int): void {
        root.pendingExpiry = root.pendingExpiry.filter(e => root.liveId(e.notif) !== id);

        const next = Object.assign({}, root.leavingIds);
        next[id] = true;
        root.leavingIds = next;
        leaveTimer.restart();
        root.armPopupTicker();
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
        root.armPopupTicker();
    }

    function checkPopupExpiry(): void {
        for (const entry of root.pendingExpiry.slice()) {
            if (!root.alive(entry.notif)) {
                // Closed by hand or by the app; nothing left to expire.
                root.pendingExpiry = root.pendingExpiry.filter(e => e !== entry);
                continue;
            }
            if (entry.since && Date.now() - entry.since >= entry.remaining)
                entry.notif.expire(); // closed -> the toast reports the id
        }
        root.armPopupTicker();
    }

    // Arms popupTicker at the soonest running countdown instead of ticking
    // 10x/s; hovered toasts are paused and do not arm it.
    function armPopupTicker(): void {
        let soonest = -1;
        const now = Date.now();
        for (const entry of root.pendingExpiry) {
            if (!entry.since)
                continue;
            const left = Math.max(0, entry.remaining - (now - entry.since));
            if (soonest < 0 || left < soonest)
                soonest = left;
        }
        if (soonest < 0) {
            popupTicker.stop();
            return;
        }
        popupTicker.interval = soonest;
        popupTicker.restart();
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

    // ---- per-app mute ------------------------------------------------------

    function isMuted(appName: string): bool {
        return appName !== "" && root.mutedApps.indexOf(appName) !== -1;
    }

    function toggleMuteApp(appName: string): void {
        if (appName === "")
            return;
        store.mutedApps = root.isMuted(appName)
            ? root.mutedApps.filter(a => a !== appName)
            : [...root.mutedApps, appName];
    }

    function unmuteAll(): void {
        store.mutedApps = [];
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
        // No focused window (empty workspace): niri still marks the active one.
        const active = Niri.workspaces.find(w => w.is_focused === true);
        if (active && active.output)
            return active.output;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function arrivalText(entry: var): string {
        return entry.at ? Qt.formatTime(new Date(entry.at), "HH:mm") : "";
    }

    // ---- icons -------------------------------------------------------------

    // A notification's icon hint is not a QML image source. app_icon arrives
    // as an XDG icon *name* (Quickshell substitutes the desktop entry's icon
    // when the app sent none), and every image-path hint that is not already a
    // file: URL is wrapped as an image://icon/<id> request — plain filesystem
    // paths included. Handed straight to an Image, a bare name resolves to a
    // missing relative URL and draws nothing, while an unresolved provider id
    // makes IconImageProvider paint its magenta checkerboard. Resolve every
    // hint here instead: names go through Quickshell.iconPath's boolean
    // overload, which returns "" when the name is not installed, so the views
    // draw their glyph fallback.
    function resolveIcon(hint: var): string {
        const value = String(hint ?? "");
        if (value === "")
            return "";

        const providerPrefix = "image://icon/";
        if (value.startsWith(providerPrefix)) {
            const id = value.slice(providerPrefix.length);
            // A path wrapped as an icon name (Chromium's image-path hint).
            if (id.startsWith("/"))
                return "file://" + id;
            if (id.startsWith("data:") || id.startsWith("qrc:"))
                return id;
            return Quickshell.iconPath(id, true);
        }

        if (value.startsWith("image://") || value.startsWith("file:")
                || value.startsWith("data:") || value.startsWith("qrc:"))
            return value;
        if (value.startsWith("/"))
            return "file://" + value;
        return Quickshell.iconPath(value, true);
    }

    // Best icon for one notification or history record: the image hint first,
    // then the app icon, then the icon of the desktop-entry hint. "" means
    // nothing resolved and the views draw their glyph fallback.
    function pickIcon(image: var, appIcon: var, desktopEntry: var): string {
        const direct = root.resolveIcon(image) || root.resolveIcon(appIcon);
        if (direct !== "")
            return direct;

        const id = String(desktopEntry ?? "");
        if (id === "")
            return "";

        // The hint is a desktop file name without its .desktop suffix; a few
        // senders include it anyway, so try both spellings.
        let entry = DesktopEntries.byId(id);
        if (!entry && id.endsWith(".desktop"))
            entry = DesktopEntries.byId(id.slice(0, -8));
        return entry ? root.resolveIcon(entry.icon) : "";
    }

    function entryIcon(entry: var): string {
        return root.pickIcon(entry?.image, entry?.appIcon, entry?.desktopEntry);
    }

    // ---- popup expiry ------------------------------------------------------

    // Drives popup expiry: armed at the next deadline by armPopupTicker.
    Timer {
        id: popupTicker

        onTriggered: root.checkPopupExpiry()
    }

    // Commits toast removals after the exit animation (fade durShort +
    // collapse durMedium) has had time to play, plus a small margin.
    Timer {
        id: leaveTimer

        interval: 400
        onTriggered: {
            const gone = root.leavingIds;
            root.leavingIds = ({});
            root.popups = root.popups.filter(n => {
                const id = root.liveId(n);
                return id >= 0 && gone[id] !== true;
            });
        }
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

        function mute(appName: string): void {
            if (!root.isMuted(appName))
                root.toggleMuteApp(appName);
        }

        function unmuteAll(): void {
            root.unmuteAll();
        }
    }
}
