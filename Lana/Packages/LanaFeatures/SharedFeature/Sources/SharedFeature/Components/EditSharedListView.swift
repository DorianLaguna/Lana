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
            Form {
                Section {
                    LanaTextField("Nombre de la lista", text: $model.name)
                }

                Section {
                    ForEach(model.participants) { participant in
                        participantRow(participant)
                    }
                    Button {
                        model.addParticipant()
                    } label: {
                        Label("Agregar participante", systemImage: "plus")
                    }
                } header: {
                    Text("Participantes e ingresos")
                } footer: {
                    Text(incomeFooter)
                }

                Section {
                    Picker("¿Cuál de estos eres tú?", selection: $model.viewerID) {
                        ForEach(model.participants) { participant in
                            Text(participant.name.isEmpty ? "Sin nombre" : participant.name)
                                .tag(Optional(participant.id))
                        }
                    }
                } footer: {
                    Text("Se muestra como «Yo» en esta lista, y decide qué parte de cada gasto va a tu Dashboard.")
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.attention)
                }
            }
            .navigationTitle("Editar lista")
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
                                Text("Guardar")
                            }
                        }
                        .disabled(model.isSaving)
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }

    private func participantRow(_ participant: EditableParticipant) -> some View {
        @Bindable var participant = participant
        return VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            LanaTextField("Nombre", text: $participant.name)
            HStack {
                Text("Ingreso mensual")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.ink50)
                Spacer()
                TextField("Sin capturar", text: $participant.incomeText)
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
