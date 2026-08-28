import LanaCore
import LanaDesign
import SwiftUI

/// La pestaña Tarjetas: lista, alta y detalle (Fase 6.5, calca
/// `Tarjetas.dc.html`). Sin lógica propia — refleja `CardsModel`
/// (Docs/ARCHITECTURE.md).
public struct CardsView: View {
    @Environment(\.lana) private var lana
    private let model: CardsModel
    /// Un solo estado para alta y edición — `AddCardModel` ya sabe cuál es
    /// según se haya creado con `editing: nil` o con una tarjeta.
    @State private var addCardModel: AddCardModel?
    /// `CardsFeature` no puede construir un editor de gasto — eso vive en
    /// `DashboardFeature`, y las features no se importan entre sí — así
    /// que la app (`ContentView`, que sí importa ambas) decide qué hacer
    /// cuando se toca un gasto dentro del detalle de una tarjeta.
    private let onExpenseTap: (Expense) -> Void

    public init(model: CardsModel, onExpenseTap: @escaping (Expense) -> Void) {
        self.model = model
        self.onExpenseTap = onExpenseTap
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.cards.isEmpty, !model.isLoading {
                    EmptyStateView(
                        systemImage: "creditcard",
                        title: "Sin tarjetas",
                        message: "Agrega una para ver sus gastos y su deuda.",
                        actionTitle: "Agregar tarjeta",
                        action: { addCardModel = model.makeAddCardModel() })
                } else {
                    ScrollView {
                        VStack(spacing: Space.sm.rawValue) {
                            ForEach(model.cards) { card in
                                NavigationLink(value: card.id) {
                                    CardRow(card: card, debt: model.debt(for: card))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Space.md.rawValue)
                    }
                }
            }
            .background(lana.surface)
            .navigationTitle("Tarjetas")
            // Por `CardID`, no por `Card`: así, cuando `model.cards` se
            // refresca tras editar, este destino se recalcula con la
            // versión viva de la tarjeta en vez de quedarse con la que
            // estaba al momento de navegar.
            .navigationDestination(for: CardID.self) { cardID in
                if let card = model.cards.first(where: { $0.id == cardID }) {
                    CardDetailView(
                        model: model.makeCardDetailModel(for: card),
                        onEdit: { addCardModel = model.makeAddCardModel(editing: card) },
                        onExpenseTap: onExpenseTap)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addCardModel = model.makeAddCardModel()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $addCardModel) { addCardModel in
                AddCardView(model: addCardModel, onDone: {
                    self.addCardModel = nil
                    // `AddCardModel.save()` escribe directo en `cardStore`,
                    // no pasa por `CardsModel.save()` — sin este refresco la
                    // lista se queda con los datos viejos hasta que la vista
                    // vuelva a aparecer (cambiar de tab), y parece que no
                    // guardó.
                    Task { await model.onAppear() }
                })
            }
        }
        .task { await model.onAppear() }
        .refreshable { await model.onAppear() }
    }
}

private struct CardRow: View {
    @Environment(\.lana) private var lana
    let card: Card
    let debt: Money?

    var body: some View {
        LanaCard {
            HStack(spacing: Space.sm.rawValue) {
                RoundedRectangle(cornerRadius: Space.xs.rawValue, style: .continuous)
                    .fill((Color(hex: card.colorHex) ?? lana.accent).gradient)
                    .frame(width: 52, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.alias)
                        .lanaFont(.body)
                        .foregroundStyle(lana.textPrimary)
                    if let lastFourDigits = card.lastFourDigits {
                        Text("•••• \(lastFourDigits)")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let debt, debt.amount > 0 {
                        Text(debt.formatted())
                            .lanaFont(.body)
                            .monospacedDigit()
                            .foregroundStyle(lana.textPrimary)
                        Text("debes")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    } else {
                        Text("Sin deuda")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(lana.textSecondary.opacity(0.6))
            }
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        CardsView(
            model: CardsModel(
                cardStore: InMemoryCardStore(),
                store: InMemoryExpenseStore(),
                cardPaymentStore: InMemoryCardPaymentStore()),
            onExpenseTap: { _ in })
            .lanaTheme(theme)
    }
}
