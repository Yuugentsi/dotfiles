.pragma library

function wrap(index, count) {
    return count > 0 ? ((index % count) + count) % count : -1
}

function eligible(windows) {
    const seen = new Set()
    return windows.filter(window => {
        if (!window || !/^(?:0x)?[0-9a-f]+$/i.test(window.address || "")) return false
        if (window.lastIpcObject && window.lastIpcObject.mapped === false) return false
        if (seen.has(window.address)) return false
        seen.add(window.address)
        return true
    })
}

function rank(windows, history) {
    return eligible(windows).slice().sort((left, right) => {
        const leftSeen = history.indexOf(left.address)
        const rightSeen = history.indexOf(right.address)
        if (leftSeen >= 0 || rightSeen >= 0) {
            if (leftSeen < 0) return 1
            if (rightSeen < 0) return -1
            return leftSeen - rightSeen
        }
        const leftRank = Number(left.lastIpcObject ? left.lastIpcObject.focusHistoryID : undefined)
        const rightRank = Number(right.lastIpcObject ? right.lastIpcObject.focusHistoryID : undefined)
        return (Number.isFinite(leftRank) ? leftRank : 99999) - (Number.isFinite(rightRank) ? rightRank : 99999)
    })
}

function reconcile(windows, order) {
    const available = eligible(windows)
    const byAddress = new Map(available.map(window => [window.address, window]))
    const result = order.filter(address => byAddress.has(address)).map(address => byAddress.get(address))
    const known = new Set(result.map(window => window.address))
    return result.concat(available.filter(window => !known.has(window.address)))
}

function remember(history, address, windows) {
    const valid = new Set(eligible(windows).map(window => window.address))
    return [address].concat(history.filter(value => value !== address && valid.has(value))).slice(0, 100)
}
