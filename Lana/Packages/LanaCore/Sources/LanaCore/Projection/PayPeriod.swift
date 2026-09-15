import Foundation

/// El periodo de pago vigente: de un sueldo al siguiente.
///
/// Se ancla al **sueldo real del usuario** —un `RecurringItem` de tipo ingreso,
/// que es como se modela un sueldo (ver su doc comment)— y no a la quincena de
/// calendario. La diferencia importa: con sueldo quincenal que cae el 15, el
/// periodo 16-31 arrancaría en ceros justo después de cobrar, y el disponible
/// saldría negativo teniendo dinero. Anclado al sueldo, el dinero del 15 cuenta
/// para los días que tiene que cubrir.
///
/// Sin ningún ingreso recurrente configurado cae a la quincena de calendario
/// (1-15 y 16-fin de mes), la misma convención que ya usa "Próximos pagos" de
/// tarjetas. `isAnchoredToIncome` dice cuál de los dos se usó, para que la UI
/// pueda ser honesta al respecto.
public struct PayPeriod: Sendable, Hashable {
    /// Primer instante del periodo, inclusive.
    public let start: Date
    /// Primer instante del periodo siguiente — **exclusivo**.
    public let end: Date
    /// `true` si el periodo salió de un ingreso recurrente; `false` si cayó a
    /// la quincena de calendario.
    public let isAnchoredToIncome: Bool
    /// El nombre del ingreso que ancla el periodo ("Sueldo"), si lo hay.
    public let anchorName: String?

    public init(start: Date, end: Date, isAnchoredToIncome: Bool, anchorName: String? = nil) {
        self.start = start
        self.end = end
        self.isAnchoredToIncome = isAnchoredToIncome
        self.anchorName = anchorName
    }

    /// El último instante del periodo, para `Projection.available(through:)`,
    /// que compara con `<=`.
    public var through: Date {
        end.addingTimeInterval(-1)
    }

    /// Si una fecha cae dentro del periodo.
    public func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    /// Resuelve el periodo vigente.
    ///
    /// - Parameters:
    ///   - date: qué día es hoy.
    ///   - recurringItems: los recurrentes del usuario. Solo se miran los de
    ///     tipo ingreso; los de gasto no anclan nada.
    public static func current(
        for date: Date,
        recurringItems: [RecurringItem],
        calendar: Calendar = .current) -> PayPeriod {
        let incomes = recurringItems.filter { $0.kind == .income }
        guard !incomes.isEmpty else {
            return calendarFortnight(for: date, calendar: calendar)
        }

        // Las ocurrencias del mes pasado, este y el siguiente: con eso siempre
        // hay una antes y una después de hoy, sin importar en qué día caiga.
        var occurrences: [(date: Date, name: String)] = []
        for offset in -1 ... 1 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: date) else { continue }
            for income in incomes {
                guard let occurrence = Self.occurrence(of: income.dayOfMonth, inMonthOf: month, calendar: calendar)
                else { continue }
                occurrences.append((occurrence, income.name))
            }
        }
        occurrences.sort { $0.date < $1.date }

        guard let last = occurrences.last(where: { $0.date <= date }),
              let next = occurrences.first(where: { $0.date > date })
        else {
            return calendarFortnight(for: date, calendar: calendar)
        }
        return PayPeriod(start: last.date, end: next.date, isAnchoredToIncome: true, anchorName: last.name)
    }

    /// Días 1-15 si hoy cae en esa mitad; si no, del 16 al último día real del
    /// mes. Misma regla que `UpcomingCardPaymentsModel`.
    static func calendarFortnight(for date: Date, calendar: Calendar) -> PayPeriod {
        let today = calendar.component(.day, from: date)
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        let startOfNextMonth = calendar.dateInterval(of: .month, for: date)?.end ?? date

        if today <= 15 {
            let sixteenth = calendar.date(byAdding: .day, value: 15, to: startOfMonth) ?? startOfNextMonth
            return PayPeriod(start: startOfMonth, end: sixteenth, isAnchoredToIncome: false)
        }
        let sixteenth = calendar.date(byAdding: .day, value: 15, to: startOfMonth) ?? startOfMonth
        return PayPeriod(start: sixteenth, end: startOfNextMonth, isAnchoredToIncome: false)
    }

    /// El día `dayOfMonth` dentro del mes de `date`, a medianoche.
    ///
    /// Se recorta al último día real del mes: un recurrente en el 31 cae el 28
    /// en febrero, igual que hace `UpcomingCardPaymentsModel` con la fecha
    /// límite de una tarjeta. Sin esto, un sueldo el 31 desaparecería en los
    /// meses cortos.
    static func occurrence(of dayOfMonth: Int, inMonthOf date: Date, calendar: Calendar) -> Date? {
        guard let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count else { return nil }
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = min(dayOfMonth, daysInMonth)
        return calendar.date(from: components)
    }
}
