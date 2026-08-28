import LanaCore
import LanaDesign
import SwiftUI

/// Registrar un pago a esta tarjeta — solo monto y fecha (Fase 7.5, pedido
/// explícito del usuario: sin método de pago, un pago ya es su propio tipo
/// de movimiento). Sin modelo propio: `CardDetailModel.recordPayment(amount:date:)`
/// ya tiene toda la lógica — esto solo sostiene el borrador hasta que se
/// confirma.
public struct AddCardPaymentView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: CardDetailModel
    @State private var amount: Decimal = 0
    @State private var date = Date()
    @State private var isSaving = false
    private let onDone: () -> Void

    public init(model: CardDetailModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Monto")
                            .foregroundStyle(lana.textPrimary)
                        Spacer()
                        TextField("0", value: $amount, format: .number)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                    }
                    // Precarga lo que toca del último estado de cuenta —
                    // no `totalDebt`, que incluye el ciclo todavía abierto:
                    // eso ni el banco lo deja pagar todavía.
                    Button("Pagar todo (\(model.statementDue.formatted()))") {
                        amount = model.statementDue.amount
                    }
                    .disabled(model.statementDue.amount <= 0)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.critical)
                }
            }
            .navigationTitle("Pagar")
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
                                isSaving = true
                                if await model.recordPayment(amount: amount, date: date) {
                                    onDone()
                                }
                                isSaving = false
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Guardar")
                            }
                        }
                        .disabled(isSaving || amount <= 0)
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    if let card = try? Card(
        alias: "BBVA Oro",
        lastFourDigits: "4821",
        limit: Money(amount: 10000, currency: .mxn),
        cutoffDay: 15,
        dueDay: 5) {
        AddCardPaymentView(
            model: CardDetailModel(
                card: card,
                store: InMemoryExpenseStore(),
                cardPaymentStore: InMemoryCardPaymentStore()),
            onDone: {})
    }
}
