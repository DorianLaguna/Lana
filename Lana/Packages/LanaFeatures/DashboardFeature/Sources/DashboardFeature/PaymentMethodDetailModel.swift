import Foundation
import LanaCore
import Observation

/// Cuánto se gastó en una categoría, dentro del drill-down de una forma de
/// pago (`PaymentMethodDetailView`).
public struct CategoryWithinPaymentMethodTotal: Identifiable, Sendable {
    public var id: String {
        category
    }

    public let category: String
    public let amount: Decimal
    public let currency: Currency
}

/// Cuánto se gastó con una tarjeta específica, dentro del drill-down de
/// "crédito" o "débito" — sin esto, las dos formas de pago que sí
/// distinguen tarjeta (a diferencia de efectivo/transferencia) se veían
/// igual de genéricas que las que no, y no había forma de saber con cuál
/// tarjeta se pagó cada cosa (pedido explícito del usuario).
public struct CardWithinPaymentMethodTotal: Identifiable, Sendable {
    public var id: CardID {
        cardID
    }

    public let cardID: CardID
    public let alias: String
    public let amount: Decimal
    public let currency: Currency
}

/// El drill-down de una forma de pago del mes: total, desglose por
/// categoría y las transacciones pagadas así, agrupadas por día — mismo
/// patrón que `CategoryDetailModel`, filtrando por cómo se pagó en vez de
/// por categoría. Antes, tocar una rebanada de "Por forma de pago" en el
/// Dashboard no hacía nada (el callback de tap estaba vacío) — este modelo
/// es lo que faltaba para que ese drill-down exista de verdad.
///
/// Los gastos se derivan de `DashboardModel.expenses`, no de una copia
/// propia — ver el comment de `CategoryDetailModel` para el bug que eso
/// evita. Las tarjetas (`cards`) sí son suyas: no viven en `DashboardModel`
/// y no forman parte del bug de gastos desincronizados.
@MainActor
@Observable
public final class PaymentMethodDetailModel {
    /// La forma de pago que se está viendo ("efectivo", "crédito"...) —
    /// mismas etiquetas que `DashboardModel.paymentMethodTotals`.
    public let label: String
    /// `true` mientras se cargan las tarjetas.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar las tarjetas.
    public private(set) var errorMessage: String?
    /// Las tarjetas guardadas — para resolver alias en `cardTotals`.
    public private(set) var cards: [Card] = []

    /// De dónde derivan los gastos — la vista lo necesita para las filas.
    let source: any ExpenseProviding
    private let cardStore: any CardStore

    /// - Parameters:
    ///   - label: la forma de pago a filtrar (ya como etiqueta, no `PaymentMethod`).
    ///   - source: de dónde salen los gastos del periodo vigente — el mismo
    ///     modelo que ya está en pantalla, nunca una copia propia. Es el
    ///     Dashboard cuando se entra desde el mes y la vista anual cuando se
    ///     entra desde el año.
    ///   - cardStore: de dónde se leen las tarjetas, para mostrar con cuál se pagó cada cosa.
    init(label: String, source: any ExpenseProviding, cardStore: any CardStore) {
        self.label = label
        self.source = source
        self.cardStore = cardStore
    }

    /// Carga las tarjetas, para resolver alias en `cardTotals`. Se llama
    /// cuando la pantalla aparece.
    public func onAppear() async {
        isLoading = true
        errorMessage = nil
        do {
            cards = try await cardStore.cards()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Los gastos pagados con esta forma de pago, dentro del periodo.
    public var expenses: [Expense] {
        source.expenses
            .filter { $0.kind == .expense && DashboardModel.paymentMethodLabel($0.paymentMethod) == label }
    }

    /// Ver el mismo campo en el modelo del que deriva — nunca su propia copia.
    public var viewerIdentities: [SharedListID: ParticipantID] {
        source.viewerIdentities
    }

    /// Cuánto se gastó en total, con esta forma de pago, en el periodo — la
    /// parte real de quien mira, no el total de un gasto compartido
    /// (`Expense.personalAmount`).
    public var total: Decimal {
        expenses.reduce(0) { $0 + $1.personalAmount(viewerIdentities: viewerIdentities).amount }
    }

    /// La moneda de los gastos de esta forma de pago — `.mxn` si no hay ninguno.
    public var currency: Currency {
        expenses.first?.amount.currency ?? .mxn
    }

    /// El desglose por categoría, de mayor a menor.
    public var categoryTotals: [CategoryWithinPaymentMethodTotal] {
        var totals: [String: Decimal] = [:]
        for expense in expenses {
            let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
            totals[expense.category ?? "otro", default: 0] += personal.amount
        }
        return totals
            .map { CategoryWithinPaymentMethodTotal(category: $0.key, amount: $0.value, currency: currency) }
            .sorted { $0.amount > $1.amount }
    }

    /// Los gastos de esta forma de pago, agrupados por día.
    public var daySections: [DaySection] {
        expenses.groupedByDay(calendar: source.calendar)
    }

    /// El desglose por tarjeta, de mayor a menor — vacío para "efectivo" y
    /// "transferencia", que no llevan tarjeta.
    public var cardTotals: [CardWithinPaymentMethodTotal] {
        var totals: [CardID: Decimal] = [:]
        for expense in expenses {
            guard let cardID = Self.cardID(from: expense.paymentMethod) else { continue }
            totals[cardID, default: 0] += expense.amount.amount
        }
        let aliasesByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.alias) })
        return totals
            .map { cardID, amount in
                CardWithinPaymentMethodTotal(
                    cardID: cardID,
                    alias: aliasesByID[cardID] ?? "Tarjeta borrada",
                    amount: amount,
                    currency: currency)
            }
            .sorted { $0.amount > $1.amount }
    }

    private static func cardID(from method: PaymentMethod?) -> CardID? {
        switch method {
        case let .credit(cardID), let .debit(cardID):
            cardID
        case .cash, .transfer, nil:
            nil
        }
    }
}
