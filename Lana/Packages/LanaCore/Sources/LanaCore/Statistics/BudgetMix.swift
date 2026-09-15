import Foundation

/// Cuánto se llevó un grupo del presupuesto, y contra qué meta se compara.
public struct BudgetShare: Identifiable, Sendable, Hashable {
    public var id: BudgetGroup {
        group
    }

    public let group: BudgetGroup
    public let amount: Decimal
    /// Qué fracción del denominador se llevó (`0.42` = 42%).
    public let share: Decimal
    /// La meta de la regla elegida. `nil` cuando no hay regla elegida, cuando
    /// la regla no fija meta para este grupo, o cuando no hay ingreso contra el
    /// cual medir.
    public let target: Decimal?

    public init(group: BudgetGroup, amount: Decimal, share: Decimal, target: Decimal?) {
        self.group = group
        self.amount = amount
        self.share = share
        self.target = target
    }

    /// Cuánto se aleja de la meta, en puntos de fracción. `nil` sin meta.
    /// Positivo = por encima de la meta.
    public var deviation: Decimal? {
        guard let target else { return nil }
        return share - target
    }
}

/// Cómo se reparte el dinero del periodo entre Necesidades, Deseos y Ahorro, y
/// cómo se compara eso contra la regla que el usuario eligió.
///
/// **Toda la aritmética es de aquí.** El modelo solo aportó las etiquetas de
/// `groupsByLabel`, sin haber visto un monto (`SpendingClassifying`).
///
/// Se mide de dos formas según haya o no ingreso registrado:
///
/// - **Con ingreso:** el denominador es el ingreso, y el ahorro es lo que
///   sobra — `ingreso − necesidades − deseos − sin clasificar`. Así entran a
///   la misma cifra tanto el dinero que se apartó a propósito (un gasto
///   etiquetado como ahorro) como el que simplemente no se gastó, sin contar
///   nada dos veces, y los cuatro montos suman el ingreso exacto. Puede salir
///   negativo: se gastó más de lo que entró, que es un dato, no un error.
/// - **Sin ingreso:** el denominador es el gasto, los tres grupos son las sumas
///   crudas de lo etiquetado y **no hay metas ni tramo de ahorro**. Sin
///   denominador real, una meta sería inventada — mismo criterio que la dona
///   del Dashboard, que solo aparece con ingreso registrado.
public struct BudgetMix: Sendable {
    public let currency: Currency
    /// `true` si los porcentajes se miden contra el ingreso. `false` si se
    /// miden contra el gasto porque no hay ingreso registrado — ahí la regla
    /// 50/30/20 no aplica y la UI no debe mostrar metas.
    public let isMeasuredAgainstIncome: Bool
    /// Contra qué se calcularon los porcentajes.
    public let denominator: Decimal
    /// Lo gastado en tipos de gasto que no volvieron etiquetados. Se reporta
    /// aparte y **nunca se reparte** entre los tres grupos.
    public let unclassified: Decimal
    /// Cuántos movimientos entraron a este cálculo — para saber si hay
    /// material suficiente antes de sugerir una regla.
    public let transactionCount: Int
    /// En cuántos meses distintos hubo movimientos.
    public let monthCount: Int

    private let amountsByGroup: [BudgetGroup: Decimal]

    /// - Parameters:
    ///   - expenses: gastos e ingresos del periodo.
    ///   - groupsByLabel: qué grupo le toca a cada par `categoría / subcategoría`,
    ///     tal como lo devolvió `SpendingClassifying`.
    ///   - viewerIdentities: para contar solo la parte propia de un gasto
    ///     compartido (ADR-0029).
    ///   - currency: la moneda a analizar. Nunca se cruzan dos.
    public init(
        expenses: [Expense],
        groupsByLabel: [String: BudgetGroup],
        viewerIdentities: [SharedListID: ParticipantID] = [:],
        currency: Currency,
        calendar: Calendar = .current) {
        self.currency = currency

        var income: Decimal = 0
        var byGroup: [BudgetGroup: Decimal] = [:]
        var unclassified: Decimal = 0
        var totalExpenses: Decimal = 0
        var counted = 0
        var months: Set<Date> = []

        for expense in expenses {
            switch expense.kind {
            case .income:
                guard expense.amount.currency == currency else { continue }
                income += expense.amount.amount
                counted += 1
                months.insert(calendar.dateInterval(of: .month, for: expense.date)?.start ?? expense.date)
            case .expense:
                let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
                guard personal.currency == currency else { continue }
                totalExpenses += personal.amount
                counted += 1
                months.insert(calendar.dateInterval(of: .month, for: expense.date)?.start ?? expense.date)
                if let group = groupsByLabel[Self.label(for: expense)] {
                    byGroup[group, default: 0] += personal.amount
                } else {
                    unclassified += personal.amount
                }
            }
        }

        self.unclassified = unclassified
        transactionCount = counted
        monthCount = months.count
        isMeasuredAgainstIncome = income > 0
        denominator = income > 0 ? income : totalExpenses

        if income > 0 {
            // El ahorro es lo que sobró: entra tanto lo que se apartó a
            // propósito como lo que simplemente no se gastó, sin doble conteo.
            byGroup[.ahorro] = income
                - (byGroup[.necesidad] ?? 0)
                - (byGroup[.deseo] ?? 0)
                - unclassified
        }
        amountsByGroup = byGroup
    }

    /// La etiqueta con la que se le pide al modelo clasificar un gasto: el par
    /// `categoría / subcategoría`, sin monto, sin fecha y sin concepto.
    ///
    /// `static` y pública a propósito: quien arma la lista que se le manda al
    /// clasificador tiene que usar exactamente esta misma forma, o las
    /// etiquetas que regresen no van a casar con ningún gasto.
    public static func label(for expense: Expense) -> String {
        let category = expense.category ?? "otro"
        guard let subcategory = expense.subcategory, !subcategory.isEmpty else { return category }
        return "\(category) / \(subcategory)"
    }

    /// Todas las etiquetas distintas de un conjunto de gastos — lo único que se
    /// le manda al modelo.
    public static func labels(in expenses: [Expense]) -> [String] {
        Array(Set(expenses.filter { $0.kind == .expense }.map(label(for:)))).sorted()
    }

    /// Cómo quedó repartido el periodo, contra la regla dada.
    ///
    /// - Parameter rule: la regla elegida, o `nil` si el usuario todavía no
    ///   elige una. Sin regla —o sin ingreso— no hay metas: solo la mezcla.
    public func shares(against rule: BudgetRule?) -> [BudgetShare] {
        let groups: [BudgetGroup] = isMeasuredAgainstIncome
            ? BudgetGroup.allCases
            // Sin ingreso no hay tramo de ahorro que mostrar: lo que se ve es
            // en qué se fue el gasto, y "lo que sobró" no existe sin saber
            // cuánto entró.
            : [.necesidad, .deseo]

        return groups.map { group in
            let amount = amountsByGroup[group] ?? 0
            return BudgetShare(
                group: group,
                amount: amount,
                share: denominator > 0 ? amount / denominator : 0,
                target: isMeasuredAgainstIncome ? rule?.target(for: group) : nil)
        }
    }

    /// Si hay material suficiente para que Lana sugiera una regla.
    ///
    /// Lo decide el código, no el modelo: sin ingreso no hay contra qué medir,
    /// y con dos compras de un solo mes cualquier recomendación sería ruido
    /// presentado como consejo.
    public var isEnoughForRecommendation: Bool {
        isMeasuredAgainstIncome && monthCount >= 2 && transactionCount >= 15
    }
}
