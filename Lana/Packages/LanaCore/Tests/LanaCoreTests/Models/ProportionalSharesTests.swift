import Foundation
import Testing
@testable import LanaCore

@Suite("ProportionalShares")
struct ProportionalSharesTests {
    // IDs fijos y ordenados (`...01` < `...02` < `...03` por `uuidString`)
    // — el desempate del residuo es por `ParticipantID`, así que un
    // `ParticipantID()` aleatorio haría el test no determinista.
    // swiftlint:disable force_unwrapping
    private let alice = ParticipantID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    private let bob = ParticipantID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    private let carla = ParticipantID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!)
    // swiftlint:enable force_unwrapping

    @Test("Dos ingresos reales se normalizan a una suma exacta de 1")
    func ingresosRealesSumanExactamenteUno() {
        let weights = [alice: Decimal(20000), bob: Decimal(15000)]

        let normalized = ProportionalShares.normalized(weights: weights, among: [alice, bob])

        #expect(normalized.values.reduce(0, +) == 1)
        // Alice va primera por ID: se divide y redondea. Bob, el último, se
        // ajusta por resta para que cierre en 1 exacto.
        #expect(normalized[alice] == (Decimal(20000) / Decimal(35000)).rounded(scale: 6, mode: .down))
        #expect(normalized[bob] == 1 - (normalized[alice] ?? 0))
    }

    @Test("Tres pesos que no dividen exacto también suman exactamente 1")
    func tresPersonasSumanExactamenteUno() {
        let weights = [alice: Decimal(1), bob: Decimal(1), carla: Decimal(1)]

        let normalized = ProportionalShares.normalized(weights: weights, among: [alice, bob, carla])

        #expect(normalized.values.reduce(0, +) == 1)
    }

    /// El bug que esto vino a arreglar: la captura a mano pasaba el roster en
    /// el orden de la pantalla y los ingresos de la lista pasaban el orden
    /// por ID, así que los mismos números congelaban centavos distintos
    /// según por dónde se hubiera entrado.
    @Test("El orden en que se pasen los participantes no cambia el resultado")
    func elOrdenDeEntradaNoCambiaElResultado() {
        let weights = [alice: Decimal(20000), bob: Decimal(15000), carla: Decimal(7000)]

        let porRoster = ProportionalShares.normalized(weights: weights, among: [carla, alice, bob])
        let porID = ProportionalShares.normalized(weights: weights, among: [alice, bob, carla])

        #expect(porRoster == porID)
    }

    @Test("Nada capturado todavía (suma cero) regresa el crudo, no revienta dividiendo entre cero")
    func sumaCeroRegresaElCrudo() {
        let weights: [ParticipantID: Decimal] = [:]

        let normalized = ProportionalShares.normalized(weights: weights, among: [alice, bob])

        #expect(normalized.isEmpty)
    }

    @Test("Un participante sin capturar nada cuenta como peso cero, no se excluye")
    func participanteSinCapturarCuentaComoCero() {
        let weights = [alice: Decimal(100)]

        let normalized = ProportionalShares.normalized(weights: weights, among: [alice, bob])

        #expect(normalized[alice] == 1)
        #expect(normalized[bob] == 0)
    }
}
