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
            Form {
                Section {
                    LanaTextField("Nombre de la lista", text: $model.name)
                }

                Section {
                    ForEach(Array(model.participantNames.enumerated()), id: \.offset) { index, _ in
                        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                            HStack {
                                LanaTextField("Participante", text: $model.participantNames[index])
                                if model.participantNames.count > 2 {
                                    Button {
                                        model.removeParticipant(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(lana.critical)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            HStack {
                                Text("Ingreso mensual")
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.textSecondary)
                                Spacer()
                                TextField("Opcional", text: $model.participantIncomes[index])
                                    .lanaFont(.body)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                    .keyboardType(.decimalPad)
                                #endif
                            }
                        }
                        .padding(.vertical, Space.xs.rawValue)
                    }
                    Button {
                        model.addParticipant()
                    } label: {
                        Label("Agregar participante", systemImage: "plus")
                    }
                } footer: {
                    Text("""
                    Escribe los nombres tal cual quieres verlos — invitar de verdad a alguien más es \
                    aparte, desde el botón de compartir dentro de la lista. Con el ingreso de todos, los \
                    gastos se dividen proporcional por default: quien gana más pone más.
                    """)
                }

                Section {
                    Picker("¿Cuál de estos eres tú?", selection: $model.viewerIndex) {
                        ForEach(Array(model.participantNames.enumerated()), id: \.offset) { index, name in
                            Text(name.isEmpty ? "Participante \(index + 1)" : name).tag(index)
                        }
                    }
                } footer: {
                    Text("""
                    Así Lana sabe qué parte de un gasto compartido es tuya de verdad, en vez de mostrar \
                    el monto completo en tu Dashboard personal.
                    """)
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.critical)
                }
            }
            .navigationTitle("Nueva lista")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
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

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        CreateSharedListView(model: CreateSharedListModel(sharedListStore: InMemorySharedListStore()), onDone: {})
            .lanaTheme(theme)
    }
}
