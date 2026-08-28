import CoreData
import Foundation
import LanaCore

/// `ExpenseStore` respaldado por Core Data + `NSPersistentCloudKitContainer`
/// (ADR-0004). Por dentro no guarda nada mutable: cada `save`/`delete`
/// inserta un `ExpenseEvent` nuevo (ADR-0005) serializado en `CDEvent.payload`;
/// leer pliega todos los eventos con `ExpenseProjection`. Core Data no sale
/// de este paquete — el resto del sistema solo ve `ExpenseStore`.
public actor CoreDataExpenseStore: ExpenseStore {
    // `internal` (no `private`), no `fileprivate` — `CoreDataCardStore.swift`
    // y `CoreDataVocabularyStore.swift` extienden este mismo actor con
    // `CardStore`/`CorrectionVocabularyStore` en archivos separados, sobre el
    // mismo container (ADR-0014: evitar un segundo `NSPersistentContainer`).
    let container: NSPersistentCloudKitContainer
    let context: NSManagedObjectContext

    /// - Parameters:
    ///   - inMemory: para tests y `#Preview` — no toca disco. Ignorado si
    ///     `storeURL` viene dado.
    ///   - storeURL: ubicación explícita del `.sqlite` en disco. `nil` usa la
    ///     ubicación default de Core Data (o `/dev/null` si `inMemory`).
    ///   - cloudKitContainerIdentifier: `nil` cae a almacenamiento local sin
    ///     iCloud (sin esto, `NSPersistentCloudKitContainerOptions` no se
    ///     configura y el store nunca intenta sincronizar). Quien construye
    ///     el store decide esto según `FileManager.ubiquityIdentityToken`.
    public init(
        inMemory: Bool = false,
        storeURL: URL? = nil,
        cloudKitContainerIdentifier: String? = nil) async throws {
        let model = LanaManagedObjectModel.make()
        let container = NSPersistentCloudKitContainer(name: "LanaPersistence", managedObjectModel: model)
        guard let description = container.persistentStoreDescriptions.first else {
            throw PersistenceError.noStoreDescription
        }
        if let storeURL {
            description.url = storeURL
        } else if inMemory {
            // `NSInMemoryStoreType` es un store real en memoria, aislado por
            // instancia — a diferencia del truco de apuntar una store SQLite
            // a `/dev/null`, que en tests corriendo en paralelo colisiona
            // entre instancias ("model configuration... incompatible").
            description.type = NSInMemoryStoreType
        }
        if let cloudKitContainerIdentifier {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudKitContainerIdentifier)
        } else {
            description.cloudKitContainerOptions = nil
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        let backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.container = container
        context = backgroundContext
    }

    /// El store de producción: sincroniza con CloudKit si hay una cuenta de
    /// iCloud activa; si no, cae a almacenamiento local sin romper nada
    /// (Docs/.claude/skills/cloudkit-sharing: "la app cae a modo local...
    /// No revientes.").
    public static func live(cloudKitContainerIdentifier: String) async throws -> CoreDataExpenseStore {
        try await CoreDataExpenseStore(
            cloudKitContainerIdentifier: CloudKitAvailability.hasActiveAccount ? cloudKitContainerIdentifier : nil)
    }

    /// Suelta el store de disco explícitamente. No hace falta en el ciclo de
    /// vida normal de la app (el container vive mientras vive la app), pero
    /// es necesario para reabrir el mismo archivo con una instancia nueva en
    /// el mismo proceso — confiar solo en ARC para soltar la conexión SQLite
    /// es una carrera (se ve como "model configuration... incompatible").
    public func close() async throws {
        try await context.perform { [container] in
            for store in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }

    public func save(_ expense: Expense) async throws {
        try await context.perform { [context] in
            let alreadyExists = try Self.rootEventExists(forRawID: expense.id.rawValue, in: context)
            let event = Self.makeEvent(for: expense, correcting: alreadyExists)
            try Self.insert(event, in: context)
            try Self.saveIfNeeded(context)
        }
    }

    public func expenses(in range: DateInterval) async throws -> [Expense] {
        try await context.perform { [context] in
            let events = try Self.allEvents(in: context)
            return ExpenseProjection.expenses(from: events)
                .filter { range.contains($0.date) }
                .sorted { $0.date < $1.date }
        }
    }

    /// El log completo, sin filtrar por rango — a diferencia de
    /// `expenses(in:)`, que ya sale plegado a saldos por transacción,
    /// `CardLedger` (`CardPaymentStore.events()`) necesita los eventos
    /// crudos para resolver correcciones/anulaciones que caigan fuera de
    /// la ventana visible (ADR-0014-adjacent: mismo actor/container,
    /// distinta forma de leer). `internal`, no `private` —
    /// `CoreDataCardPaymentStore.swift` lo comparte.
    static func allEvents(in context: NSManagedObjectContext) throws -> [ExpenseEvent] {
        let rows = try context.fetch(CDEvent.fetchRequest())
        let decoder = JSONDecoder()
        return rows.compactMap { row -> ExpenseEvent? in
            guard let payload = row.payload else { return nil }
            return try? decoder.decode(ExpenseEvent.self, from: payload)
        }
    }

    public func delete(id: Expense.ID) async throws {
        try await context.perform { [context] in
            let void = ExpenseEvent.expenseVoided(ExpenseVoided(voidsEventID: EventID(rawValue: id.rawValue)))
            try Self.insert(void, in: context)
            try Self.saveIfNeeded(context)
        }
    }

    private static func rootEventExists(forRawID rawID: UUID, in context: NSManagedObjectContext) throws -> Bool {
        let request = CDEvent.fetchRequest()
        request.predicate = NSPredicate(
            format: "id == %@ AND (kind == %@ OR kind == %@)",
            rawID as CVarArg, "expenseAdded", "incomeAdded")
        request.fetchLimit = 1
        return try context.count(for: request) > 0
    }

    private static func makeEvent(for expense: Expense, correcting alreadyExists: Bool) -> ExpenseEvent {
        guard alreadyExists else {
            switch expense.kind {
            case .expense:
                return .expenseAdded(ExpenseAdded(
                    id: EventID(rawValue: expense.id.rawValue),
                    amount: expense.amount,
                    concept: expense.concept,
                    category: expense.category ?? "",
                    subcategory: expense.subcategory,
                    date: expense.date,
                    paymentMethod: expense.paymentMethod ?? .cash,
                    sharedListID: expense.sharedListID,
                    payer: expense.payer,
                    split: expense.split,
                    needsReview: expense.needsReview))
            case .income:
                return .incomeAdded(IncomeAdded(
                    id: EventID(rawValue: expense.id.rawValue),
                    amount: expense.amount,
                    concept: expense.concept,
                    date: expense.date,
                    needsReview: expense.needsReview))
            }
        }
        return .expenseCorrected(ExpenseCorrected(
            correctsEventID: EventID(rawValue: expense.id.rawValue),
            amount: expense.amount,
            concept: expense.concept,
            category: expense.category,
            subcategory: expense.subcategory,
            date: expense.date,
            paymentMethod: expense.paymentMethod,
            needsReview: expense.needsReview))
    }

    /// `internal`, no `private` — `CoreDataCardPaymentStore.swift` también
    /// inserta eventos (`CardPaymentRecorded`) sobre este mismo container.
    static func insert(_ event: ExpenseEvent, in context: NSManagedObjectContext) throws {
        let row = CDEvent(context: context)
        row.id = event.id.rawValue
        row.recordedAt = event.recordedAt
        row.payload = try JSONEncoder().encode(event)

        switch event {
        case let .expenseAdded(added):
            row.kind = "expenseAdded"
            row.date = added.date
            row.sharedListIDValue = added.sharedListID?.rawValue
            row.sharedList = try added.sharedListID.flatMap { try existingSharedListRow(for: $0, in: context) }
        case let .incomeAdded(added):
            row.kind = "incomeAdded"
            row.date = added.date
        case let .expenseCorrected(correction):
            row.kind = "expenseCorrected"
            row.date = correction.date
        case .expenseVoided:
            row.kind = "expenseVoided"
        case let .settlementRecorded(settlement):
            row.kind = "settlementRecorded"
            row.date = settlement.date
            row.sharedListIDValue = settlement.sharedListID.rawValue
            row.sharedList = try existingSharedListRow(for: settlement.sharedListID, in: context)
        case let .cardPaymentRecorded(payment):
            row.kind = "cardPaymentRecorded"
            row.date = payment.date
        }
    }

    /// `internal`, no `private` — compartido con `CoreDataCardStore.swift` y
    /// `CoreDataVocabularyStore.swift` (ADR-0014).
    static func saveIfNeeded(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
