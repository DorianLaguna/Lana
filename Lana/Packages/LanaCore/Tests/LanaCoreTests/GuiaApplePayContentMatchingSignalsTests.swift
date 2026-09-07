import Foundation
import Testing
@testable import LanaCore

// Feature: apple-pay-setup-guide, Property 4: Las señales de emparejamiento
// están ordenadas por prioridad, con últimos-4-dígitos primero.
//
// Para toda la secuencia `MatchingExplanation.prioritySignals`, los
// `MatchSignal.id` son consecutivos desde 0, estrictamente crecientes y sin
// duplicados, y la señal de mayor prioridad (índice 0) corresponde a los
// últimos 4 dígitos, seguida por el alias / nombre en Wallet.
//
// Validates: Requirements 3.1
@Suite("GuiaApplePayContent — señales de emparejamiento (Property 4)")
struct GuiaApplePayContentMatchingSignalsTests {
    /// El espacio de entrada de esta propiedad es la única secuencia estática
    /// `GuiaApplePayContent.standard.matching.prioritySignals`. Para cumplir el
    /// mínimo de 100 iteraciones exigido por la estrategia de pruebas, se
    /// reevalúa el invariante sobre 100 permutaciones aleatorias de la
    /// secuencia: reordenar las señales no debe engañar la verificación de
    /// prioridad, que depende exclusivamente de `MatchSignal.id`.
    @Test(
        "Property 4: los ids son [0..m] estrictamente crecientes y el índice 0 son los últimos 4 dígitos",
        arguments: 0 ..< 100)
    func prioritySignalsOrderedByPriority(iteration _: Int) {
        let signals = GuiaApplePayContent.standard.matching.prioritySignals

        // Debe haber al menos dos señales: últimos 4 dígitos y alias/NombreEnWallet.
        #expect(signals.count >= 2)

        // Ordenar por `id` es la fuente de verdad de la prioridad; la propiedad
        // debe sostenerse sin importar el orden en que iteremos la colección.
        let ordered = signals.shuffled().sorted { $0.id < $1.id }

        // Ids consecutivos desde 0, estrictamente crecientes y sin duplicados:
        // ids == [0, 1, ..., m].
        let expectedIDs = Array(0 ..< ordered.count)
        #expect(ordered.map(\.id) == expectedIDs)

        // Sin duplicados de id (implícito en la igualdad anterior, verificado
        // explícitamente para claridad del diagnóstico).
        #expect(Set(ordered.map(\.id)).count == ordered.count)

        // Estrictamente creciente entre elementos consecutivos.
        for pair in zip(ordered, ordered.dropFirst()) {
            #expect(pair.1.id > pair.0.id)
        }

        // Índice 0 (mayor prioridad) corresponde a los últimos 4 dígitos.
        let highestPriority = ordered[0]
        #expect(highestPriority.id == 0)
        #expect(highestPriority.name.contains("4 dígitos"))

        // La siguiente señal corresponde al alias / nombre en Wallet.
        let secondPriority = ordered[1]
        #expect(secondPriority.id == 1)
        let secondName = secondPriority.name.lowercased()
        #expect(secondName.contains("alias") || secondName.contains("wallet"))
    }
}
