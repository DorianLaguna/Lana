import Foundation

public extension LedgerToolbox {
    /// Busca movimientos por lo que dicen —concepto, categoría o
    /// subcategoría— en todo el historial, y contesta cuándo fue la última
    /// vez, cuántas veces y cuánto suman (ADR-0058).
    ///
    /// Va aparte de las otras herramientas porque **no pregunta por un mes**:
    /// "¿cuándo fue la última vez que compré gasolina?" es justamente no saber
    /// en qué mes buscar. El modelo no busca por su cuenta —no ve el
    /// historial—, así que sin esto la pregunta no se podía contestar
    /// (Docs/CLAUDE.md).
    func buscarPorConcepto(texto: String, asOf date: Date = Date()) async -> String {
        let query = Self.normalize(texto)
        guard query.count >= 2 else {
            return "Dime con más detalle qué buscar: \"\(texto)\" es muy corto."
        }
        guard let range = Self.historyRange(endingAt: date, calendar: calendar),
              let expenses = try? await store.expenses(in: range)
        else {
            return "No se pudieron leer los movimientos."
        }

        let identities = await sharedListStore.viewerIdentities(for: expenses)
        let matches = expenses
            .filter { $0.kind == .expense && Self.matches(query, expense: $0) }
            .sorted { $0.date > $1.date }
        guard let latest = matches.first else {
            return "No encontré ningún gasto que hable de \"\(texto)\"."
        }

        let personal = { (expense: Expense) in expense.personalAmount(viewerIdentities: identities) }
        let lines = [
            """
            La última vez que hubo un gasto de "\(texto)" fue el \
            \(LanaDateFormat.shortDate(latest.date, calendar: calendar)): \
            \(latest.concept), \(personal(latest).formatted()).
            """
        ] + Self.totals(of: matches, personal: personal, calendar: calendar)
        return lines.joined(separator: "\n")
    }
}

extension LedgerToolbox {
    /// Hasta dónde atrás se busca: diez años. `ExpenseStore` pide un rango y no
    /// hay "todo el historial"; diez años es más de lo que puede tener una app
    /// que empezó a usarse este año, y no obliga a leer desde `distantPast`.
    static func historyRange(endingAt date: Date, calendar: Calendar) -> DateInterval? {
        guard let start = calendar.date(byAdding: .year, value: -10, to: date) else { return nil }
        return DateInterval(start: start, end: date)
    }

    /// Un gasto habla de lo que se busca si lo dice su concepto, su categoría o
    /// su subcategoría. Sin acentos ni mayúsculas, igual que el emparejamiento
    /// de listas compartidas.
    static func matches(_ query: String, expense: Expense) -> Bool {
        [expense.concept, expense.category, expense.subcategory]
            .compactMap(\.self)
            .contains { normalize($0).contains(query) }
    }

    /// "En total llevas 7 gastos de eso, $5,400.00, desde marzo de 2026." Una
    /// línea por moneda: los montos de monedas distintas nunca se suman
    /// (Docs/CONVENTIONS.md).
    static func totals(
        of matches: [Expense],
        personal: (Expense) -> Money,
        calendar: Calendar) -> [String] {
        let byCurrency = Dictionary(grouping: matches) { $0.amount.currency }
        return byCurrency.keys.sorted { $0.rawValue < $1.rawValue }.compactMap { currency in
            guard let group = byCurrency[currency], let first = group.min(by: { $0.date < $1.date }) else {
                return nil
            }
            let total = group.reduce(Decimal(0)) { $0 + personal($1).amount }
            let count = group.count == 1 ? "1 gasto" : "\(group.count) gastos"
            return """
            En total van \(count) por \(Money(amount: total, currency: currency).formatted()), \
            desde \(LanaDateFormat.monthYear(first.date, calendar: calendar).lowercased()).
            """
        }
    }
}
