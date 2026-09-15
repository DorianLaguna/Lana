import LanaCore
import LanaDesign
import SwiftUI

/// La pantalla de captura. Sin lógica propia — refleja `EntryModel.stage` y
/// llama a sus métodos (Docs/ARCHITECTURE.md). Tres pasos: abrir, escribir,
/// confirmar (Docs/PLAN.md → Fase 5).
public struct EntryView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: EntryModel
    private let onOpenSettings: () -> Void
    private let onDone: () -> Void
    /// Arranca a escuchar en cuanto la pantalla aparece, sin esperar a que
    /// el usuario toque el micrófono de adentro. La app lo pasa siempre en
    /// `true` — se llegue por el micrófono flotante o por el widget
    /// (ADR-0018), quien abrió esta hoja ya dijo que quiere dictar. Sigue
    /// siendo un parámetro para los `#Preview`, que no quieren pedir
    /// permiso de micrófono al renderizarse.
    private let autoStartListening: Bool

    public init(
        model: EntryModel,
        onOpenSettings: @escaping () -> Void,
        onDone: @escaping () -> Void,
        autoStartListening: Bool = false) {
        self.model = model
        self.onOpenSettings = onOpenSettings
        self.onDone = onDone
        self.autoStartListening = autoStartListening
    }

    public var body: some View {
        VStack(spacing: Space.md.rawValue) {
            content
        }
        .padding(Space.md.rawValue)
        // Llena toda la hoja, no solo lo que el contenido necesita — si no,
        // el resto de la hoja se queda con el blanco propio de iOS en vez
        // del de `LanaDesign`, y se nota la costura entre los dos.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lana.bg)
        .task { await model.onAppear(startListening: autoStartListening) }
        .onChange(of: model.stage) {
            if model.stage == .saved {
                onDone()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.stage {
        case .checkingAvailability:
            ProgressView()
        case let .unavailable(availability):
            AvailabilityOnboardingView(
                availability: availability,
                onOpenSettings: onOpenSettings,
                onRetry: { await model.retryAvailability() })
        case .composing, .parsing:
            composingView
        case .listening:
            ListeningView(
                transcript: model.inputText,
                preview: model.liveDrafts,
                onStop: { Task { await model.stopListening() } },
                onClear: { Task { await model.clearTranscript() } })
        case .reviewing, .saving:
            reviewingView
        case .saved:
            EmptyStateView(systemImage: "checkmark.circle", title: "Guardado")
        }
    }

    private var composingView: some View {
        VStack(spacing: Space.lg.rawValue) {
            if model.stage == .parsing {
                ParsingIndicatorView()
            } else {
                Button {
                    Task { await model.startListening() }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(
                            LinearGradient(
                                colors: [lana.accent, lana.highlight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            in: Circle())
                }
                .buttonStyle(.plain)
            }

            if let speechUnavailableMessage {
                VStack(spacing: Space.xs.rawValue) {
                    Text(speechUnavailableMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.ink50)
                        .multilineTextAlignment(.center)
                    if model.speechAvailability == .permissionDenied || model.speechAvailability == .restricted {
                        Button("Abrir Ajustes", action: onOpenSettings)
                    }
                }
            } else if model.stage == .composing {
                suggestionText
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.attention)
            }
        }
    }

    private static let suggestionExamples = [
        "gasté 300 en súper",
        "Uber 150",
        "cobré la quincena",
        "300 en gasolina con la Nu"
    ]

    /// Rota cada 5 segundos con un fundido, no un salto — el mismo espíritu
    /// del placeholder rotativo del mockup aprobado, y responde a "no veo
    /// dónde meter mis ingresos" mostrando un ejemplo de cobro, no solo de
    /// gasto.
    private var suggestionText: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let index = Int(context.date.timeIntervalSinceReferenceDate / 5) % Self.suggestionExamples.count
            Text("Prueba a decir: \"\(Self.suggestionExamples[index])\"")
                .lanaFont(.caption)
                .foregroundStyle(lana.ink50)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: index)
        }
    }

    private var speechUnavailableMessage: String? {
        switch model.speechAvailability {
        case .permissionDenied:
            "Activa el micrófono y el dictado en Ajustes para hablar en vez de escribir."
        case .restricted:
            "La captura por voz está restringida en este dispositivo."
        case .unavailable:
            "Este dispositivo no puede transcribir voz en el idioma actual sin conexión."
        case .permissionNotDetermined, .available:
            nil
        }
    }

    private var reviewingView: some View {
        VStack(spacing: Space.md.rawValue) {
            ScrollView {
                VStack(spacing: Space.sm.rawValue) {
                    ForEach($model.drafts) { $draft in
                        DraftCard(
                            draft: $draft,
                            cards: model.cards,
                            allSubcategories: model.allSubcategories,
                            sharedLists: model.sharedLists,
                            viewerName: { model.displayName(for: $0, in: $1) },
                            onDelete: model.drafts.count > 1 ? { model.removeDraft(id: draft.id) } : nil)
                    }
                }
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.attention)
            }

            Button {
                Task { await model.confirm() }
            } label: {
                if model.stage == .saving {
                    ProgressView()
                } else {
                    Text("Confirmar")
                }
            }
            .disabled(model.stage == .saving)
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        EntryView(
            model: EntryModel(
                parser: InMemoryExpenseParsing(),
                store: InMemoryExpenseStore(),
                cardStore: InMemoryCardStore(),
                speech: InMemorySpeechTranscribing(),
                vocabularyStore: InMemoryCorrectionVocabularyStore(),
                sharedListStore: InMemorySharedListStore()),
            onOpenSettings: {},
            onDone: {})
            .lanaTheme(theme)
    }
}
