import Foundation
import LanaCore
import Testing
@testable import LanaPersistence

/// `viewerParticipantID`/`setViewerParticipantID` (ADR-0021/ADR-0022) —
/// mismo patrón que `CoreDataSharedListStoreTests`.
extension CoreDataExpenseStoreTests {
    @Test("Sin nada guardado, viewerParticipantID regresa nil")
    func sinNadaGuardadoViewerParticipantIDRegresaNil() async throws {
        let store = try await makeStore()
        let listID = SharedListID()

        #expect(try await store.viewerParticipantID(for: listID) == nil)
    }

    @Test("Guardar y leer hace round-trip completo")
    func guardarYLeerHaceRoundTripCompleto() async throws {
        let store = try await makeStore()
        let listID = SharedListID()
        let participantID = ParticipantID()

        try await store.setViewerParticipantID(participantID, for: listID)

        #expect(try await store.viewerParticipantID(for: listID) == participantID)
    }

    @Test("Guardar de nuevo para la misma lista reemplaza, no duplica")
    func guardarDeNuevoParaLaMismaListaReemplaza() async throws {
        let store = try await makeStore()
        let listID = SharedListID()
        let first = ParticipantID()
        let second = ParticipantID()

        try await store.setViewerParticipantID(first, for: listID)
        try await store.setViewerParticipantID(second, for: listID)

        #expect(try await store.viewerParticipantID(for: listID) == second)
    }

    @Test("Cada lista guarda su propio participante, sin cruzarse")
    func cadaListaGuardaSuPropioParticipante() async throws {
        let store = try await makeStore()
        let firstList = SharedListID()
        let secondList = SharedListID()
        let firstParticipant = ParticipantID()
        let secondParticipant = ParticipantID()

        try await store.setViewerParticipantID(firstParticipant, for: firstList)
        try await store.setViewerParticipantID(secondParticipant, for: secondList)

        #expect(try await store.viewerParticipantID(for: firstList) == firstParticipant)
        #expect(try await store.viewerParticipantID(for: secondList) == secondParticipant)
    }
}
