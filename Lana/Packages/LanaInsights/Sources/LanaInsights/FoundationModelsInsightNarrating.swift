import Foundation
import FoundationModels
import LanaCore

/// La implementación real de `InsightNarrating`: `FoundationModels` para la
/// prosa, y guardas deterministas alrededor.
///
/// El modelo recibe cifras **ya calculadas** y las narra; y para recomendar una
/// regla, elige de una lista cerrada que se valida al regresar. Igual que
/// `ParsingPipeline` en el parser, aquí el código corrige al modelo y no al
/// revés (Docs/CLAUDE.md).
public struct FoundationModelsInsightNarrating: InsightNarrating {
    public init() {}

    public var availability: ParsingAvailability {
        get async { InsightsAvailability.current }
    }

    public func narrate(_ facts: PeriodFacts) async throws -> PeriodNarrative {
        let availability = await availability
        guard availability == .available else {
            throw InsightsError.modelUnavailable(availability)
        }

        let session = LanguageModelSession(instructions: NarrationInstructions.narration())
        let response = try await session.respond(
            to: Self.prompt(for: facts),
            generating: GeneratedNarrative.self)

        return PeriodNarrative(
            summary: response.content.summary,
            patterns: response.content.patterns.filter { !$0.isEmpty },
            suggestions: response.content.suggestions.filter { !$0.isEmpty })
    }

    public func recommendRule(
        mix: [String],
        from candidates: [BudgetRule]) async throws -> BudgetRuleRecommendation? {
        guard !mix.isEmpty, !candidates.isEmpty else { return nil }
        let availability = await availability
        guard availability == .available else {
            throw InsightsError.modelUnavailable(availability)
        }

        let session = LanguageModelSession(instructions: NarrationInstructions.recommendation())
        let response = try await session.respond(
            to: Self.prompt(mix: mix, candidates: candidates),
            generating: GeneratedRuleRecommendation.self)

        return Self.validated(
            ruleID: response.content.ruleID,
            reason: response.content.reason,
            candidates: candidates)
    }

    /// La guarda que importa: si el modelo devolvió algo fuera del catálogo, la
    /// recomendación se descarta en silencio. Mostrarle al usuario una regla
    /// inventada, con porcentajes que la app no sabe medir, sería peor que no
    /// sugerir nada.
    ///
    /// Separada de la llamada para poder probarse sin Apple Intelligence — el
    /// mismo motivo por el que `AmountValidator` vive aparte del parser.
    static func validated(
        ruleID: String,
        reason: String,
        candidates: [BudgetRule]) -> BudgetRuleRecommendation? {
        let trimmed = ruleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rule = candidates.first(where: { $0.rawValue == trimmed }) else { return nil }
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanReason.isEmpty else { return nil }
        return BudgetRuleRecommendation(rule: rule, reason: cleanReason)
    }

    /// Las cifras van en el prompt, nunca en las instrucciones (ADR-0013).
    private static func prompt(for facts: PeriodFacts) -> String {
        var lines = [
            "Periodo: \(facts.periodLabel)",
            "Moneda: \(facts.currencyCode)",
            "Gastado: \(facts.totalSpent)"
        ]
        if let income = facts.totalIncome {
            lines.append("Ingresos: \(income)")
        }
        if let rate = facts.savingsRate {
            lines.append("Tasa de ahorro: \(rate)")
        }
        if let comparison = facts.comparisonWithPreviousPeriod {
            lines.append("Contra el periodo anterior: \(comparison)")
        }
        lines += section("Por categoría", facts.topCategories)
        lines += section("Por subcategoría", facts.topSubcategories)
        lines += section("Por forma de pago", facts.paymentMethods)
        lines += section("Gastos chicos y repetidos", facts.antExpenses)
        lines += section("Mezcla del presupuesto", facts.budgetMix)
        return lines.joined(separator: "\n")
    }

    private static func prompt(mix: [String], candidates: [BudgetRule]) -> String {
        """
        Así reparte su dinero hoy:
        \(mix.map { "- \($0)" }.joined(separator: "\n"))

        Reglas entre las que puedes elegir:
        \(candidates.map { "- \($0.rawValue): \($0.displayName). \($0.summary)" }.joined(separator: "\n"))
        """
    }

    private static func section(_ title: String, _ items: [String]) -> [String] {
        guard !items.isEmpty else { return [] }
        return ["\(title):"] + items.map { "- \($0)" }
    }
}
