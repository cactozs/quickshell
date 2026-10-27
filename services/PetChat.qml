pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.UPower
import QtQuick

// Desktop pet conversation: one question, one answer. A singleton because the
// window is a LazyOverlay and may be destroyed while the request is in flight;
// the reply also survives closing and reopening the pet.
Singleton {
    id: root

    // PNG works too: AnimatedImage shows a still image as a single frame.
    readonly property string imagePath: Quickshell.shellPath("assets/pet/tux.gif")
    readonly property string thinkingImagePath: Quickshell.shellPath("assets/pet/laytux.gif")

    // Free model; swap for another OpenRouter slug here.
    readonly property string model: "nvidia/nemotron-3.5-lightning:free"
    readonly property string endpoint: "https://openrouter.ai/api/v1/chat/completions"

    property bool chatOpen: false
    property bool thinking: false
    property string reply: ""
    // I18n key, translated by the bubble so a live language switch follows.
    property string error: ""
    // Kept for the retry button: an error used to swallow the question.
    property string lastPrompt: ""

    property var request: null

    function ask(text: string): void {
        const prompt = text.trim();
        if (prompt === "" || root.thinking)
            return;
        const local = root.localAnswer(prompt);
        if (local !== "") {
            root.reply = local;
            root.error = "";
            root.thinking = false;
            return;
        }
        root.reply = "";
        root.error = "";
        root.lastPrompt = prompt;
        if (ShellState.openRouterKey === "") {
            root.error = "Ключ OpenRouter не задан — задайте OPENROUTER_API_KEY";
            return;
        }

        root.thinking = true;
        const xhr = new XMLHttpRequest();
        root.request = xhr;
        xhr.open("POST", root.endpoint, true);
        xhr.setRequestHeader("Authorization", "Bearer " + ShellState.openRouterKey);
        xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || root.request !== xhr)
                return;
            root.request = null;
            root.thinking = false;

            if (xhr.status !== 200) {
                console.warn("PetChat: HTTP " + xhr.status + " " + String(xhr.responseText).slice(0, 300));
                root.error = root.errorFor(xhr.status);
                return;
            }

            let answer = "";
            try {
                answer = JSON.parse(xhr.responseText)?.choices?.[0]?.message?.content ?? "";
            } catch (e) {
                console.warn("PetChat: unreadable response " + e);
            }
            if (typeof answer !== "string" || answer.trim() === "") {
                console.warn("PetChat: empty answer " + String(xhr.responseText).slice(0, 300));
                root.error = "OpenRouter вернул пустой ответ";
                return;
            }
            root.reply = answer.trim();
        };

        xhr.send(JSON.stringify({
            "model": root.model,
            "max_tokens": 3000,
            // This model reasons by default and would burn the whole budget on
            // it, returning content: null.
            "reasoning": { "enabled": false },
            "messages": [
                {
                    "role": "system",
                    "content": "You are the smart Tux, a small penguin living on the user's desktop. "
                        + "Reply in the user's language, try replying helpfully, briefly, playfully and shortly (at most three sentences)."
                },
                { "role": "user", "content": prompt }
            ]
        }));
    }

    function errorFor(status: int): string {
        if (status === 401)
            return "Неверный ключ OpenRouter — проверьте настройки";
        if (status === 402)
            return "На балансе OpenRouter нет средств";
        if (status === 429)
            return "Слишком много запросов — подождите";
        if (status === 0 || status >= 500)
            return "OpenRouter недоступен — проверьте сеть";
        return "OpenRouter не ответил — проверьте ключ и баланс";
    }

    // Abort must clear request first: the ready-state handler treats a
    // matching request as a real failure otherwise.
    function cancel(): void {
        const xhr = root.request;
        root.request = null;
        if (xhr !== null)
            xhr.abort();
        root.thinking = false;
        root.error = "";
    }

    function retry(): void {
        if (root.lastPrompt !== "" && !root.thinking)
            root.ask(root.lastPrompt);
    }

    // Free answers for the things the pet can know locally; these also work
    // without a key. Keywords only, not a parser.
    function localAnswer(text: string): string {
        const q = text.toLowerCase();
        const has = (...words) => words.some(word => q.includes(word));
        if (has("который час", "сколько времени") || /(^|\s)время(\s|$)/.test(q)
                || has("what time") || /(^|\s)time(\s|$)/.test(q))
            return Qt.formatDateTime(new Date(), "HH:mm");
        if (has("дата", "какое сегодня число") || /(^|\s)date(\s|$)/.test(q))
            return Qt.formatDateTime(new Date(), "dd.MM.yyyy");
        if (has("погода", "погод", "weather")) {
            if (!Weather.hasData)
                return I18n.t("Погода ещё не загрузилась");
            return Math.round(Weather.temp) + "°, " + I18n.t(Weather.label);
        }
        if (has("заряд", "батаре", "battery")) {
            const device = UPower.displayDevice;
            if (device === null || device === undefined)
                return I18n.t("Батарея не найдена");
            const percent = Math.round(device.percentage * 100) + "%";
            return device.state === UPowerDeviceState.Charging
                ? percent + " · " + I18n.t("заряжается")
                : percent;
        }
        return "";
    }

    // A hung request would leave "Думаю…" on screen forever; XHR has no timeout.
    Timer {
        interval: 30000
        running: root.thinking
        onTriggered: {
            const xhr = root.request;
            root.request = null;
            if (xhr !== null)
                xhr.abort();
            root.thinking = false;
            root.error = "OpenRouter недоступен — проверьте сеть";
        }
    }
}
