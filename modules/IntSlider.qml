pragma ComponentBehavior: Bound

import QtQuick

// Integer QsSlider: the number follows the drag locally and the value is
// reported once on release, so shell-state.json (and the system theme files
// that follow it) is not rewritten on every pixel. Settings binds `current`
// and commits in `changedValue`.
QsSlider {
    id: intSlider

    property int minimum: 0
    property int maximum: 100
    property int current: 0

    signal changedValue(int value)

    implicitWidth: 180

    property real dragValue: -1

    readonly property int shown: intSlider.dragValue >= 0
        ? Math.round(intSlider.minimum + intSlider.dragValue * (intSlider.maximum - intSlider.minimum))
        : intSlider.current

    value: intSlider.dragValue >= 0
        ? intSlider.dragValue
        : (intSlider.current - intSlider.minimum) / Math.max(1, intSlider.maximum - intSlider.minimum)

    onMoved: position => intSlider.dragValue = position
    onCommitted: position => {
        intSlider.dragValue = -1;
        intSlider.changedValue(Math.round(intSlider.minimum + position * (intSlider.maximum - intSlider.minimum)));
    }
}
