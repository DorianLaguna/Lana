import Foundation
import LanaCore

/// Preguntar: de un toque o escribiéndolo.
///
/// Los dos caminos son distintos a propósito. **Un chip no pasa por el
/// modelo**: el chip ya dice cuál de los cálculos deterministas corresponde, así
/// que adivinarlo con Apple Intelligence sería pagar espera —y dejar sin
/// respuesta a quien no lo tenga— por un mapeo decidido desde que se escribió el
/// chip. La pregunta escrita sí lo necesita: ahí hay lenguaje que entender.
///
/// Vive aparte de `InsightsModel.swift` para que ese archivo no rebase el largo
/// máximo (`swiftlint`), igual que `InsightsModelCache.swift`.
public extension InsightsModel {
    /// Las preguntas de un toque que se pueden contestar sobre el periodo que
    /// se está viendo. Viendo el año, las que necesitan un mes no se ofrecen.
    var quickAnswers: [QuickAnswer] {
        QuickAnswer.available(for: queryPeriod)
    }

    /// Contesta un chip **sin modelo**: corre su cálculo y muestra el resultado.
    ///
    /// No consulta `availability` ni puede fallar por falta de Apple
    /// Intelligence — es aritmética sobre lo que el usuario ya registró.
    func ask(_ quick: QuickAnswer) async {
        guard !isAnswering else { return }
        question = quick.title
        isAnswering = true
        answer = nil
        errorMessage = nil
        defer { isAnswering = false }
        answer = await quick.answer(using: toolbox, viewing: queryPeriod, calendar: calendar)
    }

    /// Contesta lo que el usuario escribió, con el modelo.
    ///
    /// El modelo no recibe los movimientos: elige qué cálculo determinista
    /// correr y narra el resultado (`LedgerToolbox`, Docs/CLAUDE.md).
    func ask() async {
        let clean = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isAnswering else { return }
        isAnswering = true
        answer = nil
        errorMessage = nil
        defer { isAnswering = false }
        do {
            // La pregunta viaja con el periodo que el usuario tiene enfrente:
            // "¿cuáles fueron mis gastos más grandes?" mirando agosto se
            // contestaba sobre septiembre, porque la pregunta no nombra el mes
            // —ya se está viendo— y el modelo solo tenía la fecha de hoy.
            answer = try await querying.answer(clean, viewing: queryPeriod)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Borra la pregunta y su respuesta, sin tocar el análisis ni lo ya
    /// recordado de otros periodos.
    ///
    /// Es distinto de `onDismiss()`, que tira toda la caché: aquí solo se
    /// limpia la conversación para volver a preguntar en blanco.
    func clearQuestion() {
        question = ""
        answer = nil
        errorMessage = nil
    }
}
