import LanaCore
import LanaDesign
import SwiftUI

/// La hoja de captura (rediseño, secciones 07 y 08). Sin lógica propia —
/// refleja `EntryModel.stage` y llama a sus métodos.
public struct EntryView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: EntryModel
    private let onOpenSettings: () -> Void
    private let onDone: () -> Void
    private let onManualEntry: () -> Void
    /// Arranca a escuchar en cuanto la hoja aparece: se llegue por el
    /// micrófono de la barra o por el widget (ADR-0018), quien la abrió ya
    /// dijo que quiere dictar. Parámetro solo para los `#Preview`, que no
    /// quieren pedir permiso de micrófono.
    private let autoStartListening: Bool

    /// - Parameters:
    ///   - onOpenSettings: abre los Ajustes del sistema (permiso de micrófono,
    ///     Apple Intelligence).
    ///   - onDone: se guardó; la app cierra la hoja y refresca.
    ///   - onManualEntry: "Agregar a mano" — el mismo formulario en blanco, sin
    ///     IA. La salida cuando no se puede hablar o dictar no está disponible.
    public init(
        model: EntryModel,
        onOpenSettings: @escaping () -> Void,
        onDone: @escaping () -> Void,
        onManualEntry: @escaping () -> Void = {},
        autoStartListening: Bool = false) {
        self.model = model
        self.onOpenSettings = onOpenSettings
        self.onDone = onDone
        self.onManualEntry = onManualEntry
        self.autoStartListening = autoStartListening
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsManualEntryShortcut {
                HStack {
                    Spacer()
                    Button("Agregar a mano", action: onManualEntry)
                        .lanaFont(.callout)
                        .foregroundStyle(lana.accent)
                        .buttonStyle(.plain)
                        .frame(minHeight: LanaMetrics.minTouchTarget)
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.sm.rawValue)
            }
            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
        // Llena toda la hoja: si no, el resto se queda con el fondo propio de
        // iOS y se nota la costura.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lana.surface)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: model.stage)
        .sensoryFeedback(.success, trigger: model.stage) { _, stage in stage == .saved }
        .task { await model.onAppear(startListening: autoStartListening) }
        .onChange(of: model.stage) {
            if model.stage == .saved {
                onDone()
            }
        }
    }

    /// Mientras se revisa, la salida manual ya no hace falta: hay borradores.
    private var showsManualEntryShortcut: Bool {
        switch model.stage {
        case .composing, .listening, .parsing: true
        case .checkingAvailability, .unavailable, .reviewing, .saving, .saved: false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.stage {
        case .checkingAvailability:
            ProgressView()
                .padding(.top, Space.p40.rawValue)
        case let .unavailable(availability):
            AvailabilityOnboardingView(
                availability: availability,
                onOpenSettings: onOpenSettings,
                onRetry: { await model.retryAvailability() },
                onManualEntry: onManualEntry)
        case .composing:
            composingView
        case .parsing:
            ParsingIndicatorView()
        case .listening:
            ListeningView(
                transcript: model.inputText,
                finalizedTranscript: model.finalizedTranscript,
                level: model.audioLevel,
                preview: model.liveDrafts,
                onStop: { Task { await model.stopListening() } },
                onClear: { Task { await model.clearTranscript() } })
        case .reviewing, .saving:
            reviewingView
        case .saved:
            EmptyStateView(systemImage: "checkmark.circle", title: "Guardado")
        }
    }

    // MARK: - Sin escuchar

    /// Aquí se llega si el dictado no arrancó (sin permiso, sin soporte) o si
    /// terminó sin entender nada.
    @ViewBuilder
    private var composingView: some View {
        switch model.speechAvailability {
        case .permissionDenied, .restricted:
            EmptyStateView(
                systemImage: "mic.slash",
                title: "Lana no puede oírte",
                message: "Dale acceso al micrófono para dictar tus movimientos.",
                actionTitle: "Abrir Ajustes",
                action: onOpenSettings,
                secondaryActionTitle: "Agregar a mano",
                secondaryAction: onManualEntry)
        case .unavailable:
            EmptyStateView(
                systemImage: "mic.slash",
                title: "Este iPhone no puede dictar en español",
                message: "Puedes registrar tus movimientos a mano; todo lo demás funciona igual.",
                actionTitle: "Agregar a mano",
                action: onManualEntry)
        case .available, .permissionNotDetermined:
            idleView
        }
    }

    private var idleView: some View {
        VStack(spacing: Space.p18.rawValue) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .lanaFont(.explanation)
                    .foregroundStyle(lana.ink70)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: LanaMetrics.emptyStateMaxWidth)
            }

            Button {
                Task { await model.startListening() }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: LanaMetrics.stopGlyph, weight: .semibold))
                    .foregroundStyle(lana.onAccent)
                    .frame(width: LanaMetrics.stopButton, height: LanaMetrics.stopButton)
                    .background(lana.accentFill, in: Circle())
                    .shadow(color: lana.accentShadow, radius: Space.p9.rawValue, y: Space.p6.rawValue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dictar un movimiento")

            Text("Toca para dictar · todo en tu teléfono")
                .lanaFont(.detail)
                .foregroundStyle(lana.ink42)
        }
        .padding(.top, Space.p40.rawValue)
        .padding(.horizontal, Space.p28.rawValue)
    }

    // MARK: - Revisar

    private var reviewingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            reviewHeader
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.bottom, Space.md.rawValue)

            if !model.inputText.isEmpty {
                transcriptQuote
                    .padding(.horizontal, LanaMetrics.screenMargin)
                    .padding(.bottom, Space.p20.rawValue)
            }

            ScrollView {
                VStack(spacing: Space.p12.rawValue) {
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
                .padding(.horizontal, LanaMetrics.screenMargin)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.attention)
                    .padding(.horizontal, LanaMetrics.screenMargin)
                    .padding(.top, Space.p10.rawValue)
            }

            reviewFooter
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.md.rawValue)
                .padding(.bottom, Space.p40.rawValue)
        }
    }

    /// "ENTENDÍ 2 MOVIMIENTOS · en el teléfono": lo que se entendió y dónde se
    /// procesó, que es la razón para confiar en la app.
    private var reviewHeader: some View {
        HStack(spacing: Space.sm.rawValue) {
            Circle()
                .fill(lana.positive)
                .frame(width: LanaMetrics.dot, height: LanaMetrics.dot)
            Text(understoodLabel)
                .lanaFont(.sectionHeader)
                .foregroundStyle(lana.positive)
            Spacer(minLength: Space.sm.rawValue)
            Text("en el teléfono")
                .lanaFont(.footnote)
                .foregroundStyle(lana.ink42)
        }
        .accessibilityElement(children: .combine)
    }

    private var understoodLabel: String {
        let count = model.drafts.count
        return count == 1 ? "Entendí un movimiento" : "Entendí \(count) movimientos"
    }

    /// Lo dictado, entre comillas. Tocarlo vuelve a escuchar conservando lo ya
    /// revisado.
    private var transcriptQuote: some View {
        Button {
            Task { await model.resumeListening() }
        } label: {
            Text("«\(model.inputText)»")
                .lanaFont(.quote)
                .foregroundStyle(lana.ink70)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Vuelve a dictar")
    }

    private var reviewFooter: some View {
        HStack(spacing: Space.p10.rawValue) {
            Button("Seguir dictando") {
                Task { await model.resumeListening() }
            }
            .buttonStyle(.lana(.secondary, size: .large))
            .disabled(model.stage == .saving)

            Button {
                Task { await model.confirm() }
            } label: {
                if model.stage == .saving {
                    ProgressView()
                        .tint(lana.onAccent)
                } else {
                    Text(saveLabel)
                }
            }
            .buttonStyle(.lana(size: .large, isExpanded: true))
            .disabled(model.stage == .saving)
        }
    }

    /// El número es real y cambia al quitar borradores. Guardar nunca se
    /// bloquea, ni siquiera con dudas (Docs/CLAUDE.md).
    private var saveLabel: String {
        model.drafts.count > 1 ? "Guardar los \(model.drafts.count)" : "Guardar"
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
