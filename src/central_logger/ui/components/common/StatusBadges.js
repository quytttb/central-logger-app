.pragma library

function eventLevelToBadge(level) {
    if (level === "critical") return "red"
    if (level === "warning") return "amber"
    if (level === "error") return "zinc"
    if (level === "info") return "blue"
    return "zinc"
}

function sensorDisplayStatus(status, alarmType) {
    switch (status) {
    case "Inactive": return { text: "Inactive", color: "zinc" }
    case "ERR": return { text: "ERR", color: "red" }
    case "WAIT": return { text: "WAIT", color: "zinc" }
    case "Stale": return { text: "Stale", color: "amber" }
    case "Invalid": return { text: "Invalid", color: "zinc" }
    case "ALARM":
        if (alarmType === "min") return { text: "MIN", color: "red" }
        if (alarmType === "max") return { text: "MAX", color: "red" }
        return { text: "Alarm", color: "red" }
    case "OK": return { text: "OK", color: "green" }
    case "ON": return { text: "ON", color: "blue" }
    case "OFF": return { text: "OFF", color: "zinc" }
    default: return { text: "", color: "zinc" }
    }
}
