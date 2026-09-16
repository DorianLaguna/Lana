import LanaCore
import LanaDesign
import SwiftUI

/// El detalle de una tarjeta (rediseño, sección 05): cuánto debes, cuánto
/// entra en este corte y qué se paga después — la distinción que más dinero
/// ahorra y que antes no se veía.
public struct CardDetailView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: CardDetailModel
    @State private var isPaying = false
    @State private var paysEverything = false
    private let onEdit: () -> Void
    private let onExpenseTap: (Expense) -> Void

    /// A partir de aquí, la barra de límite pasa a `attention`: es un dato con
    /// su acción al lado, no un regaño.
    private static var limitWarningThreshold: Double {
        0.8
    }

    public init(model: CardDetailModel, onEdit: @escaping () -> Void, onExpenseTap: @escaping (Expense) -> Void) {
        self.model = model
        self.onEdit = onEdit
        self.onExpenseTap = onExpenseTap
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                totalSection
                    .padding(.bottom, Space.p22.rawValue)

                if model.card.kind == .credit {
                    cycleSection
                        .padding(.bottom, Space.p22.rawValue)
                    limitSection
                    actions
                        .padding(.bottom, Space.xl.rawValue)
                }

                if !model.categoryTotals.isEmpty {
                    SectionHeader("En qué usas esta tarjeta")
                        .padding(.bottom, Space.p12.rawValue)
                    RankedBarList(
                        items: model.categoryTotals.prefix(4).map(rankedItem),
                        barHeight: LanaMetrics.barThin,
                        itemSpacing: .p14)
                        .padding(.bottom, Space.p30.rawValue)
                }

                DaySectionListView(
                    sections: model.daySections,
                    cardAlias: model.card.alias,
                    onSelect: onExpenseTap)
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle(model.card.alias)
        .lanaInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar", action: onEdit)
            }
        }
        .task { await model.onAppear() }
        .refreshable { await model.onAppear() }
        .sheet(isPresented: $isPaying) {
            AddCardPaymentView(
                model: model,
                prefillsStatementDue: paysEverything,
                onDone: { isPaying = false })
        }
    }

    // MARK: - Debes en total

    private var totalSection: some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            Text("Debes en total")
                .lanaFont(.footnote)
                .foregroundStyle(lana.ink50)
            Text(model.totalDebt.formatted())
                .lanaFont(.screenAmount)
                .foregroundStyle(lana.ink)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Corte

    /// Lo que urge contra lo que puede esperar.
    private var cycleSection: some View {
        HStack(spacing: Space.p10.rawValue) {
            cycleCard(
                title: "Para el corte",
                amount: model.statementDue,
                footnote: model.card.dueDay.map { "límite día \($0)" },
                footnoteColor: lana.attention,
                amountColor: lana.ink)
            cycleCard(
                title: "Después del corte",
                amount: model.currentCycleAccrued,
                footnote: "cae el mes que entra",
                footnoteColor: lana.ink35,
                amountColor: lana.ink70)
        }
    }

    private func cycleCard(
        title: String,
        amount: Money,
        footnote: String?,
        footnoteColor: Color,
        amountColor: Color) -> some View {
        LanaCard(padding: .p14, radius: .inner) {
            VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                Text(title)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                Text(amount.formatted())
                    .lanaFont(.statAmount)
                    .foregroundStyle(amountColor)
                if let footnote {
                    Text(footnote)
                        .lanaFont(.caption2)
                        .foregroundStyle(footnoteColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Límite

    @ViewBuilder
    private var limitSection: some View {
        if let limit = model.card.limit, limit.amount > 0 {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                HStack {
                    Text("Llevas \(Int(model.limitFraction * 100))% de tu límite")
                        .lanaFont(.detail)
                        .foregroundStyle(lana.ink70)
                    Spacer(minLength: Space.sm.rawValue)
                    Text(limit.formatted())
                        .lanaFont(.detail)
                        .foregroundStyle(lana.ink42)
                }
                ProgressTrack(
                    fraction: model.limitFraction,
                    height: LanaMetrics.barMedium,
                    fill: model.limitFraction >= Self.limitWarningThreshold ? .attention : .accent)
            }
            .padding(.bottom, Space.p22.rawValue)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Acciones

    /// El pago **no cuenta como gasto**: es un movimiento de tipo pago, y eso
    /// lo dice el propio formulario.
    private var actions: some View {
        HStack(spacing: Space.p10.rawValue) {
            Button("Registrar pago") {
                paysEverything = false
                isPaying = true
            }
            .buttonStyle(.lana(isExpanded: true))

            Button("Pagar todo") {
                paysEverything = true
                isPaying = true
            }
            .buttonStyle(.lana(.secondary))
            .disabled(model.totalDebt.amount <= 0)
        }
    }

    private func rankedItem(_ total: CategoryTotal) -> RankedBarList.Item {
        RankedBarList.Item(
            id: total.category,
            title: SuggestedCategory(rawValue: total.category)?.displayName
                ?? total.category.prefix(1).uppercased() + total.category.dropFirst(),
            amountText: Money(amount: total.amount, currency: total.currency).formatted(),
            value: NSDecimalNumber(decimal: total.amount).doubleValue)
    }
}

#Preview {
    if let card = try? Card(
        alias: "Bancomer",
        lastFourDigits: "9131",
        limit: Money(amount: 17000, currency: .mxn),
        cutoffDay: 12,
        dueDay: 20) {
        ForEach(LanaTheme.allCases) { theme in
            NavigationStack {
                CardDetailView(
                    model: CardDetailModel(
                        card: card,
                        store: InMemoryExpenseStore(),
                        cardPaymentStore: InMemoryCardPaymentStore()),
                    onEdit: {},
                    onExpenseTap: { _ in })
            }
            .lanaTheme(theme)
        }
    }
}
