pragma Singleton
import QtQuick

/*
 * Zinc / shadcn palette tokens — use instead of scattered hex literals.
 */
QtObject {
    function surface(isDark) { return isDark ? "#09090b" : "#ffffff" }
    function surfaceMuted(isDark) { return isDark ? "#18181b" : "#fafafa" }
    function surfaceSubtle(isDark) { return isDark ? Qt.rgba(0.09, 0.09, 0.11, 0.5) : "#fafafa" }

    function border(isDark) { return isDark ? "#27272a" : "#e4e4e7" }
    function borderMuted(isDark) { return isDark ? "#3f3f46" : "#d4d4d8" }
    function borderHover(isDark) { return isDark ? "#52525b" : "#d4d4d8" }

    function divider(isDark) { return isDark ? "#27272a" : "#f4f4f5" }

    function textPrimary(isDark) { return isDark ? "#fafafa" : "#18181b" }
    function textSecondary(isDark) { return isDark ? "#a1a1aa" : "#71717a" }
    function textMuted(isDark) { return isDark ? "#71717a" : "#a1a1aa" }
    function textBody(isDark) { return isDark ? "#d4d4d8" : "#3f3f46" }

    function navActiveBg(isDark) { return isDark ? "#2563eb" : "#eff6ff" }
    function navActiveFg(isDark) { return isDark ? "#ffffff" : "#1d4ed8" }

    function primary(isDark) { return "#2563eb" }
    function primaryHover(isDark) { return "#3b82f6" }
    function primaryPressed(isDark) { return "#1d4ed8" }

    function destructive(isDark) { return "#dc2626" }
    function destructiveHover(isDark) { return "#ef4444" }
    function destructivePressed(isDark) { return "#b91c1c" }

    function buttonSecondary(isDark) {
        return isDark ? "#27272a" : "#f4f4f5"
    }
    function buttonSecondaryHover(isDark) {
        return isDark ? "#27272a" : "#e4e4e7"
    }
    function buttonSecondaryPressed(isDark) {
        return isDark ? "#3f3f46" : "#d4d4d8"
    }

    function badgeFill(isDark, variant) {
        if (isDark) {
            switch (variant) {
            case "green": return Qt.rgba(0.22, 0.80, 0.31, 0.10)
            case "blue":  return Qt.rgba(0.23, 0.51, 0.96, 0.10)
            case "amber": return Qt.rgba(0.96, 0.66, 0.02, 0.10)
            case "red":   return Qt.rgba(0.94, 0.27, 0.24, 0.10)
            default:      return "#27272a"
            }
        }
        switch (variant) {
        case "green": return "#dcfce7"
        case "blue":  return "#dbeafe"
        case "amber": return "#fef3c7"
        case "red":   return "#fee2e2"
        default:      return "#f4f4f5"
        }
    }

    function badgeBorder(isDark, variant) {
        if (isDark) {
            switch (variant) {
            case "green": return Qt.rgba(0.22, 0.80, 0.31, 0.20)
            case "blue":  return Qt.rgba(0.23, 0.51, 0.96, 0.20)
            case "amber": return Qt.rgba(0.96, 0.66, 0.02, 0.20)
            case "red":   return Qt.rgba(0.94, 0.27, 0.24, 0.20)
            default:      return "#3f3f46"
            }
        }
        switch (variant) {
        case "green": return "#bbf7d0"
        case "blue":  return "#bfdbfe"
        case "amber": return "#fde68a"
        case "red":   return "#fecaca"
        default:      return "#e4e4e7"
        }
    }

    function badgeText(isDark, variant) {
        if (isDark) {
            switch (variant) {
            case "green": return "#4ade80"
            case "blue":  return "#60a5fa"
            case "amber": return "#fbbf24"
            case "red":   return "#f87171"
            default:      return "#d4d4d8"
            }
        }
        switch (variant) {
        case "green": return "#166534"
        case "blue":  return "#1e40af"
        case "amber": return "#92400e"
        case "red":   return "#991b1b"
        default:      return "#52525b"
        }
    }

    function trendText(isDark, variant) {
        if (variant === "green") return isDark ? "#4ade80" : "#16a34a"
        if (variant === "amber") return isDark ? "#fbbf24" : "#d97706"
        if (variant === "red") return isDark ? "#f87171" : "#dc2626"
        return textSecondary(isDark)
    }

    function probeStatusText(isDark, kind) {
        if (kind === "success") return isDark ? "#86efac" : "#166534"
        if (kind === "error") return isDark ? "#fca5a5" : "#dc2626"
        return textSecondary(isDark)
    }
}
