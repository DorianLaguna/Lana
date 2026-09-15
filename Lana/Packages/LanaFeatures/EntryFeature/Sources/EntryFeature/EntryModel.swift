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

/// Cuánto alto pide la hoja de captura, en escalones. La vista mapea cada
/// caso a un `PresentationDetent` concreto — el modelo solo dice "compacta",
/// "media" o "completa", no puntos ni fracciones (eso es presentación).
public enum CaptureHeight: Equatable, Sendable {
    case compact
    case medium
    case full
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
    public internal(set) var stage: EntryStage = .checkingAvailability
    /// Si la captura por voz está lista para usarse ahora mismo. La vista la
    /// usa para decidir si el micrófono pide permiso al tocarlo o ya escucha
    /// directo (ADR-0015).
    public private(set) var speechAvailability: SpeechAvailability = .permissionNotDetermined
    /// El preview del parseo, editable inline antes de confirmar.
    public var drafts: [DraftTransaction] = []
    /// Lo que el parser ya entendió de lo dictado hasta la última pausa,
    /// mientras se sigue escuchando (ADR-0043). Solo se muestra — no se
    /// edita ni se guarda desde aquí; al terminar de dictar pasa a `drafts`.
    public internal(set) var liveDrafts: [DraftTransaction] = []
    /// Las tarjetas reales del usuario — para resolver "con la Nu" contra un
    /// `CardID` real, y para que `DraftCard` ofrezca un picker de método de
    /// pago con nombres reales, no solo "efectivo".
    public private(set) var cards: [Card] = []
    /// Las subcategorías que el usuario ya ha usado, por categoría — para
    /// ofrecerlas como dropdown en vez de texto libre en `DraftCard`.
    public private(set) var allSubcategories: [String: [String]] = [:]
    /// El último error, si algo falló al escuchar, parsear o guardar.
    public private(set) var errorMessage: String?

    /// Interno y no privado, igual que el estado de escucha de abajo: lo usa
    /// el parseo en vivo, que vive en `EntryModelLivePreview.swift`.
    let parser: any ExpenseParsing
    private let store: any ExpenseStore
    private let cardStore: any CardStore
    private let speech: any SpeechTranscribing
    private let vocabularyStore: any CorrectionVocabularyStore
    private let sharedListStore: any SharedListStore
    /// Las listas compartidas del usuario — para resolver
    /// `ParseResult.payerHint`/`splitHint` contra un roster real
    /// (`SharedExpenseMatch.bestMatch`, ADR-0025), y para que `DraftCard`
    /// muestre a qué lista/participante se asignó un borrador. Se recarga
    /// en cada `onAppear()`, igual que `cards`/`allSubcategories`.
    public private(set) var sharedLists: [SharedList] = []
    private var viewerIdentities: [SharedListID: ParticipantID] = [:]

    /// Muestra "Yo" en lugar del nombre propio dentro de una lista, igual
    /// que en la pantalla de la lista compartida (ADR-0028) — literalmente
    /// la misma regla, en `SharedList.displayName(for:viewer:)`.
    public func displayName(for participantID: ParticipantID, in sharedListID: SharedListID) -> String {
        sharedLists
            .first { $0.id == sharedListID }?
            .displayName(for: participantID, viewer: viewerIdentities[sharedListID]) ?? "Alguien"
    }

    /// Invalida una sesión de `startListening()` vieja cuando
    /// `clearTranscript()` arranca una nueva — ver ambos métodos.
    var listeningGeneration = 0
    /// El texto finalizado más reciente que se pidió parsear en vivo.
    var latestLiveRequest: String?
    /// El texto del que salieron los `liveDrafts` actuales.
    var liveParsedText = ""
    /// Un solo parseo en vivo a la vez: el modelo on-device atiende una
    /// sesión por turno, y encimar parseos de frases a medias solo retrasa
    /// el de la frase completa. Mientras corre uno, los pedidos nuevos solo
    /// actualizan `latestLiveRequest` y el loop toma el último al terminar.
    var liveParseTask: Task<Void, Never>?

    /// - Parameters:
    ///   - parser: cómo se convierte el texto en transacciones candidatas.
    ///   - store: dónde se guardan al confirmar.
    ///   - cardStore: de dónde se leen las tarjetas reales, para resolver
    ///     "con la Nu" y para el picker de método de pago.
    ///   - speech: cómo se convierte voz en texto (ADR-0015) — el texto
    ///     resultante entra al mismo `parser`, nunca hay un camino aparte.
    ///   - vocabularyStore: dónde se registra una corrección de categoría
    ///     al confirmar (ADR-0012).
    ///   - sharedListStore: de dónde se leen las listas compartidas reales y
    ///     la identidad marcada en cada una, para resolver "lo pagué con
    ///     Ana, mitad y mitad" contra una lista real sin pasar por el tab
    ///     de Compartido (ADR-0025).
    public init(
        parser: any ExpenseParsing,
        store: any ExpenseStore,
        cardStore: any CardStore,
        speech: any SpeechTranscribing,
        vocabularyStore: any CorrectionVocabularyStore,
        sharedListStore: any SharedListStore) {
        self.parser = parser
        self.store = store
        self.cardStore = cardStore
        self.speech = speech
        self.vocabularyStore = vocabularyStore
        self.sharedListStore = sharedListStore
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
        sharedLists = await (try? sharedListStore.lists()) ?? []
        viewerIdentities = await Self.loadViewerIdentities(for: sharedLists, from: sharedListStore)
        if shouldStartListening {
            await startListening()
        }
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
        resetLivePreview()
        stage = .listening
        do {
            for try await snapshot in speech.transcribe() {
                // `clearTranscript()` pudo haber invalidado esta sesión y
                // arrancado una nueva mientras esta seguía cerrando — sin
                // este chequeo, la sesión vieja podía pisar el transcript
                // de la nueva o, peor, disparar `submit()` con lo que el
                // usuario ya había borrado.
                guard generation == listeningGeneration else { return }
                inputText = snapshot.text
                requestLiveParse(of: snapshot.finalizedText, generation: generation)
            }
        } catch {
            guard generation == listeningGeneration else { return }
            errorMessage = error.localizedDescription
            resetLivePreview()
            stage = .composing
            return
        }

        guard generation == listeningGeneration else { return }
        await finishListening(generation: generation)
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
            drafts = makeDrafts(from: results)
            stage = .reviewing
        } catch {
            errorMessage = error.localizedDescription
            stage = .composing
        }
    }

    /// El mismo mapeo para el parseo al enviar y para el parseo en vivo — si
    /// divergieran, lo que se ve mientras se dicta no sería lo que se revisa.
    func makeDrafts(from results: [ParseResult]) -> [DraftTransaction] {
        results.map { result in
            var draft = DraftTransaction(result: result, fallbackDate: Date())
            draft.paymentMethod = Self.resolvePaymentMethod(
                hint: result.paymentMethodHint,
                cardAlias: result.cardAliasHint,
                cards: cards)
            applySharedMatch(from: result, to: &draft)
            return draft
        }
    }

    /// Solo si el texto dijo explícitamente que el gasto se comparte
    /// (`result.isShared`, ya filtrado por el vocabulario determinista de
    /// `ParsingPipeline`, ADR-0027) se intenta resolver contra una lista
    /// real. Decir quién pagó no basta y nunca bastó — confiar en eso mandó
    /// todos los gastos personales a la lista compartida (el bug que ADR-0027
    /// corrige).
    ///
    /// Con un match único, el borrador queda con `sharedListID`/`payer`/
    /// `split` y `needsReview` forzado a `true`, mismo criterio que Apple
    /// Pay/OCR (Docs/CLAUDE.md: "todo lo capturado automáticamente entra con
    /// needsReview"). Si se dijo que era compartido pero no hubo match único
    /// (nombre ambiguo entre dos listas, o ninguna lista), el gasto se queda
    /// personal con `needsReview` — nunca se adivina, y nunca se interrumpe
    /// el dictado con una pregunta (ADR-0025).
    private func applySharedMatch(from result: ParseResult, to draft: inout DraftTransaction) {
        guard result.isShared else { return }
        guard let payerHint = result.payerHint, !payerHint.isEmpty,
              let match = SharedExpenseMatch.bestMatch(
                  payerHint: payerHint,
                  splitHint: result.splitHint,
                  in: sharedLists,
                  viewerIdentities: viewerIdentities)
        else {
            draft.needsReview = true
            return
        }
        draft.sharedListID = match.sharedListID
        draft.payer = match.payer
        draft.split = match.split
        draft.needsReview = true
    }

    /// El usuario no quiere guardar este borrador — un dictado ambiguo puede
    /// parsear de más (pedido explícito: "quería borrar 2 para solo guardar
    /// uno"). Si era el último, no hay nada que revisar, así que regresa a
    /// "escuchar/escribir" en vez de dejar la pantalla de revisión vacía.
    public func removeDraft(id: ExpenseID) {
        drafts.removeAll { $0.id == id }
        if drafts.isEmpty {
            stage = .composing
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

    /// Cuánto alto pide la hoja de captura ahora mismo. Vive aquí y no en
    /// la vista por la misma razón que `stage`: es una consecuencia de en
    /// qué punto va la captura, no una decisión de presentación.
    ///
    /// Antes esto era binario (compacta o pantalla completa) y el salto se
    /// sentía brusco: a la palabra 50 la hoja pegaba un brinco a ocupar toda
    /// la pantalla. Ahora crece por escalones, acompañando lo que se va
    /// diciendo:
    ///
    /// - **Revisando**: los campos de `DraftCard` no caben; toda la pantalla.
    /// - **Escuchando**: sube de compacta a media cuando el transcript pasa
    ///   de dos renglones (~50 caracteres a `.title` centrado), y de media a
    ///   completa solo cuando de verdad ya es una frase larga. El umbral es
    ///   por número de caracteres, no por renglones medidos.
    public var captureHeight: CaptureHeight {
        switch stage {
        case .reviewing, .saving:
            .full
        case .listening:
            switch inputText.count {
            case ...Self.transcriptLengthForMediumSheet:
                // El preview en vivo no cabe en la hoja compacta.
                liveDrafts.isEmpty ? .compact : .medium
            case ...Self.transcriptLengthForFullSheet:
                .medium
            default:
                .full
            }
        case .checkingAvailability, .unavailable, .composing, .parsing, .saved:
            .compact
        }
    }

    private static let transcriptLengthForMediumSheet = 50
    private static let transcriptLengthForFullSheet = 140

    /// La hoja de captura se cerró sin confirmar — arrastrándola hacia
    /// abajo, o después de guardar. Corta el dictado en curso y deja el
    /// modelo listo para la próxima vez.
    ///
    /// El `listeningGeneration` se incrementa por lo mismo que en
    /// `clearTranscript()`: al cerrar el stream, `startListening()` sigue
    /// corriendo desde su `await` y llamaría a `submit()` con lo que se
    /// alcanzó a dictar — parsear y dejar borradores de una hoja que el
    /// usuario ya cerró. Con la generación invalidada, esa sesión regresa
    /// sin tocar nada.
    public func cancel() async {
        listeningGeneration += 1
        await speech.stopTranscribing()
        startOver()
    }

    /// Limpia todo y regresa a "escuchar/escribir" — para capturar otra
    /// transacción.
    public func startOver() {
        inputText = ""
        drafts = []
        resetLivePreview()
        errorMessage = nil
        stage = .composing
    }
}
