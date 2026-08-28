import Foundation

/// Extrae una fecha relativa mencionada en el texto crudo ("hoy", "ayer",
/// "el lunes", "el 24", "el 24 del mes pasado", "el 24 de julio") y la
/// resuelve a una fecha absoluta, anclada a `now`. Puro y determinista —
/// nunca pasa por el modelo. `ParsedTransaction` sí tuvo alguna vez un
/// campo para esto (`dateHint`, pidiéndole al modelo que calculara
/// AAAA-MM-DD), pero el modelo nunca ve la fecha real de hoy — no hay
/// forma de que ese cálculo fuera correcto, y las instrucciones no pueden
/// llevar cifras (ADR-0013: un ejemplo con un monto contaminó la
/// extracción de montos en el spike). Se quitó ese campo a favor de esto:
/// el mismo principio que ya rige el monto (`AmountValidator`) y la
/// tarjeta (`ParsingPipeline`) — lo que el modelo no puede saber con
/// certeza, se resuelve con código determinista sobre el texto, no con IA.
public struct RelativeDateExtractor: Sendable {
    public init() {}

    /// `nil` si no reconoce ninguna mención de fecha — el llamador asume
    /// hoy, igual que antes.
    public func date(in text: String, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let normalized = text
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_MX"))
            .lowercased()

        if normalized.contains("anteayer") || normalized.contains("antier") {
            return calendar.date(byAdding: .day, value: -2, to: now)
        }
        if normalized.contains("ayer") {
            return calendar.date(byAdding: .day, value: -1, to: now)
        }
        if let dayAndMonth = resolveExplicitMonth(in: normalized, now: now, calendar: calendar) {
            return dayAndMonth
        }
        if let bareDay = resolveBareDayOfMonth(in: normalized, now: now, calendar: calendar) {
            return bareDay
        }
        if let weekday = resolveWeekday(in: normalized, now: now, calendar: calendar) {
            return weekday
        }
        if normalized.contains("hoy") {
            return now
        }
        return nil
    }

    private static let monthNames: [String: Int] = [
        "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
        "julio": 7, "agosto": 8, "septiembre": 9, "setiembre": 9, "octubre": 10,
        "noviembre": 11, "diciembre": 12
    ]

    private static let weekdayNumbers: [String: Int] = [
        "domingo": 1, "lunes": 2, "martes": 3, "miercoles": 4,
        "jueves": 5, "viernes": 6, "sabado": 7
    ]

    /// "el 24 de julio" — un mes explícito no deja nada por inferir: se
    /// arma la fecha directo, cayendo al año anterior si esa combinación
    /// de día y mes todavía no ha pasado este año (un gasto nunca es
    /// futuro).
    private func resolveExplicitMonth(in normalized: String, now: Date, calendar: Calendar) -> Date? {
        let pattern = #"\b(\d{1,2})\s+de\s+([a-z]+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              let dayRange = Range(match.range(at: 1), in: normalized),
              let monthRange = Range(match.range(at: 2), in: normalized),
              let day = Int(normalized[dayRange]),
              let month = Self.monthNames[String(normalized[monthRange])] else {
            return nil
        }
        var components = calendar.dateComponents([.year], from: now)
        components.month = month
        components.day = min(day, daysIn(month: month, year: components.year ?? 0, calendar: calendar))
        guard let candidate = calendar.date(from: components) else { return nil }
        if candidate > now {
            components.year = (components.year ?? 0) - 1
            return calendar.date(from: components)
        }
        return candidate
    }

    /// "el 24" sin mes: si ese día ya pasó este mes (o es hoy), es de este
    /// mes; si todavía no llega, un gasto no puede ser futuro, así que es
    /// del mes pasado — lo mismo si el texto lo dice explícito ("del mes
    /// pasado"), que siempre gana sin necesidad de comparar nada.
    private func resolveBareDayOfMonth(in normalized: String, now: Date, calendar: Calendar) -> Date? {
        let pattern = #"\bel\s+(\d{1,2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              let dayRange = Range(match.range(at: 1), in: normalized),
              let day = Int(normalized[dayRange]), (1 ... 31).contains(day) else {
            return nil
        }
        let todayDay = calendar.component(.day, from: now)
        let useLastMonth = normalized.contains("mes pasado") || day > todayDay
        let anchor = useLastMonth ? (calendar.date(byAdding: .month, value: -1, to: now) ?? now) : now
        var components = calendar.dateComponents([.year, .month], from: anchor)
        components.day = min(day, daysIn(month: components.month ?? 1, year: components.year ?? 0, calendar: calendar))
        return calendar.date(from: components)
    }

    /// "el lunes" (o "lunes" a secas) — el lunes más reciente, incluyendo
    /// hoy si hoy es lunes. Un gasto nunca es futuro, así que nunca es el
    /// próximo lunes.
    private func resolveWeekday(in normalized: String, now: Date, calendar: Calendar) -> Date? {
        for (name, weekdayNumber) in Self.weekdayNumbers where normalized.contains(name) {
            let todayWeekday = calendar.component(.weekday, from: now)
            let delta = (todayWeekday - weekdayNumber + 7) % 7
            return calendar.date(byAdding: .day, value: -delta, to: now)
        }
        return nil
    }

    private func daysIn(month: Int, year: Int, calendar: Calendar) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }
}
