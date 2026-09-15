import LanaCore
import LanaDesign
import SwiftUI

/// El drill-down de una tarjeta (Fase 6.5, calca `TarjetaDetalle.dc.html`).
/// El botón de regresar lo da `NavigationStack`, no se dibuja a mano.
public struct CardDetailView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: CardDetailModel
    @State private var isPaying = false
    private let onEdit: () -> Void
    private let onExpenseTap: (Expense) -> Void

    public init(model: CardDetailModel, onEdit: @escaping () -> Void, onExpenseTap: @escaping (Expense) -> Void) {
        self.model = model
        self.onEdit = onEdit
        self.onExpenseTap = onExpenseTap
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Space.md.rawValue) {
                if model.card.kind == .credit, let limit = model.card.limit, let cutoffDay = model.card.cutoffDay {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Debes en total")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.ink50)
                            Text(model.totalDebt.formatted())
                                .lanaFont(.largeAmount)
                                .monospacedDigit()
                                .foregroundStyle(lana.ink)

                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(lana.hairlineStrong)
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color(hex: model.card.colorHex) ?? lana.accent)
                                            .frame(width: proxy.size.width * model.limitFraction)
                                    }
                            }
                            .frame(height: 6)

                            HStack {
                                Text("\(model.totalDebt.formatted()) de \(limit.formatted()) límite")
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.ink50)
                                Spacer()
                                Text("Corte el \(cutoffDay)")
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.ink50)
                            }

                            Divider()

                            // Lo ya facturado (para pagar antes de que
                            // genere intereses) contra lo que se sigue
                            // acumulando en el ciclo abierto — dos cifras
                            // distintas, no una sola "deuda" genérica.
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Para el corte")
                                        .lanaFont(.caption)
                                        .foregroundStyle(lana.ink50)
                                    Text(model.statementDue.formatted())
                                        .lanaFont(.body)
                                        .monospacedDigit()
                                        .foregroundStyle(lana.ink)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Después del corte")
                                        .lanaFont(.caption)
                                        .foregroundStyle(lana.ink50)
                                    Text(model.currentCycleAccrued.formatted())
                                        .lanaFont(.body)
                                        .monospacedDigit()
                                        .foregroundStyle(lana.ink)
                                }
                            }

                            Button("Pagar") {
                                isPaying = true
                            }
                            .buttonStyle(.bordered)
                            .tint(lana.accent)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                if !model.categoryTotals.isEmpty {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Por categoría en esta tarjeta")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.ink50)
                            ForEach(model.categoryTotals) { total in
                                HStack {
                                    Text(total.category.capitalized)
                                        .lanaFont(.body)
                                        .foregroundStyle(lana.ink)
                                    Spacer()
                                    Text(Money(amount: total.amount, currency: total.currency).formatted())
                                        .lanaFont(.body)
                                        .monospacedDigit()
                                        .foregroundStyle(lana.ink)
                                }
                            }
                        }
                    }
                }

                DaySectionListView(sections: model.daySections, onSelect: onExpenseTap)
            }
            .padding(Space.md.rawValue)
        }
        .background(lana.bg)
        .navigationTitle(model.card.alias)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Editar", action: onEdit)
                }
            }
            .task { await model.onAppear() }
            // `CardsView` (la lista) ya lo tenía y el detalle no, así que
            // jalar hacia abajo aquí no hacía absolutamente nada — parecía
            // que el gasto recién capturado no existía (ADR-0032).
            .refreshable { await model.onAppear() }
            .sheet(isPresented: $isPaying) {
                AddCardPaymentView(model: model, onDone: { isPaying = false })
            }
    }
}

#Preview {
    if let card = try? Card(
        alias: "BBVA Oro",
        lastFourDigits: "4821",
        limit: Money(amount: 10000, currency: .mxn),
        cutoffDay: 15,
        dueDay: 5) {
        NavigationStack {
            CardDetailView(
                model: CardDetailModel(
                    card: card,
                    store: InMemoryExpenseStore(),
                    cardPaymentStore: InMemoryCardPaymentStore()),
                onEdit: {},
                onExpenseTap: { _ in })
        }
    }
}
