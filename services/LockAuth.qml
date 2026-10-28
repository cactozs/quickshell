pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pam
import QtQuick

// PAM state shared by every lock surface, so all monitors show the same
// prompt and result. There is deliberately no IPC unlock: only the password
// (or the compositor ending the lock) gets the session back.
Singleton {
    id: root

    signal unlocked()

    property string password: ""
    property bool busy: false
    property string error: ""

    onPasswordChanged: {
        if (!root.busy)
            root.error = "";
    }

    function tryUnlock(): void {
        if (root.busy || root.password.length === 0)
            return;
        root.busy = true;
        root.error = "";
        if (!pam.start()) {
            root.busy = false;
            root.error = I18n.t("Ошибка аутентификации");
        }
    }

    function reset(): void {
        root.password = "";
        root.error = "";
        root.busy = false;
    }

    PamContext {
        id: pam

        // The system login stack: the same password + faillock policy a
        // display manager uses, so no /etc/pam.d changes are needed.
        config: "login"

        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.password);
        }

        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.unlocked();
                root.reset();
                return;
            }
            root.password = "";
            if (result === PamResult.MaxTries)
                root.error = I18n.t("Слишком много попыток");
            else if (result === PamResult.Failed)
                root.error = I18n.t("Неверный пароль");
            else
                root.error = I18n.t("Ошибка аутентификации");
        }

        onError: e => {
            root.busy = false;
            root.password = "";
            root.error = I18n.t("Ошибка аутентификации");
        }
    }
}
