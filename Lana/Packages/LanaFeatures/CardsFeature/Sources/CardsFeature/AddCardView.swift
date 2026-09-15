import LanaCore
import LanaDesign
import SwiftUI

/// El formulario de agregar/editar tarjeta (Fase 6.5, calca
/// `AgregarTarjeta.dc.html`). Sin lógica propia — refleja `AddCardModel`.
public struct AddCardView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: AddCardModel
    private let onDone: () -> Void

    public init(model: AddCardModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $model.kind) {
                        Text("Crédito").tag(CardKind.credit)
                        Text("Débito").tag(CardKind.debit)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .padding(Space.sm.rawValue)
                }

                Section {
                    LanaTextField("Alias", text: $model.alias)
                    LanaTextField("Últimos 4 dígitos (opcional)", text: $model.lastFourDigits)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                }

                Section {
                    LanaTextField("Nombre en Wallet (opcional)", text: $model.walletMatchHint)
                    #if os(iOS)
                        .textInputAutocapitalization(.words)
                    #endif
                } footer: {
                    Text("""
                    Solo para reconocer esta tarjeta en automatizaciones de Apple Pay, si Wallet le \
                    dice distinto que el alias. Déjalo vacío si son iguales.
                    """)
                }

                Section {
                    colorPicker
                }

                // El débito no tiene línea de crédito, corte ni fecha límite
                // de pago en la realidad — solo se pregunta para crédito.
                if model.kind == .credit {
                    Section {
                        HStack {
                            Text("Límite")
                                .foregroundStyle(lana.ink)
                            Spacer()
                            TextField("0", value: $model.limitAmount, format: .number)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                            #if os(iOS)
                                .keyboardType(.decimalPad)
                            #endif
                        }
                        HStack {
                            Text("Día de corte")
                                .foregroundStyle(lana.ink)
                            Spacer()
                            TextField("1-31", value: $model.cutoffDay, format: .number)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                            #if os(iOS)
                                .keyboardType(.numberPad)
                            #endif
                        }
                        HStack {
                            Text("Día límite de pago")
                                .foregroundStyle(lana.ink)
                            Spacer()
                            TextField("1-31", value: $model.dueDay, format: .number)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                            #if os(iOS)
                                .keyboardType(.numberPad)
                            #endif
                        }
                    }
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.attention)
                }
            }
            .navigationTitle("Tarjeta")
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

    private var colorPicker: some View {
        HStack(spacing: Space.sm.rawValue) {
            ForEach(LanaCardColors.palette, id: \.self) { hex in
                Button {
                    model.colorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? lana.accent)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if model.colorHex == hex {
                                Circle().strokeBorder(lana.ink, lineWidth: 2)
                                    .padding(2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Space.xs.rawValue)
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        AddCardView(model: AddCardModel(cardStore: InMemoryCardStore()), onDone: {})
            .lanaTheme(theme)
    }
}
