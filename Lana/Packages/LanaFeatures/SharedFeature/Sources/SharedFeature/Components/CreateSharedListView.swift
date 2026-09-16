import LanaCore
import LanaDesign
import SwiftUI

/// El formulario de crear una lista compartida — nombre + participantes por
/// nombre. Sin lógica propia, refleja `CreateSharedListModel`.
public struct CreateSharedListView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: CreateSharedListModel
    private let onDone: () -> Void

    public init(model: CreateSharedListModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LanaTextField("Nombre de la lista", text: $model.name)
                        .padding(.bottom, Space.p22.rawValue)

                    SectionHeader("Quiénes son")
                        .padding(.bottom, Space.p10.rawValue)
                    participantsCard
                        .padding(.bottom, Space.sm.rawValue)
                    Text("""
                    Escribe los nombres tal cual quieres verlos — invitar de verdad a alguien más es aparte, \
                    desde el botón de compartir dentro de la lista. Con el ingreso de todos, los gastos se \
                    dividen proporcional por default: quien gana más pone más.
                    """)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink42)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.p22.rawValue)

                    SectionHeader("¿Cuál de estos eres tú?")
                        .padding(.bottom, Space.p10.rawValue)
                    viewerChips
                        .padding(.bottom, Space.sm.rawValue)
                    Text("""
                    Así Lana sabe qué parte de un gasto compartido es tuya de verdad, en vez de mostrar el \
                    monto completo en tu Dashboard personal.
                    """)
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
            .navigationTitle("Nueva lista")
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
                            Text("Crear")
                        }
                    }
                    .disabled(model.isSaving)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

extension CreateSharedListView {
    private var participantsCard: some View {
        LanaCard {
            VStack(spacing: 0) {
                ForEach(Array(model.participantNames.enumerated()), id: \.offset) { index, _ in
                    participantRow(at: index)
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

    private func participantRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            HStack(spacing: Space.sm.rawValue) {
                LanaTextField("Participante", text: $model.participantNames[index])
                // Una lista compartida necesita al menos dos: con dos, quitar
                // a alguien no es una opción que se pueda ofrecer.
                if model.participantNames.count > 2 {
                    Button {
                        model.removeParticipant(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(lana.ink50)
                            .frame(width: LanaMetrics.minTouchTarget, height: LanaMetrics.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quitar participante \(index + 1)")
                }
            }
            incomeRow(at: index)
        }
        .padding(.vertical, Space.p10.rawValue)
    }

    private func incomeRow(at index: Int) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            Text("Ingreso mensual")
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink50)
            Spacer(minLength: Space.sm.rawValue)
            TextField("Opcional", text: $model.participantIncomes[index])
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

    private var viewerChips: some View {
        FlowLayout {
            ForEach(Array(model.participantNames.enumerated()), id: \.offset) { index, name in
                let label = name.isEmpty ? "Participante \(index + 1)" : name
                Chip(label, tone: model.viewerIndex == index ? .neutral : .suggestion) {
                    model.viewerIndex = index
                }
                .accessibilityAddTraits(model.viewerIndex == index ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        CreateSharedListView(model: CreateSharedListModel(sharedListStore: InMemorySharedListStore()), onDone: {})
            .lanaTheme(theme)
    }
}
