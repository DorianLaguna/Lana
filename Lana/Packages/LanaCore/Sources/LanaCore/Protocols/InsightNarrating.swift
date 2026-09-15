import Foundation

/// Las cifras de un periodo, **ya calculadas y ya formateadas a texto** por
/// `LanaCore`, listas para que el modelo las narre.
///
/// Es la frontera del contrato: el modelo recibe esto y nada más. Si para
/// escribir una frase le faltara un número, el número se agrega aquí —
/// calculado por el código— y no se le pide al modelo que lo saque
/// (Docs/CLAUDE.md: "el modelo no calcula, solo narra").
///
/// Todo llega como `String` a propósito: un `Decimal` invitaría a que alguien
/// le pida al modelo "sácame el porcentaje", que es justo lo que no debe pasar.
public struct PeriodFacts: Sendable, Hashable {
    /// Cómo se llama el periodo en palabras: "septiembre de 2026", "2026".
    public let periodLabel: String
    /// La moneda de estas cifras. Un periodo con dos monedas produce dos
    /// `PeriodFacts`, nunca uno con los totales cruzados.
    public let currencyCode: String
    /// Lo gastado, ya formateado ("$12,340.00").
    public let totalSpent: String
    /// Lo ingresado. `nil` si no hay ingreso registrado.
    public let totalIncome: String?
    /// La tasa de ahorro ya en porcentaje ("25%"). `nil` sin ingreso.
    public let savingsRate: String?
    /// Las categorías más grandes, ya con su monto ("comida: $3,200.00").
    public let topCategories: [String]
    /// Las subcategorías más grandes, igual de formateadas.
    public let topSubcategories: [String]
    /// El desglose por forma de pago.
    public let paymentMethods: [String]
    /// Cómo cambió contra el periodo anterior ("subió $800.00, 18% más").
    /// `nil` si no hay con qué comparar.
    public let comparisonWithPreviousPeriod: String?
    /// Los gastos chicos y repetidos ("café: 24 veces, $1,080.00").
    public let antExpenses: [String]
    /// Cómo quedó la mezcla del presupuesto ("Necesidades: 55%"). Vacío si
    /// todavía no hay clasificación.
    public let budgetMix: [String]

    public init(
        periodLabel: String,
        currencyCode: String,
        totalSpent: String,
        totalIncome: String? = nil,
        savingsRate: String? = nil,
        topCategories: [String] = [],
        topSubcategories: [String] = [],
        paymentMethods: [String] = [],
        comparisonWithPreviousPeriod: String? = nil,
        antExpenses: [String] = [],
        budgetMix: [String] = []) {
        self.periodLabel = periodLabel
        self.currencyCode = currencyCode
        self.totalSpent = totalSpent
        self.totalIncome = totalIncome
        self.savingsRate = savingsRate
        self.topCategories = topCategories
        self.topSubcategories = topSubcategories
        self.paymentMethods = paymentMethods
        self.comparisonWithPreviousPeriod = comparisonWithPreviousPeriod
        self.antExpenses = antExpenses
        self.budgetMix = budgetMix
    }
}

/// Lo que el modelo escribe sobre un periodo.
public struct PeriodNarrative: Sendable, Hashable {
    /// Qué pasó con el dinero, en prosa corta.
    public let summary: String
    /// Hábitos que se notan en los datos.
    public let patterns: [String]
    /// Dónde se podría recortar. Son opciones, nunca correcciones: Lana no
    /// regaña (Docs/CLAUDE.md → Tono).
    public let suggestions: [String]

    public init(summary: String, patterns: [String] = [], suggestions: [String] = []) {
        self.summary = summary
        self.patterns = patterns
        self.suggestions = suggestions
    }
}

/// La regla que Lana propone, con su porqué en una línea.
public struct BudgetRuleRecommendation: Sendable, Hashable {
    public let rule: BudgetRule
    public let reason: String

    public init(rule: BudgetRule, reason: String) {
        self.rule = rule
        self.reason = reason
    }
}

/// Narra cifras ya calculadas y elige de listas cerradas. Nunca hace
/// aritmética.
public protocol InsightNarrating: Sendable {
    /// Si el modelo del sistema está disponible. Siempre se consulta antes de
    /// crear una sesión (Docs/CLAUDE.md).
    var availability: ParsingAvailability { get async }

    /// Redacta el resumen, los patrones y las sugerencias de un periodo.
    func narrate(_ facts: PeriodFacts) async throws -> PeriodNarrative

    /// Propone una de las reglas del catálogo a partir de la mezcla real.
    ///
    /// - Parameters:
    ///   - mix: la mezcla ya calculada, en texto ("Necesidades: 55%").
    ///   - candidates: las únicas reglas entre las que puede elegir.
    /// - Returns: `nil` si el modelo no eligió, o si eligió algo fuera del
    ///   catálogo — una regla inventada no se le muestra al usuario.
    func recommendRule(mix: [String], from candidates: [BudgetRule]) async throws -> BudgetRuleRecommendation?
}

/// Implementación en memoria para tests y `#Preview`: devuelve lo que se le
/// configure, sin invocar ningún modelo.
public struct InMemoryInsightNarrating: InsightNarrating {
    private let fixedNarrative: PeriodNarrative
    private let fixedRecommendation: BudgetRuleRecommendation?
    private let fixedAvailability: ParsingAvailability

    public init(
        narrative: PeriodNarrative = PeriodNarrative(summary: ""),
        recommendation: BudgetRuleRecommendation? = nil,
        availability: ParsingAvailability = .available) {
        fixedNarrative = narrative
        fixedRecommendation = recommendation
        fixedAvailability = availability
    }

    public var availability: ParsingAvailability {
        get async { fixedAvailability }
    }

    public func narrate(_: PeriodFacts) async throws -> PeriodNarrative {
        fixedNarrative
    }

    public func recommendRule(mix _: [String], from _: [BudgetRule]) async throws -> BudgetRuleRecommendation? {
        fixedRecommendation
    }
}
