import Foundation

/// Cuánto cambió una cifra entre dos periodos.
public struct PeriodDelta: Sendable, Hashable {
    /// Hacia dónde se movió. Es una dirección, no un juicio: gastar más no es
    /// "malo" ni gastar menos "bueno" — la UI lo presenta como dato
    /// (Docs/CLAUDE.md → Tono).
    public enum Direction: Sendable, Hashable {
        case up
        case down
        case unchanged
    }

    public let currency: Currency
    public let current: Decimal
    public let previous: Decimal

    public init(currency: Currency, current: Decimal, previous: Decimal) {
        self.currency = currency
        self.current = current
        self.previous = previous
    }

    /// La diferencia en dinero. Negativa si el periodo actual fue menor.
    public var absolute: Decimal {
        current - previous
    }

    /// La diferencia como fracción del periodo anterior (`0.2` = subió 20%).
    ///
    /// `nil` cuando el periodo anterior fue cero: no existe el porcentaje de
    /// cambio contra nada, y presentarlo como "+100%" sería inventar una base.
    public var relative: Decimal? {
        guard previous > 0 else { return nil }
        return absolute / previous
    }

    public var direction: Direction {
        if current > previous {
            return .up
        }
        if current < previous {
            return .down
        }
        return .unchanged
    }
}

/// El cambio de una categoría entre dos periodos.
public struct CategoryDelta: Identifiable, Sendable {
    public var id: String {
        category
    }

    public let category: String
    public let delta: PeriodDelta

    public init(category: String, delta: PeriodDelta) {
        self.category = category
        self.delta = delta
    }
}

/// Compara dos periodos ya calculados. Sirve igual para "este mes contra el
/// anterior" que para "este mes contra el mismo mes del año pasado": lo único
/// que cambia es qué se le pasa.
///
/// No sabe qué periodos son ni cuánto duran — solo resta. Quien lo construye
/// es responsable de que la comparación tenga sentido (comparar un mes contra
/// un año daría un número real y sin significado).
public struct PeriodComparison: Sendable {
    private let current: PeriodStatistics
    private let previous: PeriodStatistics

    public init(current: PeriodStatistics, previous: PeriodStatistics) {
        self.current = current
        self.previous = previous
    }

    /// Las monedas presentes en cualquiera de los dos periodos.
    public var currencies: [Currency] {
        Set(current.currencies).union(previous.currencies).sorted { $0.rawValue < $1.rawValue }
    }

    /// Cuánto cambió el gasto en una moneda. `nil` si esa moneda no aparece en
    /// ninguno de los dos periodos.
    public func expenseDelta(in currency: Currency) -> PeriodDelta? {
        guard currencies.contains(currency) else { return nil }
        return PeriodDelta(
            currency: currency,
            current: current.total(in: currency)?.expenses ?? 0,
            previous: previous.total(in: currency)?.expenses ?? 0)
    }

    /// Cuánto cambió el ingreso en una moneda.
    public func incomeDelta(in currency: Currency) -> PeriodDelta? {
        guard currencies.contains(currency) else { return nil }
        return PeriodDelta(
            currency: currency,
            current: current.total(in: currency)?.income ?? 0,
            previous: previous.total(in: currency)?.income ?? 0)
    }

    /// Qué categorías subieron y cuáles bajaron, ordenadas por el tamaño del
    /// cambio (sin importar el signo) — lo que más se movió va primero, que es
    /// lo que explica la diferencia del total.
    ///
    /// Incluye las categorías que aparecen en un solo periodo: una que dejó de
    /// gastarse es justo lo que interesa ver.
    public func categoryDeltas(in currency: Currency) -> [CategoryDelta] {
        let currentByCategory = Dictionary(
            uniqueKeysWithValues: current.categoryTotals(in: currency).map { ($0.category, $0.amount) })
        let previousByCategory = Dictionary(
            uniqueKeysWithValues: previous.categoryTotals(in: currency).map { ($0.category, $0.amount) })

        return Set(currentByCategory.keys)
            .union(previousByCategory.keys)
            .map { category in
                CategoryDelta(
                    category: category,
                    delta: PeriodDelta(
                        currency: currency,
                        current: currentByCategory[category] ?? 0,
                        previous: previousByCategory[category] ?? 0))
            }
            .sorted { first, second in
                let firstSize = abs(first.delta.absolute)
                let secondSize = abs(second.delta.absolute)
                return firstSize == secondSize ? first.category < second.category : firstSize > secondSize
            }
    }
}
