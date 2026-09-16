import Foundation

/// Fechas en español, siempre — el diagnóstico del rediseño encontró
/// "Tuesday, 15 September" y "August" en una interfaz en español porque los
/// formateadores seguían el idioma del sistema. Aquí el locale es fijo.
///
/// Devuelve texto en caja de oración ("Lunes 14"); los encabezados lo pasan a
/// mayúsculas con su estilo tipográfico.
public enum LanaDateFormat {
    /// El locale de toda fecha visible.
    public static let locale = Locale(identifier: "es_MX")

    private static func calendar(_ base: Calendar) -> Calendar {
        var calendar = base
        calendar.locale = locale
        return calendar
    }

    /// "Septiembre".
    public static func monthName(_ date: Date, calendar: Calendar = .current) -> String {
        monthNameLowercased(date, calendar: calendar).capitalizedFirstLetter
    }

    /// "septiembre" — para frases y tablas ("agosto · $19,781").
    public static func monthNameLowercased(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: Self.calendar(calendar)).month(.wide)).lowercased()
    }

    /// "Septiembre 2026".
    public static func monthYear(_ date: Date, calendar: Calendar = .current) -> String {
        let year = Self.calendar(calendar).component(.year, from: date)
        return "\(monthName(date, calendar: calendar)) \(year)"
    }

    /// "Lunes 14" — encabezado de día, sin mes ni año.
    public static func dayHeader(_ date: Date, calendar: Calendar = .current) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: Self.calendar(calendar)).weekday(.wide)
        let day = Self.calendar(calendar).component(.day, from: date)
        return "\(date.formatted(style).capitalizedFirstLetter) \(day)"
    }

    /// "Hoy", "Ayer" o "14 de septiembre" — cómo se nombra una fecha dentro
    /// de un chip, donde el año sobra y lo que importa es qué tan reciente es.
    public static func dayLabel(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Hoy"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ayer"
        }
        let day = calendar.component(.day, from: date)
        return "\(day) de \(monthNameLowercased(date, calendar: calendar))"
    }

    /// "S" — la inicial de un mes bajo una barra de la vista anual.
    public static func monthInitial(_ date: Date, calendar: Calendar = .current) -> String {
        String(monthName(date, calendar: calendar).prefix(1))
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
