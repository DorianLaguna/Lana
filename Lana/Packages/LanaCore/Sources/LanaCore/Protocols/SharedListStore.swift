import Foundation

/// Dónde se guardan y leen las listas de gastos compartidos (Fase 8). `save`
/// es upsert directo — una `SharedList` es dato de referencia editable, no
/// un evento (mismo criterio que `Card`, ADR-0014). Los gastos y
/// liquidaciones de la lista sí son eventos: `recordSettlement` inserta un
/// `SettlementRecorded`, y los gastos compartidos se guardan por el mismo
/// `ExpenseStore.save(_:)` que cualquier otro gasto — `Expense` ya carga
/// `sharedListID`/`payer`/`split` desde antes de este bloque, así que no
/// hace falta un segundo camino de escritura para eso.
public protocol SharedListStore: Sendable { // swiftlint:disable:this protocol_naming_convention
    func save(_ list: SharedList) async throws
    func lists() async throws -> [SharedList]
    func delete(id: SharedListID) async throws
    func recordSettlement(_ settlement: SettlementRecorded) async throws
    /// El log completo, sin filtrar por lista — `PersonLedger` necesita
    /// eventos fuera de un rango visible para resolver correcciones/
    /// anulaciones (mismo criterio que `CardPaymentStore.events()`).
    func events() async throws -> [ExpenseEvent]
    /// Prepara (o reutiliza) la invitación de `CKShare` para esta lista y
    /// regresa la URL para invitar por share sheet (ADR-0020). `nil` sin
    /// cuenta de iCloud activa — no es un error, es el mismo modo local de
    /// siempre (Docs/.claude/skills/cloudkit-sharing: "la app cae a modo
    /// local... no revientes"). La firma es Foundation-only a propósito:
    /// ninguna feature ve `CloudKit` directamente (Docs/ARCHITECTURE.md).
    func shareURL(for id: SharedListID) async throws -> URL?
    /// Qué participante de esta lista es "yo", en este dispositivo
    /// (ADR-0021/ADR-0022). Vive en la zona **privada** del usuario, nunca
    /// en la lista misma — sincroniza entre los propios dispositivos del
    /// usuario vía su CloudKit privado, pero nunca se comparte con los
    /// demás participantes (el mismo roster significa algo distinto para
    /// cada quien). `nil` si todavía no se marcó.
    func viewerParticipantID(for id: SharedListID) async throws -> ParticipantID?
    /// Marca cuál participante es "yo" para esta lista, en este dispositivo.
    func setViewerParticipantID(_ participantID: ParticipantID, for id: SharedListID) async throws
}

/// Implementación en memoria para tests y `#Preview`.
public actor InMemorySharedListStore: SharedListStore {
    private var listsByID: [SharedListID: SharedList]
    private var storedEvents: [ExpenseEvent]
    private var viewerIdentities: [SharedListID: ParticipantID]

    public init(seed: [SharedList] = [], events: [ExpenseEvent] = []) {
        listsByID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
        storedEvents = events
        viewerIdentities = [:]
    }

    public func save(_ list: SharedList) async throws {
        listsByID[list.id] = list
    }

    public func lists() async throws -> [SharedList] {
        listsByID.values.sorted { $0.name < $1.name }
    }

    public func delete(id: SharedListID) async throws {
        listsByID.removeValue(forKey: id)
    }

    public func recordSettlement(_ settlement: SettlementRecorded) async throws {
        storedEvents.append(.settlementRecorded(settlement))
    }

    public func events() async throws -> [ExpenseEvent] {
        storedEvents
    }

    /// Para que los tests puedan sembrar gastos compartidos igual que lo
    /// haría `ExpenseStore.save(_:)` en producción, sin duplicar ese store.
    public func seedEvent(_ event: ExpenseEvent) async {
        storedEvents.append(event)
    }

    /// No hay CloudKit en memoria — siempre `nil`, igual que sin cuenta de
    /// iCloud activa en producción.
    public func shareURL(for id: SharedListID) async throws -> URL? {
        nil
    }

    public func viewerParticipantID(for id: SharedListID) async throws -> ParticipantID? {
        viewerIdentities[id]
    }

    public func setViewerParticipantID(_ participantID: ParticipantID, for id: SharedListID) async throws {
        viewerIdentities[id] = participantID
    }
}
