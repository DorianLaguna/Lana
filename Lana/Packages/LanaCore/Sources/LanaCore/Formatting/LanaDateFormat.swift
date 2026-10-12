import Foundation

/// Fechas en español, siempre — el diagnóstico del rediseño encontró
/// "Tuesday, 15 September" y "August" en una interfaz en español porque los
/// formateadores seguían el idioma del sistema. Aquí el locale es fijo.
///
/// Devuelve texto en caja de oración ("Lunes 14"); los encabezados lo pasan a
/// mayúsculas con su estilo tipográfico.
///
/// Vive en `LanaCore` y no en `LanaDesign` porque `Money.formatted()` y
/// `LedgerToolbox` también lo necesitan, y `LanaCore` no puede importar nada
/// (ADR-0047). Escribir un monto o una fecha no es una decisión de diseño: es
/// cómo habla el producto.
public enum LanaDateFormat {
    /// El locale de toda fecha y todo monto visible. Una sola fuente de verdad.
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

    /// "14 sept 2026" — una fecha puntual dentro de una fila, donde el día de
    /// la semana sobra pero el año sí importa (un gasto de hace dos años).
    public static func shortDate(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: Self.calendar(calendar))
                .day().month(.abbreviated).year())
    }

    /// "14 sept 2026, 9:41" — cuándo pasó algo, al minuto. Para "hace 2 horas"
    /// no alcanza: saber si un cambio de ayer alcanzó a respaldarse pide el
    /// dato completo.
    public static func shortDateTime(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: Self.calendar(calendar))
                .day().month(.abbreviated).year().hour().minute())
    }

    /// "Corte del 12 de octubre", o "Corte del 12 de octubre de 2025" cuando
    /// cerró en otro año.
    ///
    /// Nombra **el día en que cierra** y no el rango de días que abarca, aunque
    /// el rango sería más explícito: un ciclo es `(start, end]` con `end` a la
    /// medianoche del día de corte, así que un cargo de ese mismo día a las 3 pm
    /// ya cae en el ciclo siguiente. Cualquier rango escrito quedaría corrido un
    /// día respecto a lo que la pantalla de verdad lista, o respecto a lo que el
    /// dueño cree (ADR-0060: con corte el 23, para él el 23 todavía es de este
    /// corte). Mientras esa pregunta no se resuelva, la etiqueta no opina.
    ///
    /// El año solo aparece cuando estorbaría no tenerlo — mismo criterio que
    /// `dayLabel` con "Hoy" y "Ayer".
    ///
    /// - Parameter end: el día del corte, el extremo cerrado del ciclo.
    public static func cycleName(end: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        let calendar = Self.calendar(calendar)
        let day = calendar.component(.day, from: end)
        let name = "Corte del \(day) de \(monthNameLowercased(end, calendar: calendar))"
        let year = calendar.component(.year, from: end)
        guard year != calendar.component(.year, from: now) else { return name }
        return "\(name) de \(year)"
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
