pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// Quick settings panel (GNOME/Android style): sliders for brightness and
// volume, tiles for Wi-Fi / do-not-disturb / night light, a media player row
// and a collapsed "power" list with the six session actions. Opened from the
// bar's power button, dismissed by Esc or a click outside.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.quickSettingsScreen === root.modelData.name

    readonly property int cardWidth: 400
    readonly property int cardPadding: 16
    readonly property int netRowHeight: 48
    readonly property int netListMaxHeight: 5 * root.netRowHeight + 2 * 4

    // ---- Wi-Fi -----------------------------------------------------------------

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi)
                return d;
        }
        return null;
    }

    readonly property bool wifiEnabled: root.wifiDevice !== null && Networking.wifiEnabled

    // Sorted connected -> known -> strongest signal. Recomputed on open and on
    // model changes, but not on every signal update, so rows don't jump.
    readonly property var networkList: {
        if (!root.shown)
            return [];
        const nets = root.wifiDevice ? root.wifiDevice.networks.values : [];
        return nets.slice().sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
    }

    readonly property string wifiSubtitle: {
        if (!root.wifiEnabled)
            return I18n.t("Выключен");
        const conn = root.networkList.find(n => n.connected);
        return conn ? conn.name : I18n.t("Включён");
    }

    property bool wifiExpanded: false
    property var pskTarget: null
    property string wifiError: ""
    property var forgetArmed: null

    function failText(reason: var): string {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "нужен пароль";
        case ConnectionFailReason.WifiAuthTimeout:
            return "неверный пароль или таймаут";
        case ConnectionFailReason.WifiClientFailed:
            return "ошибка аутентификации";
        case ConnectionFailReason.WifiClientDisconnected:
            return "соединение разорвано";
        case ConnectionFailReason.WifiNetworkLost:
            return "сеть пропала";
        default:
            return "неизвестная ошибка";
        }
    }

    function activateNetwork(net: var): void {
        root.wifiError = "";
        if (net.connected) {
            net.disconnect();
            return;
        }
        if (net.state === ConnectionState.Connecting)
            return;
        if (net.known || net.security === WifiSecurityType.Open) {
            net.connect();
            return;
        }
        root.pskTarget = net;
        pskInput.text = "";
        pskFocus.restart();
    }

    function submitPsk(): void {
        if (root.pskTarget !== null && pskInput.text.length > 0) {
            root.wifiError = "";
            root.pskTarget.connectWithPsk(pskInput.text);
        }
    }

    function forgetNetwork(net: var): void {
        if (root.forgetArmed === net) {
            net.forget();
            root.forgetArmed = null;
            forgetTimer.stop();
        } else {
            root.forgetArmed = net;
            forgetTimer.restart();
        }
    }

    // ---- media player (MPRIS) --------------------------------------------------

    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }

    // ---- power actions (was the fullscreen PowerMenu) --------------------------

    readonly property var powerActions: [
        {
            icon: Theme.iconPower,
            label: I18n.t("Выключение"),
            keys: ["s", "ы"],
            command: ["systemctl", "poweroff"],
            container: Theme.errorContainer,
            content: Theme.errorContainerText
        },
        {
            icon: Theme.iconRestart,
            label: I18n.t("Перезагрузка"),
            keys: ["r", "к"],
            command: ["systemctl", "reboot"],
            container: Theme.primaryContainer,
            content: Theme.primaryContainerText
        },
        {
            icon: Theme.iconLogout,
            label: I18n.t("Выход"),
            keys: ["e", "у"],
            command: ["niri", "msg", "action", "quit", "--skip-confirmation"],
            container: Theme.secondaryContainer,
            content: Theme.secondaryContainerText
        },
        {
            icon: Theme.iconHibernate,
            label: I18n.t("Гибернация"),
            keys: ["h", "р"],
            command: ["systemctl", "hibernate"],
            container: Theme.tertiaryContainer,
            content: Theme.tertiaryContainerText
        },
        {
            icon: Theme.iconLock,
            label: I18n.t("Блокировка"),
            keys: ["l", "д"],
            command: ["qs", "ipc", "call", "lock", "lock"],
            container: Theme.surfaceContainerHighest,
            content: Theme.surfaceText
        },
        {
            icon: Theme.iconSuspend,
            label: I18n.t("Сон"),
            keys: ["u", "г"],
            command: ["systemctl", "suspend"],
            container: Theme.primary,
            content: Theme.primaryText
        }
    ]

    property bool powerExpanded: false

    // Focus lands on Lock when the list expands: a stray Enter must not power
    // the machine off.
    readonly property int defaultPowerIndex: root.powerActions.findIndex(a => a.icon === Theme.iconLock)
    property int currentPowerIndex: 0

    function movePowerFocus(delta: int): void {
        const n = root.powerActions.length;
        root.currentPowerIndex = ((root.currentPowerIndex + delta) % n + n) % n;
    }

    function activatePower(index: int): void {
        ShellState.closeQuickSettings();
        Quickshell.execDetached(root.powerActions[index].command);
    }

    function activatePowerByLetter(ch: string): bool {
        for (let i = 0; i < root.powerActions.length; i++) {
            if (root.powerActions[i].keys.includes(ch)) {
                root.activatePower(i);
                return true;
            }
        }
        return false;
    }

    // ---- panel window ----------------------------------------------------------

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: root.shown || card.opacity > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:quicksettings"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Acrylic behind the panel (New and Blur). Off as soon as it closes: a
    // compositor blur region cannot fade, so it would hang under the card.
    BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurRegion : null

    // Unscaled twin of the card for the blur region: it only rebuilds on
    // x/y/w/h changes, so it must not see the entrance scale.
    Item {
        id: blurAnchor
        anchors.fill: card
    }

    Region {
        id: blurRegion

        Region { item: blurAnchor; radius: card.radius }
    }

    // What opening the panel does. A lazily built window (LazyOverlay) is born
    // already open, so its onShownChanged never fires; both paths call this.
    function openInit(): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = true;
        NightLight.recheck();
        focusKick.restart();
    }

    Component.onCompleted: {
        if (root.shown)
            root.openInit();
    }

    onShownChanged: {
        if (root.shown) {
            root.openInit();
        } else {
            if (root.wifiDevice)
                root.wifiDevice.scannerEnabled = false;
            root.powerExpanded = false;
            root.wifiExpanded = false;
            root.pskTarget = null;
            root.wifiError = "";
            root.forgetArmed = null;
            forgetTimer.stop();
        }
    }

    onWifiDeviceChanged: {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = root.shown;
    }

    onWifiEnabledChanged: {
        if (!root.wifiEnabled)
            root.pskTarget = null;
    }

    // Layer surfaces take a moment to gain keyboard focus; make sure the key
    // catcher ends up active either way.
    Timer {
        id: focusKick
        interval: 50
        onTriggered: keyCatcher.forceActiveFocus()
    }

    Timer {
        id: pskFocus
        interval: 50
        onTriggered: pskInput.forceActiveFocus()
    }

    Timer {
        id: forgetTimer
        interval: 3000
        onTriggered: root.forgetArmed = null
    }

    // click outside the card dismisses the panel
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeQuickSettings()
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.pskTarget !== null)
                    root.pskTarget = null;
                else
                    ShellState.closeQuickSettings();
                event.accepted = true;
                return;
            }
            if (!root.powerExpanded)
                return;
            switch (event.key) {
            case Qt.Key_Up:
                root.movePowerFocus(-1);
                break;
            case Qt.Key_Down:
                root.movePowerFocus(1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.activatePower(root.currentPowerIndex);
                break;
            default: {
                // In a cyrillic layout the letter arrives as Qt.Key_Cyrillic_*,
                // so also match event.text against the action's `keys`.
                const ch = event.text.toLowerCase();
                if (ch.length === 1)
                    root.activatePowerByLetter(ch);
            }
            }
            event.accepted = true;
        }
    }

    // Ambient shadow under the panel (New style only); follows the card's
    // entrance fade/scale.
    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: Theme.glass
        opacity: card.opacity
        scale: card.scale
    }

    Rectangle {
        id: card

        // Opens against the bar's edge: under a top bar, above a bottom one,
        // beside a rail.
        anchors.top: Theme.popupBottom ? undefined : parent.top
        anchors.bottom: Theme.popupBottom ? parent.bottom : undefined
        anchors.left: Theme.popupLeft ? parent.left : undefined
        anchors.right: Theme.popupLeft ? undefined : parent.right
        anchors.topMargin: Theme.popupTopMargin
        anchors.bottomMargin: Theme.popupBottomMargin
        anchors.leftMargin: Theme.popupLeftMargin
        anchors.rightMargin: Theme.popupRightMargin

        width: root.cardWidth
        height: column.implicitHeight + 2 * root.cardPadding
        radius: Theme.shapeXL
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        scale: root.shown ? 1 : 0.92
        opacity: root.shown ? 1 : 0

        // M3E panel entrance: springy scale under a faster fade.
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasizedDecelerate
            }
        }

        // Swallow clicks on the card so they don't reach the dismiss area.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.cardPadding
            }

            spacing: 8

            // ---- brightness slider ----------------------------------------------

            Row {
                id: brightnessRow

                width: parent.width
                spacing: 10
                visible: Brightness.deviceFound

                Item {
                    width: 32
                    height: 32

                    Text {
                        anchors.centerIn: parent
                        text: Brightness.icon
                        color: Theme.tertiary
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSizeMedium
                    }
                }

                QsSlider {
                    id: brightnessSlider

                    anchors.verticalCenter: parent.verticalCenter
                    width: brightnessRow.width - 32 - 40 - 20

                    property real dragValue: -1

                    value: dragValue >= 0 ? dragValue : Brightness.percent / 100

                    onMoved: v => dragValue = v
                    onCommitted: v => {
                        dragValue = -1;
                        Brightness.setPercent(v * 100);
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: Math.round(brightnessSlider.value * 100) + "%"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignRight
                }
            }

            // ---- volume slider ---------------------------------------------------

            Row {
                id: volumeRow

                width: parent.width
                spacing: 10
                visible: Audio.sink !== null

                Item {
                    width: 32
                    height: 32

                    Text {
                        anchors.centerIn: parent
                        text: Audio.icon
                        color: Audio.effectiveMuted ? Theme.surfaceVariantText : Theme.primary
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSizeMedium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute()
                    }
                }

                QsSlider {
                    id: volumeSlider

                    anchors.verticalCenter: parent.verticalCenter
                    width: volumeRow.width - 32 - 40 - 20

                    value: Audio.effectiveMuted ? 0 : Audio.volume
                    handleColor: Audio.effectiveMuted ? Theme.surfaceVariantText : Theme.sliderColor

                    onMoved: v => {
                        if (Audio.sink?.ready && Audio.sink?.audio) {
                            Audio.sink.audio.muted = false;
                            Audio.sink.audio.volume = v;
                        }
                    }
                    onCommitted: v => Audio.setVolume(v)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: Math.round(volumeSlider.value * 100) + "%"
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignRight
                }
            }

            // ---- tiles -------------------------------------------------------------

            Grid {
                id: tileGrid

                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                readonly property real tileWidth: (width - columnSpacing) / 2

                QsTile {
                    width: tileGrid.tileWidth
                    visible: root.wifiDevice !== null
                    icon: root.wifiEnabled ? Theme.iconWifi : Theme.iconWifiOff
                    title: "Wi-Fi"
                    subtitle: root.wifiSubtitle
                    active: root.wifiEnabled
                    hasDetails: true
                    detailsExpanded: root.wifiExpanded

                    onActivated: Networking.wifiEnabled = !root.wifiEnabled
                    onDetailsToggled: root.wifiExpanded = !root.wifiExpanded
                }

                QsTile {
                    width: tileGrid.tileWidth
                    visible: Audio.sink !== null
                    icon: Theme.iconSpeaker
                    title: I18n.t("Выход")
                    subtitle: Audio.sinkName !== "" ? Audio.sinkName : I18n.t("Нет устройства")

                    onActivated: Audio.cycleSink()
                }

                QsTile {
                    width: tileGrid.tileWidth
                    visible: Audio.source !== null
                    icon: Audio.micMuted ? Theme.iconMicOff : Theme.iconMic
                    title: I18n.t("Микрофон")
                    subtitle: Audio.micMuted ? I18n.t("Без звука") : I18n.t("Включён")
                    active: !Audio.micMuted

                    onActivated: Audio.toggleMicMute()
                }

                QsTile {
                    width: tileGrid.tileWidth
                    icon: Theme.iconDnd
                    title: I18n.t("Не беспокоить")
                    active: Notifications.dnd

                    onActivated: Notifications.toggleDnd()
                }

                QsTile {
                    width: tileGrid.tileWidth
                    visible: NightLight.available
                    icon: Theme.iconNightlight
                    title: I18n.t("Ночной свет")
                    active: NightLight.enabled

                    onActivated: NightLight.toggle()
                }

                QsTile {
                    width: tileGrid.tileWidth
                    icon: Theme.iconSettings
                    title: I18n.t("Настройки")

                    onActivated: {
                        ShellState.closeQuickSettings();
                        ShellState.toggleSettings(root.modelData.name);
                    }
                }
            }

            // ---- wi-fi network list -------------------------------------------------

            Rectangle {
                id: wifiListBox

                width: parent.width
                visible: root.wifiExpanded || height > 0.5
                height: root.wifiExpanded ? wifiColumn.implicitHeight + 16 : 0
                radius: Theme.shapeLG
                color: Theme.surfaceContainerLow
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasizedDecelerate
                    }
                }

                Column {
                    id: wifiColumn

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 8
                    }

                    spacing: 2

                    Text {
                        width: parent.width
                        visible: !root.wifiEnabled
                        text: I18n.t("Wi-Fi выключен")
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelLarge
                    }

                    Text {
                        width: parent.width
                        visible: root.wifiEnabled && root.networkList.length === 0
                        text: I18n.t("Поиск сетей…")
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabelLarge
                    }

                    ListView {
                        id: netList

                        reuseItems: true

                        width: parent.width
                        visible: root.wifiEnabled
                        implicitHeight: root.networkList.length * (root.netRowHeight + 2) - 2
                        height: Math.min(implicitHeight, root.netListMaxHeight)
                        clip: true
                        model: root.networkList
                        spacing: 2

                        delegate: NetworkRow {}
                    }

                    // password prompt for a new secured network
                    Item {
                        width: parent.width
                        visible: root.pskTarget !== null || implicitHeight > 0.5
                        implicitHeight: root.pskTarget !== null ? 40 : 0
                        opacity: root.pskTarget !== null ? 1 : 0
                        clip: true

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveEmphasizedDecelerate
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveEmphasizedDecelerate
                            }
                        }

                        Rectangle {
                            id: pskField

                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.right: pskConnect.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: 32
                            radius: Theme.shapeFull
                            color: Theme.surfaceContainerHighest

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: pskInput.text.length === 0
                                text: I18n.t("Пароль")
                                color: Theme.surfaceVariantText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabelLarge
                            }

                            TextInput {
                                id: pskInput

                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                echoMode: TextInput.Password
                                color: Theme.surfaceText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabelLarge
                                selectByMouse: true
                                selectionColor: Theme.primary
                                selectedTextColor: Theme.primaryText

                                onAccepted: root.submitPsk()

                                // The catcher is a sibling, not an ancestor;
                                // key events from this field never reach it.
                                Keys.onEscapePressed: {
                                    root.pskTarget = null;
                                    keyCatcher.forceActiveFocus();
                                }
                            }
                        }

                        Text {
                            id: pskConnect

                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("Подключить")
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelLarge
                            font.weight: Font.Medium

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitPsk()
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        visible: root.wifiError !== "" || implicitHeight > 0.5
                        implicitHeight: root.wifiError !== "" ? errorText.implicitHeight : 0
                        opacity: root.wifiError !== "" ? 1 : 0
                        clip: true

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveEmphasizedDecelerate
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveEmphasizedDecelerate
                            }
                        }

                        Text {
                            id: errorText

                            width: parent.width
                            text: root.wifiError !== "" ? I18n.t("Не удалось подключиться: ") + I18n.t(root.wifiError) : ""
                            color: Theme.error
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelMedium
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ---- media player -------------------------------------------------------

            Rectangle {
                id: mediaRow

                width: parent.width
                // Collapses smoothly when the player goes away; stays mapped
                // while the height animates (same pattern as wifiListBox).
                visible: root.player !== null || height > 0.5
                height: root.player !== null ? 56 : 0
                opacity: root.player !== null ? 1 : 0
                radius: Theme.shapeLG
                color: Theme.surfaceContainerHighest

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasizedDecelerate
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasizedDecelerate
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 6

                    ClippingRectangle {
                        id: art

                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: Theme.shapeMD
                        color: Theme.surfaceContainerHigh

                        Image {
                            id: artImage

                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 80
                            sourceSize.height: 80
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !artImage.visible
                            text: Theme.iconMusic
                            color: Theme.surfaceVariantText
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSizeMedium
                        }
                    }

                    Row {
                        id: mediaButtons

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        MiniIconButton {
                            icon: Theme.iconPrevious
                            opacity: root.player?.canGoPrevious ? 1 : Theme.disabledContent
                            onClicked: {
                                if (root.player?.canGoPrevious)
                                    root.player.previous();
                            }
                        }

                        MiniIconButton {
                            icon: root.player?.isPlaying ? Theme.iconPause : Theme.iconPlay
                            opacity: root.player?.canTogglePlaying ? 1 : Theme.disabledContent
                            onClicked: {
                                if (root.player?.canTogglePlaying)
                                    root.player.togglePlaying();
                            }
                        }

                        MiniIconButton {
                            icon: Theme.iconNext
                            opacity: root.player?.canGoNext ? 1 : Theme.disabledContent
                            onClicked: {
                                if (root.player?.canGoNext)
                                    root.player.next();
                            }
                        }
                    }

                    Column {
                        anchors.left: art.right
                        anchors.leftMargin: 10
                        anchors.right: mediaButtons.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: root.player?.trackTitle ?? ""
                            color: Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitleMedium
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.player?.trackArtist ?? ""
                            color: Theme.surfaceVariantText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabelMedium
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ---- power section (collapsed by default) --------------------------------

            Rectangle {
                id: powerHeader

                width: parent.width
                height: 48
                radius: Theme.shapeMD
                color: "transparent"

                StateLayer {
                    hovered: powerHover.hovered
                    pressed: powerTap.pressed
                    color: Theme.surfaceText
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Питание")
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitleMedium
                    font.weight: Font.Medium
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.iconExpandMore
                    color: Theme.surfaceVariantText
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSize
                    rotation: root.powerExpanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveEmphasized
                        }
                    }
                }

                MouseArea {
                    id: powerTap

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.powerExpanded = !root.powerExpanded;
                        if (root.powerExpanded)
                            root.currentPowerIndex = root.defaultPowerIndex;
                    }
                }

                HoverHandler {
                    id: powerHover
                }
            }

            Column {
                id: powerList

                width: parent.width
                spacing: 4
                height: root.powerExpanded ? implicitHeight : 0
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasizedDecelerate
                    }
                }

                Repeater {
                    model: root.powerActions

                    PowerRow {
                        focused: root.currentPowerIndex === index

                        onActivated: root.activatePower(index)
                    }
                }
            }
        }
    }

    // ---- inline components -----------------------------------------------------------

    // Large toggle tile: icon + title (+ subtitle), tonal when active; an
    // M3E shape morph on press and an optional right-side chevron toggling a
    // details section.
    component QsTile: Rectangle {
        id: tile

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property bool hasDetails: false
        property bool detailsExpanded: false

        signal activated
        signal detailsToggled

        implicitHeight: 64
        // New rests squarer than the M3 tile and pulls the corners in on press.
        radius: Theme.glass
            ? (tileTap.pressed ? Theme.shapeSM : Theme.shapeMD)
            : (tileTap.pressed ? Theme.shapeLGI : Theme.shapeXL)
        color: tile.active ? Theme.primaryContainer : Theme.surfaceContainerHighest
        scale: tileTap.pressed ? 0.98 : 1

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durMorph
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durMedium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveEmphasized
            }
        }

        StateLayer {
            hovered: tileHover.hovered
            pressed: tileTap.pressed
            color: tile.active ? Theme.primaryContainerText : Theme.surfaceText
        }

        GlassEdge {
            visible: Theme.old
            sunken: tileTap.pressed
        }

        Item {
            anchors.fill: parent
            anchors.margins: 12

            Text {
                id: tileIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: tile.icon
                color: tile.active ? Theme.primaryContainerText : Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSizeMedium

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveEmphasized
                    }
                }
            }

            Column {
                anchors.left: tileIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: tile.hasDetails ? 28 : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    width: parent.width
                    text: tile.title
                    color: tile.active ? Theme.primaryContainerText : Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitleMedium
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: tile.subtitle
                    color: tile.active ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelMedium
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: tileTap

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.activated()
        }

        MouseArea {
            id: detailsTap

            visible: tile.hasDetails
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 40
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.detailsToggled()

            Text {
                anchors.centerIn: parent
                text: tile.detailsExpanded ? Theme.iconExpandLess : Theme.iconExpandMore
                color: tile.active ? Theme.primaryContainerText : Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
            }
        }

        HoverHandler {
            id: tileHover
        }
    }

    // One available Wi-Fi network: name, lock, signal/status, forget button.
    component NetworkRow: Rectangle {
        id: row

        required property var modelData

        readonly property var net: modelData
        readonly property bool hovered: rowHover.hovered
        readonly property bool connecting: row.net.state === ConnectionState.Connecting
        readonly property bool armed: root.forgetArmed === row.net
        readonly property bool secured: row.net.security !== WifiSecurityType.Open

        width: ListView.view ? ListView.view.width : 0
        height: root.netRowHeight
        radius: Theme.glass ? Theme.shapeMD : Theme.shapeLG
        color: "transparent"

        StateLayer {
            hovered: row.hovered
            pressed: rowTap.pressed
            color: Theme.surfaceText
        }

        Text {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconWifi
            color: row.net.connected ? Theme.primary : Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
        }

        Text {
            id: rowStatus

            anchors.right: forgetButton.visible ? forgetButton.left : parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.connecting ? I18n.t("Подключение…") : (row.net.connected ? I18n.t("Подключено") : Math.round(row.net.signalStrength * 100) + "%")
            color: row.connecting || row.net.connected ? Theme.primary : Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelMedium
        }

        Text {
            id: rowLock

            anchors.right: rowStatus.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: row.secured && !row.connecting
            text: Theme.iconLock
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSizeSmall
        }

        Text {
            id: rowName

            anchors.left: rowIcon.right
            anchors.leftMargin: 8
            anchors.right: rowLock.visible ? rowLock.left : rowStatus.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.armed ? I18n.t("Забыть сеть?") : row.net.name
            color: row.armed ? Theme.error : Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            font.weight: row.net.connected ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }

        MiniIconButton {
            id: forgetButton

            visible: (row.hovered || row.armed) && row.net.known && !row.connecting
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            icon: Theme.iconDelete
            contentColor: row.armed ? Theme.error : Theme.surfaceVariantText
            // rowTap below fills the row and would otherwise swallow the click.
            z: 1

            onClicked: root.forgetNetwork(row.net)
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateNetwork(row.net)
        }

        Connections {
            target: row.net

            function onConnectedChanged(): void {
                if (row.net.connected && root.pskTarget === row.net) {
                    root.pskTarget = null;
                    keyCatcher.forceActiveFocus();
                }
            }

            function onConnectionFailed(reason): void {
                root.wifiError = root.failText(reason);
                // A known profile without secrets otherwise just fails; offer
                // the password field instead of a dead end.
                if (reason === ConnectionFailReason.NoSecrets && root.pskTarget === null) {
                    root.pskTarget = row.net;
                    pskInput.text = "";
                    pskFocus.restart();
                }
            }
        }

        HoverHandler {
            id: rowHover
        }
    }

    // Power action row, same palette as the old fullscreen PowerMenu.
    component PowerRow: Rectangle {
        id: row

        required property int index
        required property var modelData

        property bool focused: false

        readonly property bool pressed: rowTap.pressed
        readonly property bool hovered: rowHover.hovered

        signal activated

        width: parent ? parent.width : 0
        height: 48
        radius: Theme.glass ? Theme.shapeMD : Theme.shapeLG
        color: row.modelData.container
        scale: row.pressed ? 0.98 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutBack
                easing.overshoot: Theme.springOvershoot
            }
        }

        StateLayer {
            hovered: row.hovered
            pressed: row.pressed
            color: row.modelData.content
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: row.modelData.content
            opacity: row.focused ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }
            }
        }

        Text {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.icon
            color: row.modelData.content
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSizeMedium
        }

        Text {
            id: rowLabel

            anchors.left: rowIcon.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.label
            color: row.modelData.content
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelLarge
            font.weight: Font.Medium
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.keys[0].toUpperCase()
            color: row.modelData.content
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabelMedium
            font.weight: Font.Medium
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }

        HoverHandler {
            id: rowHover
        }
    }
}
