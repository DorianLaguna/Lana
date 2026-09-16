import LanaCore
import LanaDesign
import SwiftUI

/// La pestaña Tarjetas (rediseño, sección 04): cuánto debes, en qué tarjeta y
/// qué se paga pronto. Sin lógica propia — refleja `CardsModel`.
public struct CardsView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: CardsModel
    /// Un solo estado para alta y edición — `AddCardModel` ya sabe cuál es.
    @State private var addCardModel: AddCardModel?
    @State private var cardPendingDelete: Card?
    /// El editor de un movimiento vive en `DashboardFeature`, que esta feature
    /// no puede importar; la app resuelve el toque.
    private let onExpenseTap: (Expense) -> Void
    /// Reabre la guía de Apple Pay (R1.4). Su hogar es Tarjetas —es captura
    /// automática de gastos, no un método de pago— pero la arma la app, que es
    /// quien conoce `OnboardingFeature`. `nil` solo en previews.
    private let onConfigureApplePay: (() -> Void)?

    public init(
        model: CardsModel,
        onExpenseTap: @escaping (Expense) -> Void,
        onConfigureApplePay: (() -> Void)? = nil) {
        self.model = model
        self.onExpenseTap = onExpenseTap
        self.onConfigureApplePay = onConfigureApplePay
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.cards.isEmpty, !model.isLoading {
                        emptyState
                    } else {
                        totalSection
                            .padding(.bottom, Space.p30.rawValue)
                        cardList
                        if let onConfigureApplePay {
                            applePayRow(onConfigureApplePay)
                                .padding(.top, Space.p28.rawValue)
                        }
                    }
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.sm.rawValue)
                .tabBarClearance()
            }
            .background(lana.bg)
            .navigationTitle("Tarjetas")
            .lanaInlineNavigationTitle()
            .navigationDestination(for: CardID.self) { cardID in
                // Por `CardID` y no por `Card`: al refrescar tras editar, el
                // destino se recalcula con la versión viva de la tarjeta.
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
                    .accessibilityLabel("Agregar tarjeta")
                }
            }
            .sheet(item: $addCardModel) { addCardModel in
                AddCardView(model: addCardModel, onDone: {
                    self.addCardModel = nil
                    // `AddCardModel.save()` escribe directo en `cardStore`, sin
                    // pasar por `CardsModel`.
                    Task { await model.onAppear() }
                })
            }
            .confirmationDialog(
                "¿Borrar \(cardPendingDelete?.alias ?? "esta tarjeta")?",
                isPresented: isDeletingBinding,
                titleVisibility: .visible) {
                    Button("Borrar", role: .destructive) {
                        if let card = cardPendingDelete {
                            Task { try? await model.delete(card) }
                        }
                        cardPendingDelete = nil
                    }
            } message: {
                Text("Los movimientos que pagaste con ella se quedan, marcados como de una tarjeta eliminada.")
            }
        }
        .task { await model.onAppear() }
        .refreshable { await model.onAppear() }
    }

    // MARK: - Debes en total

    private var totalSection: some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            Text("Debes en total")
                .lanaFont(.footnote)
                .foregroundStyle(lana.ink50)
            Text(totalText)
                .lanaFont(.totalAmount)
                .foregroundStyle(lana.ink)
                .contentTransition(.numericText())
            Text(coverageText)
                .lanaFont(.detail)
                .foregroundStyle(lana.ink42)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Una cifra por moneda, nunca sumadas entre sí.
    private var totalText: String {
        guard !model.totalDebt.isEmpty else { return Money(amount: 0, currency: .mxn).formatted() }
        return model.totalDebt.map { $0.formatted() }.joined(separator: " · ")
    }

    private var coverageText: String {
        let withDebt = model.cardsWithDebtCount
        let total = model.cards.count
        guard withDebt > 0 else { return total == 1 ? "en tu única tarjeta" : "en ninguna de tus \(total) tarjetas" }
        return "en \(withDebt) de \(total) \(total == 1 ? "tarjeta" : "tarjetas")"
    }

    // MARK: - Lista

    private var cardList: some View {
        VStack(spacing: Space.p10.rawValue) {
            ForEach(model.cardsByDebt) { card in
                NavigationLink(value: card.id) {
                    CardRow(card: card, debt: model.debt(for: card))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Editar") { addCardModel = model.makeAddCardModel(editing: card) }
                    Button("Borrar", role: .destructive) { cardPendingDelete = card }
                }
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "creditcard",
            title: "Sin tarjetas",
            message: "Dalas de alta y Lana sabrá con qué pagaste al dictar.",
            actionTitle: "Agregar tarjeta",
            action: { addCardModel = model.makeAddCardModel() })
            .padding(.top, Space.xxl.rawValue)
    }

    // MARK: - Apple Pay

    /// Cuando ya está configurada es una fila discreta; cuando no, invita con
    /// el fondo del acento. Nunca dice "activado": Lana no puede comprobar que
    /// la automatización de Atajos exista.
    private func applePayRow(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LanaCard(radius: .inner, fill: model.hasSeenApplePayGuide ? .surface : .accent) {
                HStack(spacing: Space.p12.rawValue) {
                    VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                        Text("Compras con Apple Pay")
                            .lanaFont(.bodyEmphasis)
                            .foregroundStyle(lana.ink)
                        Text(model.hasSeenApplePayGuide
                            ? "Vuelve a ver la guía cuando quieras"
                            : "Registra tus compras automáticamente")
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(model.hasSeenApplePayGuide ? lana.ink42 : lana.ink70)
                    }
                    Spacer(minLength: Space.sm.rawValue)
                    RowChevron()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var isDeletingBinding: Binding<Bool> {
        Binding(
            get: { cardPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    cardPendingDelete = nil
                }
            })
    }
}

/// Una tarjeta en la lista: color, alias, últimos cuatro y corte, deuda y qué
/// tanto del límite llevas. Las que no deben nada se apagan.
private struct CardRow: View {
    @Environment(\.lana) private var lana
    let card: Card
    let debt: Money?

    private var hasDebt: Bool {
        (debt?.amount ?? 0) > 0
    }

    var body: some View {
        LanaCard(fill: hasDebt ? .surface : .dim) {
            HStack(spacing: Space.p12.rawValue) {
                RoundedRectangle(cornerRadius: Radius.swatch.rawValue, style: .continuous)
                    .fill(Color(hex: card.colorHex) ?? lana.accentFill)
                    .frame(width: LanaMetrics.cardSwatchWidth, height: LanaMetrics.cardSwatchHeight)
                    .opacity(hasDebt ? 1 : 0.5)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                    Text(card.alias)
                        .lanaFont(.rowTitle)
                        .foregroundStyle(hasDebt ? lana.ink : lana.ink70)
                    if let subtitle {
                        Text(subtitle)
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.ink42)
                    }
                }

                Spacer(minLength: Space.sm.rawValue)

                VStack(alignment: .trailing, spacing: Space.p2.rawValue) {
                    if let debt, hasDebt {
                        Text(debt.formatted())
                            .lanaFont(.rowAmountStrong)
                            .foregroundStyle(lana.ink)
                        if let limitText {
                            Text(limitText)
                                .lanaFont(.caption2)
                                .foregroundStyle(lana.ink42)
                        }
                    } else {
                        Text("Sin deuda")
                            .lanaFont(.detail)
                            .foregroundStyle(lana.ink35)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "•••• 9131 · corte día 12" — cada parte se omite si no se registró.
    private var subtitle: String? {
        var parts: [String] = []
        if let lastFourDigits = card.lastFourDigits {
            parts.append("•••• \(lastFourDigits)")
        }
        if let cutoffDay = card.cutoffDay {
            parts.append("corte día \(cutoffDay)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var limitText: String? {
        guard let limit = card.limit, limit.amount > 0, let debt else { return nil }
        let percent = NSDecimalNumber(decimal: debt.amount / limit.amount * 100).intValue
        return "\(percent)% del límite"
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        CardsView(
            model: CardsModel(
                cardStore: InMemoryCardStore(),
                store: InMemoryExpenseStore(),
                cardPaymentStore: InMemoryCardPaymentStore()),
            onExpenseTap: { _ in },
            onConfigureApplePay: {})
            .lanaTheme(theme)
    }
}
