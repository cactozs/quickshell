pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// Shell UI translations. Keys are the Russian source strings, so "ru" needs no
// table at all: a missing entry falls back to the key itself. A plain QML map
// instead of .ts/.qm files, because this config has no build step (no
// lrelease). Reading ShellState.language inside t() makes every binding that
// calls it re-evaluate when the language is switched in the settings menu.
Singleton {
    id: root

    readonly property var translations: ({
        "en": {
            // settings menu
            "Настройки": "Settings",
            "Язык": "Language",
            "Вид лончера": "Launcher view",
            "Классический": "Classic",
            "Полноэкранный": "Fullscreen",
            "Стиль": "Style",
            "Блюр": "Blur",
            "Обои": "Wallpaper",
            "Окна": "Windows",
            "Тема": "Theme",
            "Тёмная": "Dark",
            "Светлая": "Light",
            "Цвета": "Colors",
            "Шрифт": "Font",
            "Профиль питания": "Power profile",
            "Экономия": "Power saver",
            "Баланс": "Balanced",
            "Производительность": "Performance",

            // quick settings
            "Выключен": "Off",
            "Включён": "On",
            "нужен пароль": "password required",
            "неверный пароль или таймаут": "wrong password or timeout",
            "ошибка аутентификации": "authentication error",
            "соединение разорвано": "connection lost",
            "сеть пропала": "network lost",
            "неизвестная ошибка": "unknown error",
            "Выключение": "Power off",
            "Перезагрузка": "Restart",
            "Выход": "Log out",
            "Гибернация": "Hibernate",
            "Блокировка": "Lock",
            "Сон": "Sleep",
            "Не беспокоить": "Do not disturb",
            "Ночной свет": "Night light",
            "Wi-Fi выключен": "Wi-Fi is off",
            "Поиск сетей…": "Searching for networks…",
            "Пароль": "Password",
            "Подключить": "Connect",
            "Подключение…": "Connecting…",
            "Подключено": "Connected",
            "Забыть сеть?": "Forget network?",
            "Питание": "Power",
            "Не удалось подключиться: ": "Could not connect: ",
            "Аудиовыход": "Audio output",
            "Микрофон": "Microphone",
            "Нет устройства": "No device",
            "Без звука": "Muted",
            "Громкость: ": "Volume: ",

            // launcher
            "Поиск приложений…": "Search apps…",
            "Ничего не найдено": "Nothing found",
            "↑↓←→ — выбор · Enter — запуск · тянуть иконку — порядок · Ctrl+F — в избранное · Esc — закрыть": "↑↓←→ — select · Enter — launch · drag icon — reorder · Ctrl+F — favorite · Esc — close",
            "↑↓ — выбор · Enter — запуск · Ctrl+F — в избранное · Esc — закрыть": "↑↓ — select · Enter — launch · Ctrl+F — favorite · Esc — close",
            " из ": " of ",

            // clipboard
            "Поиск в буфере обмена…": "Search clipboard…",
            "Буфер обмена пуст": "Clipboard is empty",
            "Удалить выбранную": "Delete selected",
            "Удалить всё": "Delete all",
            "Закрепить": "Pin",
            "Открепить": "Unpin",
            "Закреплённые": "Pinned",
            "Очистить историю": "Clear history",
            "↑↓ — выбор · Enter — применить · Esc — назад": "↑↓ — select · Enter — apply · Esc — back",
            "↑↓ — выбор · Enter — копировать · Ctrl+P — действия · Esc — закрыть": "↑↓ — select · Enter — copy · Ctrl+P — actions · Esc — close",

            // wallpaper manager
            "Все": "All",
            "Случайные": "Random",
            "Поиск обоев…": "Search wallpapers…",
            "В ~/Pictures/Wallpapers нет изображений": "No images in ~/Pictures/Wallpapers",
            "↑↓←→ — выбор · Enter — применить · Ctrl+F — в избранное · Ctrl+R — случайные · Esc — закрыть": "↑↓←→ — select · Enter — apply · Ctrl+F — favorite · Ctrl+R — random · Esc — close",

            // calendar and forecast names
            "Январь": "January",
            "Февраль": "February",
            "Март": "March",
            "Апрель": "April",
            "Май": "May",
            "Июнь": "June",
            "Июль": "July",
            "Август": "August",
            "Сентябрь": "September",
            "Октябрь": "October",
            "Ноябрь": "November",
            "Декабрь": "December",
            "Пн": "Mon",
            "Вт": "Tue",
            "Ср": "Wed",
            "Чт": "Thu",
            "Пт": "Fri",
            "Сб": "Sat",
            "Вс": "Sun",

            // weather
            "Ясно": "Clear",
            "Ясная ночь": "Clear night",
            "Переменная облачность": "Partly cloudy",
            "Пасмурно": "Overcast",
            "Туман": "Fog",
            "Морось": "Drizzle",
            "Дождь": "Rain",
            "Гроза": "Thunderstorm",
            "Снег": "Snow",
            "Не удалось обновить погоду": "Could not update the weather",
            "Сегодня": "Today",
            "Загрузка…": "Loading…",
            "Ощущается ": "Feels like ",
            "° • Ветер ": "° • Wind ",
            " м/с • Влажность ": " m/s • Humidity ",

            // system popup and notifications
            "Мониторинг": "Monitoring",
            "Сеть": "Network",
            "Аптайм ": "Uptime ",
            "Уведомления": "Notifications",
            "Нет уведомлений": "No notifications",
            "Замьютить приложение": "Mute app",
            "Вернуть все": "Unmute all",

            // tray
            "Трей": "Tray",
            "Нет приложений": "No applications",

            // bar
            "Brightness: ": "Brightness: ",
            " дн ": " d ",
            " remaining": " remaining",
            "Temperature: ": "Temperature: ",
            "Usage: ": "Usage: ",
            "Memory": "Memory",
            "Used: ": "Used: ",
            "Network": "Network"
        },
        "de": {
            // settings menu
            "Настройки": "Einstellungen",
            "Язык": "Sprache",
            "Вид лончера": "Launcher-Ansicht",
            "Классический": "Klassisch",
            "Полноэкранный": "Vollbild",
            "Стиль": "Stil",
            "Блюр": "Unschärfe",
            "Обои": "Hintergrund",
            "Окна": "Fenster",
            "Тема": "Design",
            "Тёмная": "Dunkel",
            "Светлая": "Hell",
            "Цвета": "Farben",
            "Шрифт": "Schrift",
            "Профиль питания": "Energieprofil",
            "Экономия": "Energiesparen",
            "Баланс": "Ausgewogen",
            "Производительность": "Leistung",

            // quick settings
            "Выключен": "Aus",
            "Включён": "An",
            "нужен пароль": "Passwort erforderlich",
            "неверный пароль или таймаут": "falsches Passwort oder Zeitüberschreitung",
            "ошибка аутентификации": "Authentifizierungsfehler",
            "соединение разорвано": "Verbindung unterbrochen",
            "сеть пропала": "Netzwerk verloren",
            "неизвестная ошибка": "unbekannter Fehler",
            "Выключение": "Ausschalten",
            "Перезагрузка": "Neustart",
            "Выход": "Abmelden",
            "Гибернация": "Ruhezustand",
            "Блокировка": "Sperren",
            "Сон": "Standby",
            "Не беспокоить": "Nicht stören",
            "Ночной свет": "Nachtlicht",
            "Wi-Fi выключен": "Wi-Fi ist aus",
            "Поиск сетей…": "Netzwerke werden gesucht…",
            "Пароль": "Passwort",
            "Подключить": "Verbinden",
            "Подключение…": "Verbinden…",
            "Подключено": "Verbunden",
            "Забыть сеть?": "Netzwerk vergessen?",
            "Питание": "Energie",
            "Не удалось подключиться: ": "Verbindung fehlgeschlagen: ",
            "Аудиовыход": "Audioausgabe",
            "Микрофон": "Mikrofon",
            "Нет устройства": "Kein Gerät",
            "Без звука": "Stumm",
            "Громкость: ": "Lautstärke: ",

            // launcher
            "Поиск приложений…": "Apps suchen…",
            "Ничего не найдено": "Nichts gefunden",
            "↑↓←→ — выбор · Enter — запуск · тянуть иконку — порядок · Ctrl+F — в избранное · Esc — закрыть": "↑↓←→ — auswählen · Enter — starten · Symbol ziehen — Reihenfolge · Ctrl+F — Favorit · Esc — schließen",
            "↑↓ — выбор · Enter — запуск · Ctrl+F — в избранное · Esc — закрыть": "↑↓ — auswählen · Enter — starten · Ctrl+F — Favorit · Esc — schließen",
            " из ": " von ",

            // clipboard
            "Поиск в буфере обмена…": "Zwischenablage durchsuchen…",
            "Буфер обмена пуст": "Zwischenablage ist leer",
            "Удалить выбранную": "Ausgewählte löschen",
            "Удалить всё": "Alles löschen",
            "Закрепить": "Anheften",
            "Открепить": "Loslösen",
            "Закреплённые": "Angeheftet",
            "Очистить историю": "Verlauf löschen",
            "↑↓ — выбор · Enter — применить · Esc — назад": "↑↓ — auswählen · Enter — übernehmen · Esc — zurück",
            "↑↓ — выбор · Enter — копировать · Ctrl+P — действия · Esc — закрыть": "↑↓ — auswählen · Enter — kopieren · Ctrl+P — Aktionen · Esc — schließen",

            // wallpaper manager
            "Все": "Alle",
            "Случайные": "Zufällig",
            "Поиск обоев…": "Hintergründe suchen…",
            "В ~/Pictures/Wallpapers нет изображений": "Keine Bilder in ~/Pictures/Wallpapers",
            "↑↓←→ — выбор · Enter — применить · Ctrl+F — в избранное · Ctrl+R — случайные · Esc — закрыть": "↑↓←→ — auswählen · Enter — anwenden · Ctrl+F — Favorit · Ctrl+R — zufällig · Esc — schließen",

            // calendar and forecast names
            "Январь": "Januar",
            "Февраль": "Februar",
            "Март": "März",
            "Апрель": "April",
            "Май": "Mai",
            "Июнь": "Juni",
            "Июль": "Juli",
            "Август": "August",
            "Сентябрь": "September",
            "Октябрь": "Oktober",
            "Ноябрь": "November",
            "Декабрь": "Dezember",
            "Пн": "Mo",
            "Вт": "Di",
            "Ср": "Mi",
            "Чт": "Do",
            "Пт": "Fr",
            "Сб": "Sa",
            "Вс": "So",

            // weather
            "Ясно": "Klar",
            "Ясная ночь": "Klare Nacht",
            "Переменная облачность": "Teilweise bewölkt",
            "Пасмурно": "Bedeckt",
            "Туман": "Nebel",
            "Морось": "Nieselregen",
            "Дождь": "Regen",
            "Гроза": "Gewitter",
            "Снег": "Schnee",
            "Не удалось обновить погоду": "Wetter konnte nicht aktualisiert werden",
            "Сегодня": "Heute",
            "Загрузка…": "Laden…",
            "Ощущается ": "Gefühlt ",
            "° • Ветер ": "° • Wind ",
            " м/с • Влажность ": " m/s • Feuchtigkeit ",

            // system popup and notifications
            "Мониторинг": "Überwachung",
            "Сеть": "Netzwerk",
            "Аптайм ": "Laufzeit ",
            "Уведомления": "Benachrichtigungen",
            "Нет уведомлений": "Keine Benachrichtigungen",
            "Замьютить приложение": "App stummschalten",
            "Вернуть все": "Alle wieder aktivieren",

            // tray
            "Трей": "Tray",
            "Нет приложений": "Keine Anwendungen",

            // bar
            "Brightness: ": "Helligkeit: ",
            " дн ": " T ",
            " remaining": " verbleibend",
            "Temperature: ": "Temperatur: ",
            "Usage: ": "Nutzung: ",
            "Memory": "Arbeitsspeicher",
            "Used: ": "Belegt: ",
            "Network": "Netzwerk"
        }
    })

    // One string, or a list mapped item by item (month and day names).
    function t(value: var): var {
        const table = root.translations[ShellState.language];
        if (!table)
            return value;
        if (Array.isArray(value))
            return value.map(entry => table[entry] !== undefined ? table[entry] : entry);
        return table[value] !== undefined ? table[value] : value;
    }

    // Stand-in for the repo's missing test suite: the two tables must cover the
    // same keys, so a new string never lands in only one language.
    Component.onCompleted: {
        const en = root.translations["en"];
        const de = root.translations["de"];
        for (const key in en)
            if (de[key] === undefined)
                console.warn("I18n: de misses \"" + key + "\"");
        for (const key in de)
            if (en[key] === undefined)
                console.warn("I18n: en misses \"" + key + "\"");
    }
}
