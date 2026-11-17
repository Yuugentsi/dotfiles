.pragma library
function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }
function wheelSteps(accumulator, delta) { var total = accumulator + delta; var steps = total < 0 ? Math.ceil(total / 120) : Math.floor(total / 120); return { steps: steps, remainder: total - steps * 120 } }
