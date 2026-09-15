import Foundation

/// Todas las sumas de un periodo — un mes, un año, o el rango que sea. Es la
/// única aritmética de agregación del proyecto: el Dashboard mensual, el
/// detalle de tarjeta y la vista anual la comparten en vez de tener cada uno
/// su propia copia (antes había dos, y la de `CardDetailModel` ignoraba la
/// parte real de un gasto compartido).
///
/// Reglas que respeta, todas del proyecto y ninguna negociable:
///
/// - **Nunca suma monedas distintas.** Todo agregado es `[Currency: Decimal]`
///   (Docs/CONVENTIONS.md → Multi-moneda).
/// - **De un gasto compartido cuenta solo la parte de quien mira**, vía
///   `Expense.personalAmount(viewerIdentities:)` (ADR-0029). De un ingreso
///   cuenta el monto completo: un ingreso no se divide.
/// - **No persiste nada.** Se recalcula plegando lo que se le pase (ADR-0005).
///
/// Las sumas se hacen una sola vez, al construirlo, no en cada lectura: esto
/// lo lee una vista de SwiftUI, que consulta sus propiedades muchas veces por
/// cada refresco.
public struct PeriodStatistics: Sendable {
    private let expensesByCurrency: [Currency: Decimal]
    private let incomeByCurrency: [Currency: Decimal]
    private let categoryByCurrency: [Currency: [String: Decimal]]
    private let subcategoryByCurrency: [Currency: [String: Decimal]]
    private let paymentMethodByCurrency: [Currency: [String: Decimal]]
    private let incomeCategoryByCurrency: [Currency: [String: Decimal]]

    /// Cuántos movimientos entraron a estas sumas. Sirve para decidir si hay
    /// material suficiente para un análisis, sin volver a recorrer nada.
    public let transactionCount: Int

    /// - Parameters:
    ///   - expenses: gastos e ingresos del periodo, mezclados — se separan
    ///     aquí por `kind`.
    ///   - viewerIdentities: qué participante es "yo" en cada lista
    ///     compartida. Quien llama lo resuelve antes (es `async` en el store
    ///     real, ADR-0022). Vacío es válido: sin identidad marcada, un gasto
    ///     compartido cuenta completo, que es el respaldo seguro de
    ///     `personalAmount`.
    public init(expenses: [Expense], viewerIdentities: [SharedListID: ParticipantID] = [:]) {
        var expensesByCurrency: [Currency: Decimal] = [:]
        var incomeByCurrency: [Currency: Decimal] = [:]
        var categoryByCurrency: [Currency: [String: Decimal]] = [:]
        var subcategoryByCurrency: [Currency: [String: Decimal]] = [:]
        var paymentMethodByCurrency: [Currency: [String: Decimal]] = [:]
        var incomeCategoryByCurrency: [Currency: [String: Decimal]] = [:]

        for expense in expenses {
            switch expense.kind {
            case .expense:
                let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
                let currency = personal.currency
                expensesByCurrency[currency, default: 0] += personal.amount
                categoryByCurrency[currency, default: [:]][expense.category ?? "otro", default: 0] += personal.amount
                let label = Self.paymentMethodLabel(expense.paymentMethod)
                paymentMethodByCurrency[currency, default: [:]][label, default: 0] += personal.amount
                // Sin subcategoría no entra: "Top subcategorías" con una
                // rebanada "otro" que se come todo no dice nada útil.
                if let subcategory = expense.subcategory, !subcategory.isEmpty {
                    subcategoryByCurrency[currency, default: [:]][subcategory, default: 0] += personal.amount
                }
            case .income:
                let currency = expense.amount.currency
                incomeByCurrency[currency, default: 0] += expense.amount.amount
                // Los ingresos se categorizan con su propio catálogo
                // (`IncomeCategory`, ADR-0040) y se suman aparte: un ingreso
                // nunca entra al desglose de gastos ni al revés.
                let category = expense.category ?? "otro"
                incomeCategoryByCurrency[currency, default: [:]][category, default: 0] += expense.amount.amount
            }
        }

        self.expensesByCurrency = expensesByCurrency
        self.incomeByCurrency = incomeByCurrency
        self.categoryByCurrency = categoryByCurrency
        self.subcategoryByCurrency = subcategoryByCurrency
        self.paymentMethodByCurrency = paymentMethodByCurrency
        self.incomeCategoryByCurrency = incomeCategoryByCurrency
        transactionCount = expenses.count
    }

    /// Las monedas presentes en el periodo, en orden estable. Cada una se
    /// presenta en su propio bloque: no hay un total que las cruce.
    public var currencies: [Currency] {
        Set(expensesByCurrency.keys)
            .union(incomeByCurrency.keys)
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Gastos e ingresos del periodo, un renglón por moneda.
    public var totals: [PeriodTotal] {
        currencies.map { currency in
            PeriodTotal(
                currency: currency,
                expenses: expensesByCurrency[currency] ?? 0,
                income: incomeByCurrency[currency] ?? 0)
        }
    }

    /// El total de una sola moneda, o `nil` si esa moneda no aparece.
    public func total(in currency: Currency) -> PeriodTotal? {
        guard expensesByCurrency[currency] != nil || incomeByCurrency[currency] != nil else { return nil }
        return PeriodTotal(
            currency: currency,
            expenses: expensesByCurrency[currency] ?? 0,
            income: incomeByCurrency[currency] ?? 0)
    }

    /// El desglose por categoría de todas las monedas, de mayor a menor.
    ///
    /// - Important: mezcla monedas en una sola lista **para presentarlas por
    ///   separado**, no para sumarlas: cada `CategoryTotal` trae la suya. Una
    ///   gráfica que compare barras entre sí tiene que usar
    ///   `categoryTotals(in:)`, o estaría comparando pesos contra dólares.
    public var categoryTotals: [CategoryTotal] {
        Self.flatten(categoryByCurrency)
    }

    /// El desglose por categoría de una sola moneda, de mayor a menor — el que
    /// deben usar las gráficas.
    public func categoryTotals(in currency: Currency) -> [CategoryTotal] {
        Self.flatten([currency: categoryByCurrency[currency] ?? [:]])
    }

    /// El desglose por subcategoría de una sola moneda, de mayor a menor. Los
    /// gastos sin subcategoría no aparecen.
    public func subcategoryTotals(in currency: Currency) -> [CategoryTotal] {
        Self.flatten([currency: subcategoryByCurrency[currency] ?? [:]])
    }

    /// El desglose por forma de pago de todas las monedas, de mayor a menor.
    /// Solo gastos — un ingreso no se "paga" con nada.
    public var paymentMethodTotals: [CategoryTotal] {
        Self.flatten(paymentMethodByCurrency)
    }

    /// El desglose por forma de pago de una sola moneda, de mayor a menor.
    public func paymentMethodTotals(in currency: Currency) -> [CategoryTotal] {
        Self.flatten([currency: paymentMethodByCurrency[currency] ?? [:]])
    }

    /// De dónde vino el dinero, por categoría, en una sola moneda y de mayor a
    /// menor (ADR-0040).
    ///
    /// Va aparte de `categoryTotals` a propósito: son catálogos distintos
    /// (`IncomeCategory` contra `SuggestedCategory`) y juntarlos en una lista
    /// daría un desglose donde "sueldo" y "comida" compiten por el mismo
    /// espacio sin significar lo mismo.
    public func incomeCategoryTotals(in currency: Currency) -> [CategoryTotal] {
        Self.flatten([currency: incomeCategoryByCurrency[currency] ?? [:]])
    }

    /// Qué proporción del ingreso no se gastó, como fracción (`0.25` = 25%).
    ///
    /// `nil` si no hay ingreso registrado en esa moneda: sin denominador la
    /// tasa no existe, y mostrar `0%` sería afirmar que no se ahorró nada
    /// cuando lo que pasa es que no se sabe. Puede ser negativa — se gastó más
    /// de lo que entró.
    public func savingsRate(in currency: Currency) -> Decimal? {
        guard let income = incomeByCurrency[currency], income > 0 else { return nil }
        let expenses = expensesByCurrency[currency] ?? 0
        return (income - expenses) / income
    }

    /// La etiqueta con la que se agrupa una forma de pago. No distingue
    /// tarjeta por tarjeta, solo el tipo — cruzar eso con `CardStore` es otra
    /// pantalla.
    ///
    /// `nil` cae en efectivo: `Expense.paymentMethod` solo es `nil` en
    /// ingresos y en gastos viejos anteriores al picker (ADR-0035).
    public static func paymentMethodLabel(_ method: PaymentMethod?) -> String {
        switch method {
        case .cash, nil: "efectivo"
        case .debit: "débito"
        case .credit: "crédito"
        case .transfer: "transferencia"
        }
    }

    /// Desempaqueta un `[Currency: [String: Decimal]]` a `[CategoryTotal]`
    /// ordenado de mayor a menor. Los empates se rompen por nombre para que el
    /// orden no baile entre corridas (los diccionarios no tienen orden).
    private static func flatten(_ totals: [Currency: [String: Decimal]]) -> [CategoryTotal] {
        var result: [CategoryTotal] = []
        for (currency, byLabel) in totals {
            for (label, amount) in byLabel {
                result.append(CategoryTotal(category: label, amount: amount, currency: currency))
            }
        }
        return result.sorted { first, second in
            first.amount == second.amount
                ? first.category < second.category
                : first.amount > second.amount
        }
    }
}
