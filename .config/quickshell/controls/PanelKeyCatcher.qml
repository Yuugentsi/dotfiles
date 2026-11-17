import QtQuick

Item {
    focus: true
    signal moveRequested(int dx, int dy)
    signal activateRequested()
    signal closeRequested()
    signal tabRequested(int direction)
    signal deleteRequested()
    signal textKey(string text)
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) closeRequested()
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) moveRequested(0, -1)
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) moveRequested(0, 1)
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) moveRequested(-1, 0)
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) moveRequested(1, 0)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activateRequested()
        else if (event.key === Qt.Key_Tab) tabRequested(event.modifiers & Qt.ShiftModifier ? -1 : 1)
        else if (event.key === Qt.Key_Delete) deleteRequested()
        else if (event.text) textKey(event.text)
        else return
        event.accepted = true
    }
}
