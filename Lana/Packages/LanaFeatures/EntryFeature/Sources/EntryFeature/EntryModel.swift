import Foundation
import LanaCore
import Observation

/// En qué punto de "abrir → escuchar/escribir → confirmar" está la pantalla
/// (Docs/PLAN.md → Fase 5, Fase 6.5). `.unavailable` es aparte: no cuenta
/// como uno de los pasos, es la pantalla que los reemplaza cuando el modelo
/// no sirve.
public enum EntryStage: Equatable, Sendable {
    case checkingAvailability
    case unavailable(ParsingAvailability)
    case composing
    case listening
    case parsing
    case reviewing
    case saving
    case saved
}

/// Toda la lógica y el estado de la captura. La vista no decide nada — solo
/// llama a estos métodos y refleja `stage` (Docs/ARCHITECTURE.md → Estructura
/// interna de una feature).
@MainActor
@Observable
public final class EntryModel {
    /// Lo que el usuario está escribiendo, o el transcript en vivo mientras
    /// escucha — ambos caminos llegan al mismo `submit()`.
    public var inputText = ""
    /// En qué paso del flujo está la pantalla.
    public private(set) var stage: EntryStage = .checkingAvailability
    /// Si la captura por voz está lista para usarse ahora mismo. La vista la
    /// usa para decidir si el micrófono pide permiso al tocarlo o ya escucha
    /// directo (ADR-0015).
    public private(set) var speechAvailability: SpeechAvailability = .permissionNotDetermined
    /// El preview del parseo, editable inline antes de confirmar.
    public var drafts: [DraftTransaction] = []
    /// Las tarjetas reales del usuario — para resolver "con la Nu" contra un
    /// `CardID` real, y para que `DraftCard` ofrezca un picker de método de
    /// pago con nombres reales, no solo "efectivo".
    public private(set) var cards: [Card] = []
    /// Las subcategorías que el usuario ya ha usado, por categoría — para
    /// ofrecerlas como dropdown en vez de texto libre en `DraftCard`.
    public private(set) var allSubcategories: [String: [String]] = [:]
    /// El último error, si algo falló al escuchar, parsear o guardar.
    public private(set) var errorMessage: String?

    private let parser: any ExpenseParsing
    private let store: any ExpenseStore
    private let cardStore: any CardStore
    private let speech: any SpeechTranscribing
    private let vocabularyStore: any CorrectionVocabularyStore
    /// Invalida una sesión de `startListening()` vieja cuando
    /// `clearTranscript()` arranca una nueva — ver ambos métodos.
    private var listeningGeneration = 0

    /// - Parameters:
    ///   - parser: cómo se convierte el texto en transacciones candidatas.
    ///   - store: dónde se guardan al confirmar.
    ///   - cardStore: de dónde se leen las tarjetas reales, para resolver
    ///     "con la Nu" y para el picker de método de pago.
    ///   - speech: cómo se convierte voz en texto (ADR-0015) — el texto
    ///     resultante entra al mismo `parser`, nunca hay un camino aparte.
    ///   - vocabularyStore: dónde se registra una corrección de categoría
    ///     al confirmar (ADR-0012).
    public init(
        parser: any ExpenseParsing,
        store: any ExpenseStore,
        cardStore: any CardStore,
        speech: any SpeechTranscribing,
        vocabularyStore: any CorrectionVocabularyStore) {
        self.parser = parser
        self.store = store
        self.cardStore = cardStore
        self.speech = speech
        self.vocabularyStore = vocabularyStore
    }

    /// Se llama cuando la pantalla aparece: revisa disponibilidad del
    /// parser y, si sirve, lo precalienta
    /// (Docs/.claude/skills/foundation-models). También lee la
    /// disponibilidad de voz, sin pedir permiso todavía — eso se pide hasta
    /// que el usuario toque el micrófono (ADR-0015) — y carga las tarjetas
    /// reales para resolver alias y ofrecerlas en el picker.
    ///
    /// - Parameter startListening: `true` cuando se llega aquí desde el
    ///   widget de Home Screen (ADR-0018) — arranca a escuchar de
    ///   inmediato, sin esperar a que el usuario toque el micrófono. Solo
    ///   tiene efecto si el modelo sí está disponible; si no, la pantalla
    ///   de onboarding de siempre se muestra igual, sin intentar escuchar.
    public func onAppear(startListening shouldStartListening: Bool = false) async {
        let availability = await parser.availability
        guard availability == .available else {
            stage = .unavailable(availability)
            return
        }
        parser.prewarm()
        stage = .composing
        speechAvailability = await speech.availability
        cards = await (try? cardStore.cards()) ?? []
        allSubcategories = await Self.loadSubcategories(from: store)
        if shouldStartListening {
            await startListening()
        }
    }

    /// Rango amplio (2 años), no acotado al mes vigente — se ofrecen todas
    /// las subcategorías que el usuario ya ha usado alguna vez, filtradas y
    /// agrupadas por categoría del lado del cliente (sin protocolo nuevo).
    private static func loadSubcategories(from store: any ExpenseStore) async -> [String: [String]] {
        guard let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) else { return [:] }
        guard let expenses = try? await store.expenses(in: DateInterval(start: start, end: Date())) else {
            return [:]
        }
        var bySubcategory: [String: Set<String>] = [:]
        for expense in expenses {
            guard let category = expense.category, let subcategory = expense.subcategory, !subcategory.isEmpty else {
                continue
            }
            bySubcategory[category, default: []].insert(subcategory)
        }
        return bySubcategory.mapValues { $0.sorted() }
    }

    /// Para el caso recuperable (`.notEnabled`) y el temporal
    /// (`.modelNotReady`) — vuelve a checar tras la acción del usuario.
    public func retryAvailability() async {
        stage = .checkingAvailability
        await onAppear()
    }

    /// El usuario tocó el micrófono. Pide permiso la primera vez si hace
    /// falta, escucha hasta que `stopListening()` corte el stream, y de ahí
    /// sigue directo al mismo `submit()` que usa el texto tecleado — la voz
    /// es otra forma de producir texto, no un camino de parseo aparte
    /// (ADR-0015).
    public func startListening() async {
        if speechAvailability != .available {
            speechAvailability = await speech.requestPermission()
            guard speechAvailability == .available else { return }
        }

        listeningGeneration += 1
        let generation = listeningGeneration

        errorMessage = nil
        inputText = ""
        stage = .listening
        do {
            for try await snapshot in speech.transcribe() {
                // `clearTranscript()` pudo haber invalidado esta sesión y
                // arrancado una nueva mientras esta seguía cerrando — sin
                // este chequeo, la sesión vieja podía pisar el transcript
                // de la nueva o, peor, disparar `submit()` con lo que el
                // usuario ya había borrado.
                guard generation == listeningGeneration else { return }
                inputText = snapshot
            }
        } catch {
            guard generation == listeningGeneration else { return }
            errorMessage = error.localizedDescription
            stage = .composing
            return
        }

        guard generation == listeningGeneration else { return }
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            stage = .composing
            return
        }
        await submit()
    }

    /// El usuario tocó el micrófono otra vez para terminar de dictar — no
    /// hay detección de silencio (ADR-0015).
    public func stopListening() async {
        await speech.stopTranscribing()
    }

    /// Borra lo dictado hasta ahora sin dejar de escuchar — pedido explícito
    /// del usuario ("me gustaría borrar lo que dije en algún punto, para
    /// reiniciar"). No se puede resetear a medias una sesión de
    /// reconocimiento en curso de forma confiable, así que esto detiene y
    /// arranca una sesión nueva; `listeningGeneration` evita que la sesión
    /// vieja, al terminar de cerrarse, alcance a tocar el estado (ver
    /// `startListening()`). Se incrementa aquí, antes del `await`, para que
    /// la invalidación quede lista sin importar el orden en que el sistema
    /// reanude las dos tareas.
    public func clearTranscript() async {
        guard stage == .listening else { return }
        listeningGeneration += 1
        await speech.stopTranscribing()
        await startListening()
    }

    /// El paso "escribir": el usuario envía el texto y se parsea. Nunca dos
    /// pasos separados de "parsear" y luego "ver preview" — el preview
    /// aparece en cuanto termina esto.
    public func submit() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        stage = .parsing
        do {
            let results = try await parser.parse(trimmed)
            guard !results.isEmpty else {
                errorMessage = "No se entendió el texto. Intenta escribirlo de otra forma."
                stage = .composing
                return
            }
            drafts = results.map { result in
                var draft = DraftTransaction(result: result, fallbackDate: Date())
                draft.paymentMethod = Self.resolvePaymentMethod(
                    hint: result.paymentMethodHint,
                    cardAlias: result.cardAliasHint,
                    cards: cards)
                return draft
            }
            stage = .reviewing
        } catch {
            errorMessage = error.localizedDescription
            stage = .composing
        }
    }

    /// El tipo de tarjeta ya no se adivina de la frase — se fija al dar de
    /// alta o editar la tarjeta (`Card.kind`). Si el texto mencionó una
    /// tarjeta real por alias, esa tarjeta manda: decir "con la tarjeta
    /// Banamex" sin decir "crédito" ya no pierde la tarjeta, que era el bug
    /// real. `paymentMethodHint` solo importa cuando no se resolvió ninguna
    /// tarjeta — para no inventar una, cae a efectivo (el usuario lo
    /// corrige a mano si hacía falta; `DraftCard` deja editar esto).
    private static func resolvePaymentMethod(
        hint: PaymentMethodHint?,
        cardAlias: String?,
        cards: [Card]) -> PaymentMethod {
        if let card = resolveCard(aliasHint: cardAlias, in: cards) {
            return card.kind == .credit ? .credit(cardID: card.id) : .debit(cardID: card.id)
        }
        return hint == .transfer ? .transfer : .cash
    }

    private static func resolveCard(aliasHint: String?, in cards: [Card]) -> Card? {
        guard let aliasHint else { return nil }
        let normalizedHint = aliasHint.lowercased()
        if let exact = cards.first(where: { $0.alias.lowercased() == normalizedHint }) {
            return exact
        }
        return cards.first { card in
            let normalizedAlias = card.alias.lowercased()
            return normalizedHint.contains(normalizedAlias) || normalizedAlias.contains(normalizedHint)
        }
    }

    /// El paso "confirmar". Guarda todos los borradores tal como quedaron
    /// editados — lo ambiguo entra con `needsReview`, nunca bloquea esto.
    /// Si el usuario cambió la categoría que propuso el parser, esa
    /// corrección se registra antes de guardar (ADR-0012) — hasta ahora
    /// `CorrectionVocabularyStore` existía pero nada la disparaba.
    public func confirm() async {
        guard !drafts.isEmpty else { return }
        stage = .saving
        do {
            for draft in drafts {
                if !draft.category.isEmpty, draft.category != draft.originalCategory {
                    await vocabularyStore.record(term: draft.concept, category: draft.category)
                }
                try await store.save(draft.asExpense())
            }
            stage = .saved
        } catch {
            errorMessage = error.localizedDescription
            stage = .reviewing
        }
    }

    /// Limpia todo y regresa a "escuchar/escribir" — para capturar otra
    /// transacción.
    public func startOver() {
        inputText = ""
        drafts = []
        errorMessage = nil
        stage = .composing
    }
}
