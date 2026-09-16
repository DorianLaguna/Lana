import Foundation
import LanaCore

/// La carga de los hallazgos (`Findings`, LanaCore).
///
/// Va por su propio camino, **fuera de la guarda de disponibilidad** que
/// envuelve al análisis narrado: son aritmética sobre lo que el usuario ya
/// registró, así que apagarlos sin Apple Intelligence repetiría el error que
/// tenía la pantalla entera antes de esta tanda.
///
/// Vive aparte de `InsightsModel.swift` para que ese archivo no rebase el largo
/// máximo (`swiftlint`), igual que la caché y las preguntas.
extension InsightsModel {
    /// Resuelve los hallazgos del periodo visible.
    ///
    /// Solo por mes: el motor compara contra el mes anterior y mide el mes a
    /// medias contra el mismo día. Viendo el año no hay nada honesto que decir
    /// con esos detectores, así que no se ofrece nada — el mismo criterio que
    /// siguen los chips (`QuickAnswer.supports(_:)`).
    func loadFindings() async {
        guard period == .month else {
            findings = []
            return
        }

        let key = currentKey
        if let remembered = findingsCache[key] {
            findings = remembered
            return
        }

        guard let range = findingsRange() else {
            findings = []
            return
        }

        guard let expenses = try? await store.expenses(in: range) else {
            // Que falle esta lectura no puede tumbar la pantalla: los chips y
            // el análisis narrado siguen su camino.
            findings = []
            return
        }
        let identities = await sharedListStore.viewerIdentities(for: expenses)
        let statistics = PeriodStatistics(expenses: expenses, viewerIdentities: identities)
        guard let currency = Self.primaryCurrency(of: statistics) else {
            findingsCache[key] = []
            findings = []
            return
        }

        let resolved = Findings.resolve(
            Findings.Input(
                month: anchor,
                currency: currency,
                expenses: expenses,
                viewerIdentities: identities,
                asOf: Date()),
            calendar: calendar)
        findingsCache[key] = resolved
        findings = resolved
    }

    /// El mes visible **más la historia que necesitan los detectores que
    /// comparan**. Sin ella, "vas arriba de como ibas" no existe.
    private func findingsRange() -> DateInterval? {
        guard let month = calendar.dateInterval(of: .month, for: anchor) else { return nil }
        guard let start = calendar.date(
            byAdding: .month,
            value: -Findings.monthsOfHistoryNeeded,
            to: month.start)
        else { return nil }
        // Mismo ajuste de -1 segundo que el resto: `DateInterval.contains`
        // incluye los dos extremos.
        return DateInterval(start: start, end: month.end.addingTimeInterval(-1))
    }
}
