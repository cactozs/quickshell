# Quickshell

[English](README.md) | **Русский**

> **В основном написано ИИ.** QML, установщик, документация и этот README
> сделаны с помощью ИИ и проверены человеком. Это личный конфиг, который просто
> опубликован, а не продукт с поддержкой.

Полноценная оболочка рабочего стола в стиле Material 3 Expressive для
[niri](https://github.com/YaLTeR/niri), собранная на
[Quickshell](https://quickshell.org/). Один QML-конфиг заменяет панель,
лаунчер, менеджер буфера обмена, демон уведомлений, быстрые настройки, OSD,
менеджер обоев и меню питания.

![Рабочий стол](assets/screenshots/desktop.png)

Палитра берётся из обоев через [matugen](https://github.com/InioX/matugen) и
переносится на остальной рабочий стол: GTK3/GTK4, Qt-приложения, ghostty,
границы и focus-ring в niri.

Тексты интерфейса сейчас на русском; код и документация — на английском (кроме
этого файла).

## Что внутри

- **Панель** — рабочие пространства, заголовок окна, часы (таймер и секундомер)
  и дата (погода), раскладка, громкость, яркость, батарея, уведомления,
  системный трей и кнопка питания.
- **Лаунчер** — приложения, арифметика и записи `Terminal=true` из `.desktop`;
  терминал настраивается через `$TERMINAL` (`alacritty` по умолчанию).
- **История буфера обмена** — `cliphist` + `wl-clipboard`, текст и картинки.
  Ctrl+P открывает меню действий; закрепление сохраняет декодированный снимок
  в каталоге данных оболочки, поэтому пины переживают `cliphist wipe`.
- **Уведомления** — Quickshell сам является демоном уведомлений: всплывающие
  тосты, история, переживающая перезапуск, режим «Не беспокоить», мьют
  приложений и центр уведомлений.
- **Быстрые настройки** — громкость, переключение аудиовыхода, мьют микрофона,
  яркость, Wi-Fi, ночной свет, «Не беспокоить», MPRIS-плеер, профили питания,
  язык интерфейса (RU/EN/DE), тема/стиль/цвета/шрифт и меню питания.
- **Экран блокировки** — текущие обои, карточка с часами и поле пароля через
  PAM на `ext-session-lock-v1`; блокируется после 5 минут простоя и выключает
  мониторы через 7,5.
- **Менеджер обоев** — рекурсивная библиотека, кеш превью, избранное, случайные
  обои, drag-and-drop на рабочий стол или панель.
- **Питомец** — перетаскиваемый Тукс: общается через NVIDIA NIM, отвечает про
  время, дату, погоду и батарею без сети, спит от бездействия и реагирует на
  уведомления, низкий заряд и выключенный звук.
- **OSD и системное окно** — громкость/яркость (в том числе для изменений через
  `wpctl`/`brightnessctl`), CPU, RAM, температура и GPU (AMD через sysfs,
  запасной вариант — `nvidia-smi`).
- **Пять стилей** — `M3 Inspired`, `M3 Blur`, `New` (графитовый акрил),
  `Nothing` (непрозрачный графит, жёсткие углы) и `New Nothing` (тот же графит
  с акриловой отделкой и блюром).
- **Светлая и тёмная темы** — второй проход matugen пишет светлую палитру;
  переключается и оболочка, и остальной рабочий стол.

## Требования

- Wayland с **niri**. QML можно запустить и в другом композиторе, но рабочие
  пространства, заголовки окон и раскладка берутся из `niri msg`.
- Arch Linux для установщика (`pacman`). Ручной путь работает и в других
  дистрибутивах с теми же пакетами.
- Quickshell **0.3.2 или новее** (разработка и проверка шли на 0.3.2 и niri 26.04).

## Скриншоты

| Погода | Календарь |
|:---:|:---:|
| ![Погода](assets/screenshots/weather.png) | ![Календарь](assets/screenshots/calendar.png) |

| Быстрые настройки | Меню питания |
|:---:|:---:|
| ![Быстрые настройки](assets/screenshots/quick-settings.png) | <img src="assets/screenshots/power-menu.png" width="300" alt="Меню питания"> |

| OSD | Раскладка |
|:---:|:---:|
| ![OSD](assets/screenshots/osd.png) | ![Раскладка](assets/screenshots/layout.png) |

| Лончер | История буфера обмена |
|:---:|:---:|
| ![Лончер](assets/screenshots/launcher.png) | ![История буфера обмена](assets/screenshots/clipboard.png) |

| Меню настроек | Менеджер обоев |
|:---:|:---:|
| ![Меню настроек](assets/screenshots/settings.png) | <img src="assets/screenshots/wallpaper.png" width="520" alt="Менеджер обоев"> |

## Быстрый старт

### Установщик (рекомендуется)

```sh
git clone https://github.com/cactozs/quickshell.git ~/.config/quickshell
cd ~/.config/quickshell
./install.sh
```

Установщик намеренно осторожен:

| шаг | что делает | отключить |
|---|---|---|
| пакеты | ставит недостающие пакеты Arch через `pacman -S --needed` | `--no-packages` |
| шрифты | скачивает **Google Sans** в `~/.local/share/fonts/GoogleSans.ttf`, если его нет | `--no-fonts` |
| matugen | пишет `~/.config/matugen/config.toml`, `light.toml` и шаблон с **абсолютными путями к этому репозиторию** | — |
| шим | ставит `/usr/local/bin/awww`, делая бэкап существующего файла | `--no-shim` |
| каталоги | создаёт `~/Pictures/Wallpapers` и каталоги, в которые оболочка пишет темы | — |
| niri | добавляет include `quickshell.kdl`, автозапуск и `QT_QPA_PLATFORMTHEME`, с бэкапами | `--no-apply` |
| ghostty | добавляет `theme = Quickshell`, если темы ещё нет | `--no-apply` |
| qt6ct | добавляет `color_scheme_path`, если он ещё не задан | `--no-apply` |
| клавиши | **печатает** бинды; `keybinds.kdl` никогда не редактируется | всегда |

Перед изменением существующий файл копируется в
`файл.bak.ГГГГММДД-ЧЧММСС.PID`. Повторный запуск безопасен: файл пишется,
только если содержимое отличается.

Если репозиторий лежит не в `~/.config/quickshell`, запустите
`./install.sh --link` (создаст симлинк, если путь свободен) или стартуйте
оболочку через `quickshell -p /путь/к/quickshell`. Пути в matugen всегда
переписываются на абсолютный путь репозитория, поэтому для перекраски `--link`
не нужен; он нужен только для того, чтобы обычные `quickshell` и `qs ipc`
находили конфиг.

Проверка окружения в любой момент:

```sh
./install.sh --check     # ничего не пишет
qs ipc show              # живые IPC-цели запущенной оболочки
qs log                   # stderr запущенного экземпляра
```

### Ручная установка

Этот путь — если хотите видеть каждое изменение (или вы не на Arch).

#### 1. Клонирование

```sh
git clone https://github.com/cactozs/quickshell.git ~/.config/quickshell
```

Quickshell считает `~/.config/quickshell` своим каталогом конфига по умолчанию.
Если клонировать в другое место, сделайте симлинк:

```sh
ln -s /путь/к/quickshell ~/.config/quickshell
```

или запускайте `quickshell -p /путь/к/quickshell` и используйте `toggleOn`, как
показано в разделе [горячие клавиши](#горячие-клавиши).

#### 2. Пакеты

```sh
sudo pacman -S --needed \
  quickshell niri matugen awww \
  fd ripgrep jq curl cliphist wl-clipboard brightnessctl \
  pipewire wireplumber upower power-profiles-daemon networkmanager \
  ttf-material-symbols-variable ttf-nerd-fonts-symbols ttf-jetbrains-mono-nerd \
  alacritty gtk3 gtk4 qt6ct ghostty \
  imagemagick wlsunset playerctl
```

Опционально:

```sh
sudo pacman -S papirus-icon-theme   # иконки приложений; hicolor тянет quickshell
sudo pacman -S nvidia-utils         # строки GPU на NVIDIA; AMD не требует пакета
```

`imagemagick` нужен только для превью обоев 720 px. Без него менеджер грузит
оригиналы: для 4K это медленно, но работает.

#### 3. Шрифты

Material Symbols и Symbols Nerd Font есть в pacman:

```sh
sudo pacman -S ttf-material-symbols-variable ttf-nerd-fonts-symbols ttf-jetbrains-mono-nerd
```

У основного шрифта интерфейса, **Google Sans**, нет пакета в Arch:

```sh
mkdir -p ~/.local/share/fonts
curl -L -o ~/.local/share/fonts/GoogleSans.ttf \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/googlesans/GoogleSans%5BGRAD%2Copsz%2Cwght%5D.ttf"
fc-cache -f
fc-match "Google Sans"        # должен напечатать Google Sans, не fallback
```

Режим **Monospace** в настройках — это **JetBrainsMono Nerd Font Mono** из
`ttf-jetbrains-mono-nerd`. Если шрифта нет, моноширинный режим откатится на
обычный sans.

#### 4. matugen

Оболочка читает цвета из `style/Colors.json` (тёмная) и
`style/ColorsLight.json` (светлая). Их пишет matugen. Конфиги лежат в
репозитории в `install/matugen/`:

```sh
mkdir -p ~/.config/matugen
cp -r install/matugen/. ~/.config/matugen/
```

Затем отредактируйте `~/.config/matugen/config.toml`:

```toml
[config]
version_check = false
source_color_index = 0
fallback_color = "#6750A4"

[config.wallpaper]
set = true
command = "/usr/bin/awww img --transition-type center {{ image }}"

[templates.quickshell]
input_path = "/home/you/.config/matugen/templates/quickshell.json"
output_path = "/home/you/.config/quickshell/style/Colors.json"
type = "SchemeContent"
```

`light.toml` — тот же шаблон с выводом в `ColorsLight.json` и **без**
`[config.wallpaper]`: перегенерация светлых цветов не должна заново ставить
обои. matugen берёт режим только из командной строки, поэтому светлый проход —
отдельный вызов `matugen -m light`.

Сгенерировать первую палитру из любой картинки:

```sh
matugen image ~/Pictures/Wallpapers/ваши-обои.png
```

Абсолютный путь в `command` важен. Шим в `/usr/local/bin/awww` вызывает
`matugen image`, а команда обоев в matugen вызывает `/usr/bin/awww`; относительный
`awww` там зациклился бы.

#### 5. Шим для awww

`awww img <файл>` должен идти через matugen, иначе цвета не будут следовать за
обоями. `/usr/local/bin` идёт раньше `/usr/bin` в обычном PATH:

```sh
sudo install -Dm755 install/awww /usr/local/bin/awww
command -v awww               # должен напечатать /usr/local/bin/awww
```

Шим перехватывает только простой `awww img <существующий-файл>`. `query`,
`restore`, `pause`, лишние флаги и цвета уходят напрямую в `/usr/bin/awww`.

#### 6. niri

Создайте генерируемый файл до include, иначе niri не запустится:

```sh
touch ~/.config/niri/quickshell.kdl
```

`~/.config/niri/config.kdl` — include должен идти после `layout.kdl`, потому что
niri сливает include позиционно, и сгенерированные цвета границ должны
применяться позже:

```kdl
include "layout.kdl"
include "quickshell.kdl"
```

`~/.config/niri/autostart.kdl`:

```kdl
spawn-at-startup "quickshell"
spawn-at-startup "awww-daemon"
spawn-at-startup "sh" "-c" "wl-paste --type text --watch cliphist store"
spawn-at-startup "sh" "-c" "wl-paste --type image --watch cliphist store"
```

Блокировка по простою, выключение мониторов и блокировка перед сном теперь
внутри оболочки.

Если Quickshell уже запускается с переменными окружения, оставьте эту строку
вместо второй. Например:

```kdl
spawn-at-startup "sh" "-c" "env QT_QUICK_BACKEND=software quickshell"
```

`~/.config/niri/environment.kdl`:

```kdl
environment {
    QT_QPA_PLATFORMTHEME "qt6ct"
}
```

#### 7. ghostty и Qt

`~/.config/ghostty/config`:

```ini
theme = Quickshell
```

`~/.config/qt6ct/qt6ct.conf` (создайте, если у qt6ct ещё нет конфига):

```ini
[Appearance]
color_scheme_path=/home/you/.config/qt6ct/colors/matugen.conf
custom_palette=true
```

Файл, на который указывает этот путь, оболочка создаст при первом запуске.
Qt-приложения читают палитру при старте, поэтому после смены темы их нужно
перезапустить. ghostty оболочка перезагружает через `SIGUSR2`.

Пункт **«Блокировка»** в меню питания запускает `qs ipc call lock lock`; ту же
команду можно повесить на клавишу. Встроенный экран блокировки показывает
текущие обои под затемнением и карточку с часами, датой, пользователем и полем
пароля. Это настоящий `ext-session-lock-v1`, пароль проверяется через системный
стек PAM `login`, поэтому отдельный локер и правки `/etc/pam.d` не нужны.

Оболочка блокируется сама после 5 минут простоя, выключает мониторы через 7,5
(любой ввод их включает) и блокируется перед сном по сигналу logind
`PrepareForSleep`, удерживая delay-ингибитор, пока лок не поднимется. `swayidle`
не нужен. IPC для разблокировки намеренно нет — блокировку снимает только
пароль.

#### 8. Обои, погода и терминал

```sh
mkdir -p ~/Pictures/Wallpapers
```

Положите туда картинки. Брошенный на пустой рабочий стол или панель файл тоже
станет обоями.

Что менять под себя:

| что | где | по умолчанию |
|---|---|---|
| каталог обоев | `services/Wallpapers.qml` → `rootDir` | `~/Pictures/Wallpapers` |
| координаты погоды | `services/Weather.qml` → `lat`, `lon` | Москва (`55.75`, `37.62`) |
| терминал для `.desktop` | `$TERMINAL`, затем `modules/Launcher.qml` | `alacritty` |

`$TERMINAL` делится по пробелам, поэтому `TERMINAL="ghostty --class=foo"` тоже
работает.

#### 9. Запуск

```sh
quickshell
```

Сначала запускайте в терминале. Сборки и тестов нет: ошибки QML появляются в
stderr, а оболочка сама перезагружается при изменении файлов. GitHub Actions
запускает `qmllint`, `bash -n install.sh` и `python3 scripts/check-qml.py` на
push и pull request. Когда всё работает, оставьте строку автозапуска в niri и
остановите ручной экземпляр.

## Горячие клавиши

Положите это в `~/.config/niri/keybinds.kdl`. Это вызовы `qs ipc`, поэтому
оболочка должна быть запущена. `toggleOn` открывает панель на мониторе в фокусе;
для него нужны `niri` и `jq`.

```kdl
Mod+A       repeat=false { spawn-sh "qs ipc call launcher toggleOn $(niri msg --json focused-output | jq -r .name)"; }
Mod+V       repeat=false { spawn-sh "qs ipc call clipboard toggleOn $(niri msg --json focused-output | jq -r .name)"; }
Mod+N       repeat=false { spawn-sh "qs ipc call center toggleOn $(niri msg --json focused-output | jq -r .name)"; }
Mod+Ctrl+W  repeat=false { spawn-sh "qs ipc call wallpaper toggleOn $(niri msg --json focused-output | jq -r .name)"; }
Mod+Shift+N repeat=false { spawn "qs" "ipc" "call" "notifs" "toggleDnd"; }
Mod+P       repeat=false { spawn "qs" "ipc" "call" "bar" "toggle"; }
Mod+Alt+L   repeat=false { spawn "qs" "ipc" "call" "lock" "lock"; }
```

Без niri/jq замените `toggleOn $(…)` на `toggle`; панель откроется на первом
экране. Esc и клик снаружи закрывают открытую панель.

Громкость, яркость и медиа не идут через оболочку: используйте `wpctl`,
`brightnessctl` и `playerctl` напрямую. Блокировка идёт:
`qs ipc call lock lock`.

## IPC

`qs ipc show` печатает живой список. У оверлеев есть `toggle`,
`toggleOn <output>` и `close`; `bar` и `notifs` — отдельные цели:

| цель | дополнительные функции |
|---|---|
| `launcher` | — |
| `clipboard` | — |
| `center` (уведомления) | — |
| `tray` | — |
| `weather` | — |
| `clock` (таймер и секундомер) | — |
| `system` (мониторинг) | — |
| `settings` (быстрые настройки) | `launcherView <bool>`, `style <m3\|blur\|new\|nothing\|newNothing>`, `colorscheme <matugen\|oled\|gruvbox>`, `theme <dark\|light>`, `font <material\|mono>`, `blur <wallpaper\|window>`, `ambient <off\|xmas>`, `language <ru\|en\|de>` |
| `wallpaper` (менеджер) | `random` |
| `pet` (питомец) | — |
| `lock` (экран блокировки) | `lock` |
| `bar` | `toggle` |
| `notifs` | `toggleDnd`, `dnd`, `clear`, `mute <app>`, `unmuteAll` |

`<output>` — имя монитора (`"eDP-1"`, см. `niri msg outputs`), не номер.
Примеры:

```sh
qs ipc call launcher toggle
qs ipc call settings theme light
qs ipc call settings colorscheme gruvbox
qs ipc call settings style new
qs ipc call wallpaper random
qs ipc call notifs toggleDnd
qs ipc call lock lock
```

## Темы

Палитрой владеет оболочка, а `services/SystemTheme.qml` — единственное место,
которое пишет файлы:

- `~/.config/gtk-3.0/gtk.css` и `~/.config/gtk-4.0/gtk.css`
- `~/.config/ghostty/themes/Quickshell` (перезагрузка через `pkill -USR2 -x ghostty`)
- `~/.config/qt6ct/colors/matugen.conf`
- `~/.config/niri/quickshell.kdl` — цвета границ и focus-ring niri плюс
  `layer-rule`, который выбирает источник блюра
- `gsettings set org.gnome.desktop.interface color-scheme …`

Файл пишется, только если содержимое изменилось. Ручные правки живут до
следующей смены темы, потом файл перегенерируется.

Какие из этих целей писать вообще, решает вкладка «Приложения» в настройках
(или `qs ipc call settings app ghostty false`). Выключенная цель не трогается:
её файл остаётся с теми цветами, что получил в последний раз.

**Светлая тема** — второй проход matugen. Оболочка запускает
`matugen -m light image <обои> -c ~/.config/matugen/light.toml`, когда тёмная
палитра новее `ColorsLight.json`. В обоих конфигах должны совпадать настройки
исходного цвета; в `light.toml` намеренно нет команды установки обоев.

**Блюр** — политика niri. «Обои» (по умолчанию) — это xray-блюр niri: только
обои. «Окна» пишет `xray false` в сгенерированный `layer-rule`, и окна под
акриловыми плашками тоже размываются. Выбор читается из
`~/.config/niri/quickshell.kdl` при старте оболочки, поэтому переживает
перезагрузку.

**Стили** переключаются в меню настроек или через
`qs ipc call settings style …`. `M3 Inspired` — палитра matugen с формами M3,
`M3 Blur` добавляет акрил и блюр композитора, `New` — графитовый акрил,
`Nothing` — непрозрачный графит с жёсткими углами, а `New Nothing` — тот же
графит и те же углы с акриловой отделкой `New`: рамка, блик, тень и блюр.

## Настройка

| что | файл / ключ |
|---|---|
| оверлеи и экраны | `shell.qml` (`Variants` по `Quickshell.screens`) |
| каталог обоев | `services/Wallpapers.qml` → `rootDir` |
| город погоды | `services/Weather.qml` → `lat`, `lon` |
| терминал | `$TERMINAL`; fallback в `modules/Launcher.qml` |
| шрифты | `style/Theme.qml` → `fontFamily`, `iconFont`, `nerdFont` |
| переводы интерфейса | `services/I18n.qml` |
| стиль, палитра, тема, шрифт, язык | меню настроек или `qs ipc call settings …` |
| конфиги matugen | `~/.config/matugen/config.toml`, `light.toml` |
| сгенерированные цвета niri | `~/.config/niri/quickshell.kdl` |
| запись темы рабочего стола | `services/SystemTheme.qml` |
| системная статистика | `services/SystemMonitor.qml` |
| уведомления | `services/Notifications.qml` |
| закреплённые записи буфера | `services/ClipboardPins.qml` (каталог данных оболочки) |
| IPC-обработчики | `services/ShellState.qml` |

`launcher-usage.json`, `notifications.json`, `wallpaper-favorites.json`,
`shell-state.json` и `.qmlls.ini` — локальное состояние, оно в `.gitignore`.
`style/Colors.json` и `style/ColorsLight.json` —
сгенерированные палитры, но они лежат в git, чтобы свежий клон имел рабочий
fallback до первого запуска matugen.

## Питомец

Кнопка с лапой в панели показывает Тукса на своём экране (`qs ipc call pet
toggle` для бинда). Его можно перетащить куда угодно — место сохраняется.
Клик открывает чат, двойной клик гладит, а после пяти минут бездействия он
засыпает. Пока в фокусе полноэкранное окно, окно питомца скрыто.

Отвечает NVIDIA NIM (`integrate.api.nvidia.com`), а про время, дату, погоду и
батарею оболочка отвечает сама. Ключ читается из `NVIDIA_API_KEY` в окружении
оболочки; поля для ключа в настройках нет:

```fish
set -Ux NVIDIA_API_KEY nvapi-...
```

Переменную оболочка получает при запуске, поэтому после экспорта её нужно
перезапустить.

Питомец помнит последние реплики и умеет три инструмента:

- `run_diagnostic` — одна команда только на чтение: ядро, свободное место,
  диски, память, адреса сети, упавшие юниты systemd, последние строки
  `qs log` или список папки внутри домашнего каталога. Скрытые папки и всё
  вне `$HOME` отклоняются; `cat`, `find` и шелла там нет.
- `grep_shell` — поиск по этому репозиторию с ответом `файл:строка`, так что
  вопросы про конфиг проверяются по реальным файлам, а не по догадкам.
- `shell_action` — открыть панель, сменить тему, изменить громкость, выключить
  звук или сделать скриншот. Выполняется только по просьбе.

Каждый вопрос, вывод команд и имена файлов из `ls` уходят в NVIDIA. Без
ключа питомец по-прежнему отвечает на локальные вопросы.

## Если что-то не работает

| симптом | причина | что делать |
|---|---|---|
| текст обычным sans | нет Google Sans | установите шрифт (шаг 3), затем `fc-cache -f` |
| вместо иконок квадраты | нет Material Symbols | `sudo pacman -S ttf-material-symbols-variable` |
| панель осталась фиолетовой | matugen не запускался или `output_path` ведёт не туда | исправьте `~/.config/matugen/config.toml`, запустите `matugen image <файл>` |
| обои меняются, цвета нет | шим `awww` не установлен или перекрыт | `command -v awww` должен печатать `/usr/local/bin/awww`; переустановите шим |
| `awww img` ничего не делает | не запущен `awww-daemon` | добавьте `spawn-at-startup "awww-daemon"` |
| панель открывается не на том мониторе | в бинде `toggle` | используйте `toggleOn $(niri msg --json focused-output \| jq -r .name)` |
| блюр не работает | нет include в niri или стиль не рисует акрил | шаг 6; попробуйте `M3 Blur` и «Окна» |
| Qt-приложения не меняют цвета | Qt читает палитру при старте | перезапустите их |
| светлая тема не обновляется | нет `light.toml` или `ColorsLight.json` устарел | перезапустите `./install.sh`, затем смените обои |
| `qs ipc` не подключается | оболочка не запущена или репозиторий в другом месте | `qs ipc show`; `./install.sh --link` или `quickshell -p <путь>` |
| оболочка не запускается | ошибка QML | запустите `quickshell` в терминале и прочитайте stderr; `qs log` для запущенного экземпляра |

Если правите QML, держите открытым терминал с `quickshell`. Синтаксическая
ошибка оставляет на экране предыдущий конфиг и печатает файл и строку в лог.

## Обновление

```sh
cd ~/.config/quickshell
git pull --ff-only
./install.sh
```

Установщик перепишет пути matugen, если репозиторий переехал, и тронет конфиг,
только если содержимое отличается или чего-то не хватает. Если вы используете
`--no-apply`, сравните `install/matugen/` с `~/.config/matugen/` и сниппеты из
этого README вручную.

## Удаление

Сначала остановите оболочку и уберите строку автозапуска:

```sh
pkill -x quickshell
```

Затем удалите то, что больше не нужно:

```sh
sudo rm /usr/local/bin/awww             # если есть awww.bak.*, верните его
rm -rf ~/.config/quickshell             # репозиторий
rm -rf ~/.config/matugen                # конфиги matugen
rm -f  ~/.config/niri/quickshell.kdl
rm -f  ~/.config/ghostty/themes/Quickshell
rm -f  ~/.config/qt6ct/colors/matugen.conf
rm -f  ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css
```

Уберите `include "quickshell.kdl"` и строки автозапуска из niri вручную.
Бэкапы установщика лежат рядом с исходными файлами как
`*.bak.ГГГГММДД-ЧЧММСС.PID`. Библиотека обоев и установленные пакеты не
трогаются.

## Благодарности

- [Quickshell](https://quickshell.org/) — тулкит оболочки и `qs` IPC.
- [niri](https://github.com/YaLTeR/niri) — композитор, под который всё сделано.
- [matugen](https://github.com/InioX/matugen) — палитры Material You из картинок.
- [awww](https://codeberg.org/LGFae/awww) — демон обоев.
- [Google Sans](https://fonts.google.com/specimen/Google+Sans) и
  [Material Symbols](https://fonts.google.com/icons) — шрифты OFL.
- Material 3 Expressive — язык форм, цвета и анимаций.
- QML, установщик и документация написаны с помощью ИИ и проверены
  [cactozs](https://github.com/cactozs).

## Лицензия

MIT. См. [LICENSE](LICENSE).
