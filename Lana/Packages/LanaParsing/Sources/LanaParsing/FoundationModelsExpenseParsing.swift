import Foundation
import FoundationModels
import LanaCore

public enum ParsingError: LocalizedError, Sendable {
    case modelUnavailable(ParsingAvailability)

    public var errorDescription: String? {
        switch self {
        case let .modelUnavailable(availability):
            "El modelo del sistema no está disponible ahora mismo (\(availability))."
        }
    }
}

/// La implementación real de `ExpenseParsing`: `FoundationModels` + la
/// validación determinista de `ParsingPipeline`. Siempre revisa
/// `availability` antes de crear una sesión
/// (Docs/.claude/skills/foundation-models).
public struct FoundationModelsExpenseParsing: ExpenseParsing {
    private let vocabularyStore: CorrectionVocabularyStore?
    // Vivos, no snapshots — `cardStore`/`expenseStore` se consultan en cada
    // `parse(_:)`, igual que `vocabularyStore` ya hacía. Antes,
    // `subcategoriesByCategory`/`cardAliases` llegaban precalculados una
    // sola vez al construir esto (en `AppDependencies.live()`, que solo
    // corre una vez al abrir la app) — una tarjeta agregada a medio sesión
    // nunca entraba al vocabulario del modelo hasta reiniciar la app, el
    // bug real detrás de "le digo con qué tarjeta y no la reconoce".
    private let cardStore: (any CardStore)?
    private let expenseStore: (any ExpenseStore)?
    private let sharedListStore: (any SharedListStore)?
    private let subcategoryMatcher = SubcategoryMatcher()
    private let dateExtractor = RelativeDateExtractor()

    public init(
        vocabularyStore: CorrectionVocabularyStore? = nil,
        cardStore: (any CardStore)? = nil,
        expenseStore: (any ExpenseStore)? = nil,
        sharedListStore: (any SharedListStore)? = nil) {
        self.vocabularyStore = vocabularyStore
        self.cardStore = cardStore
        self.expenseStore = expenseStore
        self.sharedListStore = sharedListStore
    }

    public var availability: ParsingAvailability {
        ParserAvailability.current
    }

    public func parse(_ text: String) async throws -> [ParseResult] {
        guard availability == .available else {
            throw ParsingError.modelUnavailable(availability)
        }

        let vocabulary = await vocabularyStore?.topEntries(limit: 20) ?? []
        let cardAliases = await (try? cardStore?.cards().map(\.alias)) ?? []
        let subcategoriesByCategory = await Self.loadSubcategoriesByCategory(from: expenseStore)
        let participantNames = await Self.loadSharedParticipantNames(from: sharedListStore)
        let instructions = ParserInstructions.build(
            subcategoriesByCategory: subcategoriesByCategory,
            correctionVocabulary: vocabulary,
            cardAliases: cardAliases,
            sharedParticipantNames: participantNames)

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: text, generating: ParsedTransactionBatch.self)
        let pipeline = ParsingPipeline.process(response.content, rawText: text)
        // Una sola fecha para todo el lote — el modelo nunca calcula esto
        // (ver doc comment de `RelativeDateExtractor`), y una frase que
        // describe varios gastos casi siempre los describe todos en el
        // mismo momento ("ayer compré esto y aquello").
        let date = dateExtractor.date(in: text)

        return pipeline.transactions.map { validated in
            let code = validated.transaction.currencyCode.isEmpty ? "MXN" : validated.transaction.currencyCode
            let existingSubcategories = subcategoriesByCategory[validated.transaction.category] ?? []
            let subcategory = subcategoryMatcher.resolve(
                validated.transaction.subcategory,
                existing: existingSubcategories)
            return ParseResult(
                kind: validated.transaction.isIncome ? .income : .expense,
                amount: Money(amount: validated.validatedAmount, currency: Currency(rawValue: code)),
                concept: validated.transaction.concept,
                category: validated.transaction.category.rawValue,
                subcategory: subcategory,
                date: date,
                paymentMethodHint: Self.paymentMethodHint(from: validated.transaction.paymentMethodHint),
                cardAliasHint: validated.transaction.cardHint.isEmpty ? nil : validated.transaction.cardHint,
                isShared: validated.transaction.isShared,
                payerHint: validated.transaction.payerHint.isEmpty ? nil : validated.transaction.payerHint,
                splitHint: validated.transaction.splitHint.isEmpty ? nil : validated.transaction.splitHint,
                needsReview: validated.needsReview)
        }
    }

    /// El modelo devuelve texto libre en español ("efectivo", "crédito"...),
    /// no el enum — normaliza acentos/mayúsculas y solo reconoce los
    /// términos que el `@Guide` de `ParsedTransaction.paymentMethodHint`
    /// pide. Cualquier otra cosa se trata como "no mencionado".
    static func paymentMethodHint(from raw: String) -> PaymentMethodHint? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "efectivo", "cash":
            .cash
        case "débito", "debito", "debit":
            .debit
        case "crédito", "credito", "credit":
            .credit
        case "transferencia", "transfer":
            .transfer
        default:
            nil
        }
    }

    /// Carga el modelo en memoria por anticipado. Se llama cuando el
    /// usuario abre la pantalla de captura, no cuando confirma, para que la
    /// primera respuesta se sienta inmediata.
    public func prewarm() {
        guard availability == .available else { return }
        LanguageModelSession(instructions: ParserInstructions.build()).prewarm()
    }

    /// Rango amplio (2 años), deduplicado del lado del cliente — mismo
    /// criterio que `EntryModel`/`EditExpenseModel`, que cargan lo mismo
    /// para su propio dropdown de subcategoría.
    private static func loadSubcategoriesByCategory(from expenseStore: (any ExpenseStore)?) async
        -> [ExpenseCategory: [String]] {
        guard let expenseStore else { return [:] }
        guard let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) else { return [:] }
        guard let expenses = try? await expenseStore.expenses(in: DateInterval(start: start, end: Date())) else {
            return [:]
        }
        var bySubcategory: [ExpenseCategory: Set<String>] = [:]
        for expense in expenses {
            guard let categoryRaw = expense.category, let category = ExpenseCategory(rawValue: categoryRaw),
                  let subcategory = expense.subcategory, !subcategory.isEmpty else {
                continue
            }
            bySubcategory[category, default: []].insert(subcategory)
        }
        return bySubcategory.mapValues { $0.sorted() }
    }

    /// Los nombres de todas las listas compartidas del usuario, sin
    /// distinguir a cuál pertenece cada quien — el modelo solo necesita
    /// reconocer el nombre real, resolver a cuál lista y participante
    /// corresponde pasa después, fuera de `LanaParsing` (ADR-0025).
    private static func loadSharedParticipantNames(from sharedListStore: (any SharedListStore)?) async -> [String] {
        guard let sharedListStore else { return [] }
        guard let lists = try? await sharedListStore.lists() else { return [] }
        let names = lists.flatMap { $0.participants.map(\.displayName) }
        return Array(Set(names)).sorted()
    }
}
