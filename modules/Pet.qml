pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../style"

// Desktop pet: a draggable GIF on the overlay layer. The window is fullscreen
// but its mask only covers the pet and the open bubble, so the rest of the
// screen stays click-through. The chat state lives in services/PetChat.qml:
// this window is a LazyOverlay and may be gone while a request is in flight.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: ShellState.petScreen === root.modelData.name

    // Fixed box: the GIF is letterboxed inside it, so the click area and the
    // saved position never jump when tux switches to the lying frame.
    readonly property int petSize: 140
    readonly property int bubbleWidth: Math.min(320, root.width - 16)
    // A long answer scrolls inside the bubble instead of running off-screen.
    readonly property int maxMessageHeight: Math.min(420, Math.max(80, root.height - 240))

    // A fullscreen window on this output covers the pet; layer-shell would
    // otherwise keep it on top of video and games.
    readonly property bool hiddenByFullscreen: {
        const t = ToplevelManager.activeToplevel;
        if (!t || !t.fullscreen)
            return false;
        const screens = t.screens ?? [];
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === root.modelData.name)
                return true;
        }
        return false;
    }

    readonly property string petSource: PetChat.thinking || root.sleeping
        ? PetChat.thinkingImagePath
        : PetChat.imagePath
    readonly property bool bubbleVisible: PetChat.chatOpen || root.reaction !== ""

    property bool sleeping: false
    property double lastActivity: 0
    property string reaction: ""
    property bool batteryWarned: false
    property bool lastMuted: false
    property int lastNotifCount: -1

    readonly property string bubbleText: PetChat.chatOpen
        ? (PetChat.thinking
            ? I18n.t("Думаю…")
            : (PetChat.error !== "" ? I18n.t(PetChat.error) : PetChat.reply))
        : root.reaction

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: root.shown && !root.hiddenByFullscreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:pet"
    // The pet idles without a keyboard grab: an interactive layer steals the
    // focused window even when the chat is closed. The open chat needs keys.
    WlrLayershell.keyboardFocus: PetChat.chatOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        Region { item: pet }
        Region { item: bubbleHit }
    }

    function placePet(): void {
        if (!root.shown)
            return;
        const maxX = Math.max(0, root.width - pet.width);
        const maxY = Math.max(0, root.height - pet.height);
        if (ShellState.petPlaced) {
            pet.x = Math.max(0, Math.min(ShellState.petX, maxX));
            pet.y = Math.max(0, Math.min(ShellState.petY, maxY));
        } else {
            pet.x = Math.max(0, maxX - 24);
            pet.y = Math.max(0, maxY - 24);
        }
    }

    function send(): void {
        const text = petInput.text.trim();
        if (text === "" || PetChat.thinking)
            return;
        petInput.text = "";
        PetChat.ask(text);
    }

    function wake(): void {
        root.sleeping = false;
        root.lastActivity = Date.now();
    }

    function petIt(): void {
        root.wake();
        heartAnim.restart();
        petBounce.restart();
    }

    function react(text: string): void {
        if (!root.shown || root.hiddenByFullscreen || PetChat.chatOpen
                || PetChat.thinking || text === "")
            return;
        root.wake();
        root.reaction = text;
        reactionTimer.restart();
    }

    Component.onCompleted: {
        root.lastNotifCount = Notifications.history.length;
        root.lastMuted = Audio.effectiveMuted;
        if (root.shown) {
            root.placePet();
            root.lastActivity = Date.now();
            if (PetChat.chatOpen)
                focusKick.restart();
        }
    }

    onShownChanged: {
        if (root.shown) {
            root.placePet();
            root.sleeping = false;
            root.lastActivity = Date.now();
        } else {
            PetChat.chatOpen = false;
            root.reaction = "";
        }
    }

    // Fullscreen hides the surface but not `shown`; drop the bubble so it does
    // not pop back when the video ends.
    onHiddenByFullscreenChanged: {
        if (root.hiddenByFullscreen) {
            PetChat.chatOpen = false;
            root.reaction = "";
        }
    }

    // A resize (or a monitor change) can leave the saved spot off-screen.
    onWidthChanged: root.placePet()
    onHeightChanged: root.placePet()

    AnimatedImage {
        id: pet

        width: root.petSize
        height: root.petSize
        source: root.petSource
        fillMode: Image.PreserveAspectFit
        playing: root.visible
        smooth: true

        MouseArea {
            id: petDrag

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: petDrag.drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            property real startX: 0
            property real startY: 0

            drag.target: pet
            drag.minimumX: 0
            drag.maximumX: Math.max(0, root.width - pet.width)
            drag.minimumY: 0
            drag.maximumY: Math.max(0, root.height - pet.height)

            onPressed: {
                petDrag.startX = pet.x;
                petDrag.startY = pet.y;
                root.wake();
            }

            onReleased: {
                if (Math.abs(pet.x - petDrag.startX) + Math.abs(pet.y - petDrag.startY) > 2)
                    ShellState.setPetPosition(pet.x, pet.y);
            }

            // A double click must not toggle the chat twice, so the single
            // click action waits for the double-click window.
            onClicked: {
                if (Math.abs(pet.x - petDrag.startX) + Math.abs(pet.y - petDrag.startY) <= 2)
                    clickTimer.restart();
            }

            onDoubleClicked: {
                clickTimer.stop();
                root.petIt();
            }

            onEntered: root.wake()
        }
    }

    // Petting: a heart inside the pet box, so the layer mask still covers it.
    Text {
        id: heart

        x: pet.x + pet.width - 34
        y: pet.y + 30
        text: "♥"
        visible: opacity > 0.01
        opacity: 0
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: 26
    }

    // Layered bubble: visible = open, 0x0 when closed so the mask does not keep
    // an invisible card blocking clicks.
    Item {
        id: bubbleHit

        visible: bubble.visible
        x: bubble.x
        y: bubble.y
        width: bubble.visible ? bubble.width : 0
        height: bubble.visible ? bubble.height : 0
    }

    RectangularShadow {
        anchors.fill: bubble
        radius: bubble.radius
        blur: Theme.cardShadowBlur
        offset.y: Theme.cardShadowOffset
        color: Theme.cardShadow
        visible: Theme.glass && bubble.visible
    }

    Rectangle {
        id: bubble

        readonly property int pad: 12

        width: root.bubbleWidth
        height: bubbleColumn.implicitHeight + 2 * pad
        visible: root.bubbleVisible
        radius: Theme.shapeXL
        color: Theme.surfaceContainerHigh
        border.width: Theme.hairlineWidth
        border.color: Theme.hairline

        GlassEdge {}

        x: Math.max(8, Math.min(pet.x + pet.width / 2 - width / 2, root.width - width - 8))
        y: pet.y > height + 16
            ? pet.y - height - 8
            : Math.max(8, Math.min(pet.y + pet.height + 8, root.height - height - 8))

        Column {
            id: bubbleColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: bubble.pad
            }

            spacing: 8

            Flickable {
                id: messageScroll

                width: parent.width
                height: Math.min(msgText.implicitHeight, root.maxMessageHeight)
                contentHeight: msgText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Text {
                    id: msgText

                    width: messageScroll.width
                    visible: text !== ""
                    text: root.bubbleText
                    textFormat: Text.MarkdownText
                    wrapMode: Text.Wrap
                    color: PetChat.chatOpen && PetChat.error !== "" ? Theme.error : Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBodyMedium
                    lineHeight: 1.25
                }
            }

            Rectangle {
                width: parent.width
                height: 40
                visible: PetChat.chatOpen
                radius: Theme.nothing || Theme.glass ? Theme.shapeMD : Theme.shapeFull
                color: Theme.surfaceContainerHighest

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        right: retryButton.visible ? retryButton.left : sendButton.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }

                    visible: petInput.text.length === 0
                    text: I18n.t("Спросить питомца…")
                    elide: Text.ElideRight
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                }

                TextInput {
                    id: petInput

                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: retryButton.visible ? 76 : 40
                    }

                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabelLarge
                    selectByMouse: true
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText

                    onAccepted: root.send()

                    Keys.onEscapePressed: PetChat.chatOpen = false
                }

                MiniIconButton {
                    id: retryButton

                    anchors {
                        right: sendButton.left
                        rightMargin: 2
                        verticalCenter: parent.verticalCenter
                    }

                    visible: PetChat.error !== "" && PetChat.lastPrompt !== ""
                    icon: Theme.iconRestart
                    contentColor: Theme.primary
                    onClicked: PetChat.retry()
                }

                MiniIconButton {
                    id: sendButton

                    anchors {
                        right: parent.right
                        rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }

                    icon: PetChat.thinking ? Theme.iconStop : Theme.iconSend
                    contentColor: PetChat.thinking ? Theme.error : Theme.primary
                    onClicked: PetChat.thinking ? PetChat.cancel() : root.send()
                }
            }
        }
    }

    // The surface needs a moment to gain keyboard focus; give the field a kick.
    Timer {
        id: focusKick
        interval: 50
        onTriggered: petInput.forceActiveFocus()
    }

    Timer {
        id: clickTimer
        interval: 220
        onTriggered: {
            root.reaction = "";
            PetChat.chatOpen = !PetChat.chatOpen;
        }
    }

    Timer {
        id: reactionTimer
        interval: 4000
        onTriggered: root.reaction = ""
    }

    Timer {
        id: sleepTimer
        interval: 60 * 1000
        repeat: true
        running: root.shown && !root.hiddenByFullscreen
        onTriggered: {
            if (!PetChat.chatOpen && !PetChat.thinking && !petDrag.containsMouse
                    && Date.now() - root.lastActivity >= 5 * 60 * 1000)
                root.sleeping = true;
        }
    }

    SequentialAnimation {
        id: heartAnim

        NumberAnimation { target: heart; property: "opacity"; from: 0; to: 1; duration: 100 }
        ParallelAnimation {
            NumberAnimation {
                target: heart
                property: "y"
                from: pet.y + 30
                to: pet.y + 2
                duration: 800
                easing.type: Easing.OutCubic
            }
            NumberAnimation { target: heart; property: "opacity"; to: 0; duration: 800 }
        }
    }

    SequentialAnimation {
        id: petBounce

        NumberAnimation {
            target: pet
            property: "scale"
            from: 1
            to: 1.12
            duration: 120
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: pet
            property: "scale"
            to: 1
            duration: 220
            easing.type: Easing.OutBack
        }
    }

    Connections {
        target: Notifications

        function onHistoryChanged(): void {
            const count = Notifications.history.length;
            const entry = Notifications.history[0];
            if (root.lastNotifCount !== -1 && count > root.lastNotifCount
                    && entry && Date.now() - entry.at < 3000)
                root.react(I18n.t("Новое уведомление"));
            root.lastNotifCount = count;
        }
    }

    Connections {
        target: UPower.displayDevice

        function onPercentageChanged(): void {
            const device = UPower.displayDevice;
            if (!device)
                return;
            const percent = device.percentage * 100;
            if (device.state === UPowerDeviceState.Charging || percent > 20) {
                root.batteryWarned = false;
                return;
            }
            if (percent <= 15 && !root.batteryWarned) {
                root.batteryWarned = true;
                root.react(I18n.t("Батарея садится"));
            }
        }
    }

    Connections {
        target: Audio

        function onEffectiveMutedChanged(): void {
            if (Audio.effectiveMuted && !root.lastMuted)
                root.react(I18n.t("Звук выключен"));
            root.lastMuted = Audio.effectiveMuted;
        }
    }

    Connections {
        target: PetChat

        function onChatOpenChanged(): void {
            if (PetChat.chatOpen) {
                root.sleeping = false;
                focusKick.restart();
            } else {
                root.lastActivity = Date.now();
            }
        }

        function onThinkingChanged(): void {
            if (PetChat.thinking)
                root.sleeping = false;
            root.lastActivity = Date.now();
        }
    }
}
