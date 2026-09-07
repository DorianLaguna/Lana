import Foundation
import Testing
@testable import LanaCore

// Feature: apple-pay-setup-guide, Property 5: Cobertura total de las
// limitaciones conocidas.
//
// Para todo caso de `KnownLimitation.Kind` (los seis: nfcOnly, needsReview,
// rejectedTx, duplicateTx, reviewEach, manualIsPrimary),
// `GuiaApplePayContent.standard.limitations` contiene exactamente una entrada
// con ese `kind` y con `message` no vacío, sin duplicados.
//
// Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
@Suite("GuiaApplePayContent.standard.limitations — Property 5")
struct GuiaApplePayContentLimitationsTests {
    /// Property 5: para cada `Kind` existe exactamente una entrada en
    /// `.standard.limitations`, con `message` no vacío. Parametrizado sobre
    /// `Kind.allCases` y repetido para alcanzar el mínimo de 100 iteraciones
    /// que exige la estrategia de testing del diseño.
    @Test(
        "Cada Kind tiene exactamente una limitación con mensaje no vacío",
        arguments: KnownLimitation.Kind.allCases)
    func exactamenteUnaEntradaPorKind(kind: KnownLimitation.Kind) {
        let limitations = GuiaApplePayContent.standard.limitations

        // ≥100 iteraciones por caso (6 casos * 100 = 600 comprobaciones), tal
        // como pide la Testing Strategy del diseño (mínimo 100 iteraciones).
        for _ in 0 ..< 100 {
            let matching = limitations.filter { $0.kind == kind }

            // Exactamente una entrada por kind (sin faltantes ni duplicados).
            #expect(matching.count == 1)

            // El mensaje de esa entrada no está vacío.
            let message = matching.first?.message ?? ""
            #expect(!message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    /// Verificación global de cobertura y ausencia de duplicados: el conjunto
    /// de `kind` presentes es exactamente el conjunto de todos los casos, y
    /// la cantidad de entradas coincide con la cantidad de casos.
    @Test("Cobertura total y sin duplicados sobre todos los Kind")
    func coberturaTotalSinDuplicados() {
        let limitations = GuiaApplePayContent.standard.limitations
        let kinds = limitations.map(\.kind)

        // No hay duplicados: tantos kinds únicos como entradas.
        #expect(Set(kinds).count == kinds.count)

        // Cobertura total: el conjunto presente == todos los casos.
        #expect(Set(kinds) == Set(KnownLimitation.Kind.allCases))
        #expect(limitations.count == KnownLimitation.Kind.allCases.count)
    }
}
