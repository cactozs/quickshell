import QtQuick

// Kicks a BlurKick when the target's geometry changes. `position` also watches
// x/y, which the bar's island anchors need; popup cards only resize.
Connections {
    required property Item item
    required property BlurKick kicker
    property bool position: false

    target: item

    // The target can emit during construction, before the kicker is set.
    function kick(): void {
        if (kicker)
            kicker.kick();
    }

    function onWidthChanged(): void {
        kick();
    }

    function onHeightChanged(): void {
        kick();
    }

    function onXChanged(): void {
        if (position)
            kick();
    }

    function onYChanged(): void {
        if (position)
            kick();
    }
}
