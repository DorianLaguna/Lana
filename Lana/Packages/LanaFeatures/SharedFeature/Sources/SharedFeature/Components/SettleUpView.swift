import LanaCore
import LanaDesign
import SwiftUI

/// Liquidar una deuda — monto y fecha precargados del `Debt` que la
/// disparó, editables por si se pagó solo una parte. Registra un
/// `SettlementRecorded`, no un gasto — no se mezcla con `ExpenseStore`.
public struct SettleUpView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    private let model: SharedListDetailModel
    private let debt: Debt
    private let onDone: () -> Void

    @State private var amount: Decimal
    @State private var date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(model: SharedListDetailModel, debt: Debt, onDone: @escaping () -> Void) {
        self.model = model
        self.debt = debt
        self.onDone = onDone
        _amount = State(initialValue: debt.amount.amount)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(fromName) le paga a \(toName)")
                        .lanaFont(.body)
                        .foregroundStyle(lana.textPrimary)
                    HStack {
                        Text("Monto")
                        Spacer()
                        TextField("0", value: $amount, format: .number)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                    }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.critical)
                }
            }
            .navigationTitle("Liquidar")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Listo")
                            }
                        }
                        .disabled(isSaving || amount <= 0)
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }

    private var fromName: String {
        model.participant(debt.from)?.displayName ?? "Alguien"
    }

    private var toName: String {
        model.participant(debt.to)?.displayName ?? "Alguien"
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let saved = await model.recordSettlement(
            from: debt.from,
            to: debt.to,
            amount: amount,
            currency: debt.amount.currency,
            date: date)
        if saved {
            onDone()
        } else {
            errorMessage = "No se pudo guardar."
        }
    }
}

#Preview {
    let alice = Participant(displayName: "Tú")
    let bob = Participant(displayName: "Sam")
    let list = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .payerOnly)
    ForEach(LanaTheme.allCases) { theme in
        SettleUpView(
            model: SharedListDetailModel(
                list: list,
                sharedListStore: InMemorySharedListStore(seed: [list]),
                expenseStore: InMemoryExpenseStore(),
                parser: InMemoryExpenseParsing()),
            debt: Debt(from: bob.id, to: alice.id, amount: Money(amount: 250, currency: .mxn)),
            onDone: {})
            .lanaTheme(theme)
    }
}
