import Foundation
import LanaCore
import Testing
@testable import OnboardingFeature

// Feature: apple-pay-setup-guide, Property 6: El resumen de cierre corresponde
// 1:1 con los pasos de configuración.
//
// Para todo contenido de guía válido, `completionSummary` tiene exactamente un
// `CompletionStep` por cada `GuiaStep` de `shortcutSteps`, en el mismo orden y
// preservando el título de cada paso (`completionSummary.count ==
// shortcutSteps.count` y correspondencia por índice).
//
// Validates: Requirements 6.1
@MainActor
@Suite("GuiaApplePayModel — resumen de cierre (Property 6)")
struct GuiaApplePayModelSummaryPropertyTests {
    @Test(
        "El resumen de cierre corresponde 1:1 con los pasos de configuración",
        arguments: variableLengthContents)
    func summaryMirrorsShortcutSteps(content: GuiaApplePayContent) {
        let model = GuiaApplePayModel(
            mode: .onboarding,
            content: content,
            environment: InMemoryApplePayEnvironment())

        let summary = model.completionSummary
        let steps = content.shortcutSteps

        // Cardinalidad 1:1.
        #expect(summary.count == steps.count)

        // Correspondencia por índice: mismo orden, títulos preservados y el id
        // de cada paso se conserva.
        for (index, step) in steps.enumerated() {
            #expect(summary[index].title == step.title)
            #expect(summary[index].id == step.id)
        }
    }
}

// MARK: - Generación de contenidos (nonisolated)

// La colección de `arguments` se materializa al recolectar los tests, fuera del
// actor del suite, así que la generación vive en alcance no aislado. Los tipos
// de contenido son `Sendable`, de modo que compartirlos es seguro.

/// Genera contenidos válidos con `shortcutSteps` de longitud variable
/// (0…N pasos), cada uno con `id` 1-based consecutivo y un título único. El
/// resto del contenido se mantiene fijo y válido: la propiedad solo mira la
/// correspondencia entre `shortcutSteps` y `completionSummary`.
///
/// Se generan 120 contenidos (≥100 iteraciones) con longitudes que varían de
/// forma determinista para cubrir el vacío, longitudes cortas y largas.
private let variableLengthContents: [GuiaApplePayContent] = {
    var rng = SeededGenerator(seed: 0x5EED_A11E)
    return (0 ..< 120).map { iteration in
        // Longitud variable: mezcla de valores pequeños y grandes,
        // incluyendo 0 para probar el caso vacío.
        let count = iteration % 17
        let steps = (0 ..< count).map { index -> GuiaStep in
            let stepNumber = index + 1
            let title = "Paso \(stepNumber) · \(randomTitleFragment(using: &rng))"
            return GuiaStep(
                id: stepNumber,
                title: title,
                detail: "Detalle del paso \(stepNumber)",
                systemImage: "circle")
        }
        return makeContent(shortcutSteps: steps)
    }
}()

/// Construye un `GuiaApplePayContent` válido variando solo `shortcutSteps`.
private func makeContent(shortcutSteps: [GuiaStep]) -> GuiaApplePayContent {
    GuiaApplePayContent(
        deviceRequirement: DeviceRequirement(
            physicalDeviceMessage: "Requiere iPhone físico.",
            simulatorMessage: "No probable en simulador."),
        shortcutSteps: shortcutSteps,
        parameterMappings: [
            ParameterMapping(
                walletParameter: .amount,
                intentParameter: .amount,
                walletLabel: "Monto",
                intentLabel: "Monto"),
            ParameterMapping(
                walletParameter: .merchant,
                intentParameter: .merchant,
                walletLabel: "Comercio",
                intentLabel: "Comercio"),
            ParameterMapping(
                walletParameter: .cardName,
                intentParameter: .cardName,
                walletLabel: "Nombre de tarjeta",
                intentLabel: "Tarjeta")
        ],
        matching: MatchingExplanation(
            prioritySignals: [
                MatchSignal(id: 0, name: "Últimos 4", explanation: "…"),
                MatchSignal(id: 1, name: "Alias", explanation: "…")
            ],
            mismatchGuidance: "…",
            noMatchGuidance: "…"),
        limitations: [
            KnownLimitation(kind: .nfcOnly, message: "…"),
            KnownLimitation(kind: .needsReview, message: "…"),
            KnownLimitation(kind: .rejectedTx, message: "…"),
            KnownLimitation(kind: .duplicateTx, message: "…"),
            KnownLimitation(kind: .reviewEach, message: "…"),
            KnownLimitation(kind: .manualIsPrimary, message: "…")
        ])
}

/// Fragmento de título aleatorio para que los títulos varíen entre pasos y
/// entre iteraciones — así la correspondencia por título es significativa.
private func randomTitleFragment(using rng: inout SeededGenerator) -> String {
    let words = ["abrir", "crear", "seleccionar", "agregar", "guardar", "repetir", "configurar"]
    let index = Int(rng.next() % UInt64(words.count))
    return words[index]
}

/// Generador determinista (LCG) para producir contenidos reproducibles sin
/// depender del RNG del sistema — mantiene los tests estables entre corridas.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed != 0 ? seed : 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
