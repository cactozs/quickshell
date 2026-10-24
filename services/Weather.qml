pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// Open-Meteo forecast without an API key: current conditions, the next 24 h
// in 3 h steps and a 3-day forecast. Coordinates are hardcoded; change
// lat/lon for your city.
Singleton {
    id: root

    property real lat: 55.75
    property real lon: 37.62

    property bool hasData: false
    property string error: ""

    property real temp: 0
    property real feels: 0
    property int humidity: 0
    property real wind: 0
    property string label: ""
    property string icon: Theme.iconSunny

    property var hours: []
    property var days: []

    readonly property string requestUrl: "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon
        + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"
        + "&hourly=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min"
        + "&timezone=auto&forecast_days=4"

    readonly property var weekDays: ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]

    // Label sources are I18n keys (services/I18n.qml); the popup translates
    // them at display time so they follow a live language switch.
    function condition(code: int, day: bool): var {
        if (code === 0)
            return day ? ["Ясно", Theme.iconSunny] : ["Ясная ночь", Theme.iconNightlight];
        if (code <= 2)
            return ["Переменная облачность", Theme.iconPartlyCloudy];
        if (code === 3)
            return ["Пасмурно", Theme.iconCloud];
        if (code === 45 || code === 48)
            return ["Туман", Theme.iconFog];
        if (code < 60)
            return ["Морось", Theme.iconRain];
        if (code < 70 || (code >= 80 && code <= 82))
            return ["Дождь", Theme.iconRain];
        if (code === 95 || code >= 96)
            return ["Гроза", Theme.iconStorm];
        return ["Снег", Theme.iconSnow];
    }

    function refresh(): void {
        if (!fetchProc.running)
            fetchProc.running = true;
    }

    Process {
        id: fetchProc

        command: ["curl", "-sS", "--max-time", "20", root.requestUrl]

        stdout: StdioCollector {
            onStreamFinished: {
                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    root.error = "Не удалось обновить погоду";
                    return;
                }
                if (!data || !data.current || !data.hourly || !data.daily) {
                    root.error = "Не удалось обновить погоду";
                    return;
                }
                const cur = data.current;
                const day = cur.is_day === 1;
                const cond = root.condition(cur.weather_code, day);
                root.temp = Math.round(cur.temperature_2m);
                root.feels = Math.round(cur.apparent_temperature);
                root.humidity = cur.relative_humidity_2m;
                root.wind = Math.round(cur.wind_speed_10m);
                root.label = cond[0];
                root.icon = cond[1];

                const nowH = String(cur.time).slice(0, 13);
                let start = data.hourly.time.findIndex(t => String(t).slice(0, 13) === nowH);
                if (start < 0)
                    start = 0;
                const h = [];
                for (let i = start; i < data.hourly.time.length && h.length < 8; i += 3) {
                    h.push({
                        "hour": String(data.hourly.time[i]).slice(11, 16),
                        "temp": Math.round(data.hourly.temperature_2m[i]),
                        "icon": root.condition(data.hourly.weather_code[i], data.hourly.is_day[i] === 1)[1]
                    });
                }
                root.hours = h;

                const d = [];
                for (let i = 0; i < Math.min(3, data.daily.time.length); i++) {
                    const parts = String(data.daily.time[i]).split("-");
                    const wd = new Date(parts[0], parts[1] - 1, parts[2]).getDay();
                    d.push({
                        "day": i === 0 ? "Сегодня" : root.weekDays[wd],
                        "icon": root.condition(data.daily.weather_code[i], true)[1],
                        "tmin": Math.round(data.daily.temperature_2m_min[i]),
                        "tmax": Math.round(data.daily.temperature_2m_max[i])
                    });
                }
                root.days = d;

                root.hasData = true;
                root.error = "";
            }
        }
    }

    // Only the weather popup reads this data: refresh while it is open, not
    // every half hour for the whole session. Opening the popup calls refresh()
    // itself, so a long-closed popup still comes back fresh.
    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: ShellState.weatherScreen !== ""
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
