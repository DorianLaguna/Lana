import Foundation
import LanaCore

/// Lo ya analizado en esta sesión de la pantalla, por periodo.
///
/// Analizar cuesta una lectura del store más dos llamadas al modelo, así que
/// volver a un periodo que ya se vio no debe pagarlo otra vez: navegar entre
/// mes y año, o de un mes al anterior y de regreso, sale instantáneo y sin
/// spinner.
///
/// Vive solo mientras la pantalla está abierta —`onDismiss()` la vacía— porque
/// los datos pueden haber cambiado mientras tanto, y una cifra vieja presentada
/// como fresca es peor que esperar.
///
/// Vive en su propio archivo para que `InsightsModel.swift` no rebase el largo
/// máximo (`swiftlint`).
extension InsightsModel {
    struct AnalysisKey: Hashable {
        let period: InsightsPeriod
        let year: Int
        /// `nil` cuando el periodo es el año completo.
        let month: Int?
    }

    struct Analysis {
        let mix: BudgetMix?
        let narrative: PeriodNarrative?
        let suggestion: BudgetRuleRecommendation?
        let analyzedCurrency: Currency?
        let otherCurrencies: [Currency]
    }

    var currentKey: AnalysisKey {
        AnalysisKey(
            period: period,
            year: calendar.component(.year, from: anchor),
            month: period == .month ? calendar.component(.month, from: anchor) : nil)
    }

    func apply(_ analysis: Analysis) {
        mix = analysis.mix
        narrative = analysis.narrative
        suggestion = analysis.suggestion
        analyzedCurrency = analysis.analyzedCurrency
        otherCurrencies = analysis.otherCurrencies
    }

    /// Quita la sugerencia de todo lo ya analizado: elegir o descartar una
    /// regla vale para la sesión entera, y sin esto volver a un periodo que ya
    /// se había visto la resucitaría.
    func forgetSuggestions() {
        cache = cache.mapValues { analysis in
            Analysis(
                mix: analysis.mix,
                narrative: analysis.narrative,
                suggestion: nil,
                analyzedCurrency: analysis.analyzedCurrency,
                otherCurrencies: analysis.otherCurrencies)
        }
    }
}
