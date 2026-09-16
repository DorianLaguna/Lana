import LanaCore
import LanaDesign
import SwiftUI

/// Editar una lista ya creada: nombre, roster, ingresos y quién soy yo
/// (ADR-0028). Sin lógica propia, refleja `EditSharedListModel`.
public struct EditSharedListView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: EditSharedListModel
    private let onDone: () -> Void

    public init(model: EditSharedListModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LanaTextField("Nombre de la lista", text: $model.name)
                        .padding(.bottom, Space.p22.rawValue)

                    SectionHeader("Participantes e ingresos")
                        .padding(.bottom, Space.p10.rawValue)
                    participantsCard
                        .padding(.bottom, Space.sm.rawValue)
                    Text(incomeFooter)
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, Space.p22.rawValue)

                    SectionHeader("¿Cuál de estos eres tú?")
                        .padding(.bottom, Space.p10.rawValue)
                    viewerChips
                        .padding(.bottom, Space.sm.rawValue)
                    Text("Se muestra como «Yo» en esta lista, y decide qué parte de cada gasto va a tu Dashboard.")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.attention)
                            .padding(.top, Space.p12.rawValue)
                    }
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.p18.rawValue)
                .padding(.bottom, Space.p40.rawValue)
            }
            .background(lana.bg)
            .navigationTitle("Editar lista")
            .lanaInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await model.save() {
                                onDone()
                            }
                        }
                    } label: {
                        if model.isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar")
                        }
                    }
                    .disabled(model.isSaving)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

extension EditSharedListView {
    private var participantsCard: some View {
        LanaCard {
            VStack(spacing: 0) {
                ForEach(model.participants) { participant in
                    participantRow(participant)
                    HairlineDivider()
                }
                Button {
                    model.addParticipant()
                } label: {
                    Label("Agregar participante", systemImage: "plus")
                        .lanaFont(.bodyEmphasis)
                        .foregroundStyle(lana.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: LanaMetrics.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func participantRow(_ participant: EditableParticipant) -> some View {
        @Bindable var participant = participant
        return VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            LanaTextField("Nombre", text: $participant.name)
            HStack(spacing: Space.sm.rawValue) {
                Text("Ingreso mensual")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                Spacer(minLength: Space.sm.rawValue)
                TextField("Sin capturar", text: $participant.incomeText)
                    .lanaFont(.rowTitle)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(lana.ink)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
            }
            .frame(minHeight: LanaMetrics.minTouchTarget)
        }
        .padding(.vertical, Space.p10.rawValue)
    }

    private var viewerChips: some View {
        FlowLayout {
            ForEach(model.participants) { participant in
                let label = participant.name.isEmpty ? "Sin nombre" : participant.name
                Chip(label, tone: model.viewerID == participant.id ? .neutral : .suggestion) {
                    model.viewerID = participant.id
                }
                .accessibilityAddTraits(model.viewerID == participant.id ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// Explica el efecto real de capturar los ingresos, en vez de dejar al
    /// usuario adivinar por qué la división proporcional aparece o no.
    private var incomeFooter: String {
        if model.canSplitProportionally {
            return """
            Con los ingresos de todos capturados, los gastos nuevos se dividen proporcional por default: \
            quien gana más pone más. Cambiarlos aplica de aquí en adelante — lo ya registrado no se recalcula.
            """
        }
        return """
        Captura el ingreso de todos para que los gastos se dividan proporcional por default (quien gana más \
        pone más). Sin eso, se dividen en partes iguales. No se puede quitar a alguien que ya tiene gastos \
        registrados.
        """
    }
}

#Preview {
    let alice = Participant(displayName: "Ana", monthlyIncome: 20000)
    let bob = Participant(displayName: "Sam", monthlyIncome: 15000)
    let list = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .payerOnly)
    ForEach(LanaTheme.allCases) { theme in
        EditSharedListView(
            model: EditSharedListModel(list: list, viewerID: alice.id, onSave: { _, _ in true }),
            onDone: {})
            .lanaTheme(theme)
    }
}
