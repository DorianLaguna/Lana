import LanaCore
import LanaDesign
import SwiftUI

/// El drill-down de una lista compartida: saldos, gastos, capturar,
/// liquidar (Fase 8). Sin lógica propia, refleja `SharedListDetailModel`.
public struct SharedListDetailView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: SharedListDetailModel
    @State private var isCapturing = false
    @State private var settlingDebt: Debt?

    public init(model: SharedListDetailModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Space.md.rawValue) {
                BalancesView(
                    balances: model.balances,
                    debts: model.debts,
                    participantName: { model.participant($0)?.displayName ?? "Alguien" },
                    onSettle: { settlingDebt = $0 })

                if !model.expenses.isEmpty {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Gastos")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.textSecondary)
                            VStack(spacing: 0) {
                                ForEach(model.expenses) { expense in
                                    SharedExpenseRow(
                                        expense: expense,
                                        payerName: expense.payer.flatMap { model.participant($0)?.displayName })
                                    if expense.id != model.expenses.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Space.md.rawValue)
        }
        .background(lana.surface)
        .navigationTitle(model.list.name)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCapturing = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await model.onAppear() }
            .refreshable { await model.onAppear() }
            .sheet(isPresented: $isCapturing) {
                SharedExpenseCaptureView(model: model, onDone: { isCapturing = false })
            }
            .sheet(isPresented: isSettlingBinding) {
                if let debt = settlingDebt {
                    SettleUpView(model: model, debt: debt, onDone: { settlingDebt = nil })
                }
            }
    }

    /// `Debt` no es `Identifiable` — no tiene un id propio, es un valor
    /// calculado a partir de los saldos, no una entidad persistida — por
    /// eso `.sheet(isPresented:)` en vez de `.sheet(item:)`.
    private var isSettlingBinding: Binding<Bool> {
        Binding(
            get: { settlingDebt != nil },
            set: { isPresented in
                if !isPresented {
                    settlingDebt = nil
                }
            })
    }
}

private struct SharedExpenseRow: View {
    @Environment(\.lana) private var lana
    let expense: Expense
    let payerName: String?

    var body: some View {
        HStack(spacing: Space.sm.rawValue) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.concept)
                    .lanaFont(.body)
                    .foregroundStyle(lana.textPrimary)
                HStack(spacing: 4) {
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    if let payerName {
                        Text("· Pagó \(payerName)")
                    }
                }
                .lanaFont(.caption)
                .foregroundStyle(lana.textSecondary)
            }
            Spacer()
            Text(expense.amount.formatted())
                .lanaFont(.body)
                .monospacedDigit()
                .foregroundStyle(lana.textPrimary)
        }
        .padding(.vertical, Space.xs.rawValue)
    }
}

#Preview {
    let alice = Participant(displayName: "Tú")
    let bob = Participant(displayName: "Sam")
    let list = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .equally(among: [alice.id, bob.id]))
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            SharedListDetailView(model: SharedListDetailModel(
                list: list,
                sharedListStore: InMemorySharedListStore(seed: [list]),
                expenseStore: InMemoryExpenseStore()))
        }
        .lanaTheme(theme)
    }
}
