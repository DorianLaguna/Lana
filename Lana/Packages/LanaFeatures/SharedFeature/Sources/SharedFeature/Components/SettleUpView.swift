import LanaCore
import LanaDesign
import SwiftUI

/// Liquidar una deuda — monto y fecha precargados del `Debt` que la
/// disparó, editables por si se pagó solo una parte. Registra un
/// `SettlementRecorded`, no un gasto — no se mezcla con `ExpenseStore`.
public struct SettleUpView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditingAmount: Bool
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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(fromName) le paga a \(toName)")
                        .lanaFont(.pushTitle)
                        .foregroundStyle(lana.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, Space.p18.rawValue)

                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                            amountRow
                            HairlineDivider()
                            DatePicker("Fecha", selection: $date, displayedComponents: .date)
                                .lanaFont(.rowTitle)
                                .foregroundStyle(lana.ink)
                                .tint(lana.accentFill)
                        }
                    }

                    // Liquidar no es un gasto: mueve el saldo entre personas y
                    // no toca lo gastado del mes (ADR-0005).
                    Text("Un pago entre ustedes no cuenta como gasto del mes.")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.p12.rawValue)

                    if let errorMessage {
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
            .navigationTitle("Liquidar")
            .lanaInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        // El `decimalPad` no tiene tecla de retorno: sin soltar
                        // el foco, el último dígito tecleado puede no haber
                        // llegado al binding todavía.
                        isEditingAmount = false
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { isEditingAmount = false }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var amountRow: some View {
        HStack(spacing: Space.sm.rawValue) {
            Text("Monto")
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink50)
            Spacer(minLength: Space.sm.rawValue)
            TextField("0", value: $amount, format: .number)
                .lanaFont(.draftAmount)
                .foregroundStyle(lana.ink)
                .multilineTextAlignment(.trailing)
                .focused($isEditingAmount)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
        }
        .frame(minHeight: LanaMetrics.minTouchTarget)
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
