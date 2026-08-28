import Testing
@testable import LanaCore

@Suite("InMemoryExpenseParsing")
struct InMemoryExpenseParsingTests {
    @Test("Por defecto está disponible y devuelve los resultados fijos")
    func porDefectoDisponibleYDevuelveResultados() async throws {
        let result = ParseResult(concept: "café", category: "comida")
        let parser = InMemoryExpenseParsing(results: [result])

        #expect(await parser.availability == .available)
        #expect(try await parser.parse("cualquier texto") == [result])
    }

    @Test("Se puede simular cualquiera de los 4 casos de disponibilidad", arguments: [
        ParsingAvailability.available,
        .deviceNotEligible,
        .notEnabled,
        .modelNotReady,
        .unknown
    ])
    func simulaCualquierDisponibilidad(availability: ParsingAvailability) async {
        let parser = InMemoryExpenseParsing(availability: availability)
        #expect(await parser.availability == availability)
    }
}
