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
                    }
                    Button {
                        model.addParticipant()
                    } label: {
                        Label("Agregar participante", systemImage: "plus")
                    }
                } footer: {
                    Text("Por ahora, solo el nombre — invitar de verdad llega cuando tengas otro iPhone a la mano.")
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
