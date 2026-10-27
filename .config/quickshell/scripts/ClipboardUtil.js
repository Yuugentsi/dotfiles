.pragma library
function fileUrl(path) { return "file://" + String(path).split("/").map(encodeURIComponent).join("/") }
function editsFilter(event, text) { return event.key === Qt.Key_Backspace || (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) }
function editedFilter(event, text) { return event.key === Qt.Key_Backspace ? text.slice(0, -1) : "" }
