import Foundation
import LanaCore
import Testing
@testable import LanaInsights

/// El código corrige al modelo, no al revés — mismo principio que
/// `ParsingPipeline` con el monto (Docs/CLAUDE.md).
@Suite("La regla recomendada se valida contra el catálogo")
struct RuleRecommendationGuardTests {
    private func validated(_ ruleID: String, reason: String = "porque encaja") -> BudgetRuleRecommendation? {
        FoundationModelsInsightNarrating.validated(
            ruleID: ruleID,
            reason: reason,
            candidates: BudgetRule.allCases)
    }

    @Test("Una regla del catálogo pasa")
    func unaReglaDelCatalogoPasa() throws {
        let recommendation = try #require(validated(BudgetRule.seventyTwentyTen.rawValue))
        #expect(recommendation.rule == .seventyTwentyTen)
    }

    @Test("Una regla inventada se descarta y no llega a la UI")
    func unaReglaInventadaSeDescarta() {
        #expect(validated("cuarentaCuarentaVeinte") == nil)
        #expect(validated("50/30/20") == nil)
        #expect(validated("") == nil)
    }

    @Test("Una regla que no estaba entre las ofrecidas se descarta")
    func unaReglaFueraDeLasOfrecidasSeDescarta() {
        let recommendation = FoundationModelsInsightNarrating.validated(
            ruleID: BudgetRule.payYourselfFirst.rawValue,
            reason: "porque sí",
            candidates: [.fiftyThirtyTwenty, .seventyTwentyTen])
        #expect(recommendation == nil)
    }

    @Test("Espacios de más alrededor del identificador no tumban una regla válida")
    func espaciosDeMasNoTumbanUnaReglaValida() throws {
        let recommendation = try #require(validated("  \(BudgetRule.sixtyTwentyTwenty.rawValue)\n"))
        #expect(recommendation.rule == .sixtyTwentyTwenty)
    }

    @Test("Una recomendación sin porqué no se muestra — sería una regla caída del cielo")
    func sinPorqueNoSeMuestra() {
        #expect(validated(BudgetRule.fiftyThirtyTwenty.rawValue, reason: "   ") == nil)
    }
}
