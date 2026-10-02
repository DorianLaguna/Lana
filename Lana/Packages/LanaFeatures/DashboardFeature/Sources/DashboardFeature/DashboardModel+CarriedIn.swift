import Foundation
import LanaCore

/// Lo comprado con una tarjeta el mes anterior que ya cuenta en este porque
/// cerró en su corte (ADR-0060). Hoy lo dice mientras el mes no tiene
/// movimientos: explica de dónde sale "Gastaste" el día 1.
public struct CarriedInCard: Identifiable, Sendable {
    public let card: Card
    /// Todo: compras y recurrentes.
    public let amount: Money
    /// Cuántas compras hechas a mano o por Apple Pay.
    public let purchaseCount: Int
    /// Lo que salió de un recurrente: ya se sabía que venía.
    public let recurringAmount: Decimal
    public let recurringCount: Int
    public var id: String {
        "\(card.id)-\(amount.currency.rawValue)"
    }

    /// Lo que de verdad se decidió gastar: el total menos lo recurrente.
    public var purchasesAmount: Decimal {
        amount.amount - recurringAmount
    }
}

// MARK: - Lo que el corte trae del mes anterior

/// Las compras con tarjeta del mes anterior que cerraron en el corte de este
/// (ADR-0060), por tarjeta y separando lo recurrente: lo que Hoy muestra en
/// "Ya cuentan en octubre" y su detalle.
extension DashboardModel {
    /// Lo de `carriedInSections` sumado por tarjeta, de la que más carga a la
    /// que menos. Solo entra lo pagado con crédito después del corte del mes
    /// anterior: es lo único que el corte mueve de un mes a otro.
    func carriedInByCard() -> [CarriedInCard] {
        struct Key: Hashable {
            let cardID: CardID
            let currency: Currency
        }
        struct Sum {
            var amount: Decimal = 0
            var purchaseCount = 0
            var recurringAmount: Decimal = 0
            var recurringCount = 0
        }
        var byCard: [Key: Sum] = [:]
        for expense in carriedInCreditPurchases() {
            guard case let .credit(cardID) = expense.paymentMethod else { continue }
            let key = Key(cardID: cardID, currency: expense.amount.currency)
            let amount = expense.personalAmount(viewerIdentities: viewerIdentities).amount
            byCard[key, default: Sum()].amount += amount
            if !(expense.recurringItemID != nil) {
                byCard[key, default: Sum()].purchaseCount += 1
            } else {
                byCard[key, default: Sum()].recurringAmount += amount
                byCard[key, default: Sum()].recurringCount += 1
            }
        }
        return byCard.compactMap { key, sum in
            guard sum.amount > 0, let card = cards.first(where: { $0.id == key.cardID }) else { return nil }
            return CarriedInCard(
                card: card,
                amount: Money(amount: sum.amount, currency: key.currency),
                purchaseCount: sum.purchaseCount,
                recurringAmount: sum.recurringAmount,
                recurringCount: sum.recurringCount)
        }
        .sorted { $0.amount.amount > $1.amount.amount }
    }

    /// Las compras de una tarjeta que suma `carriedInByCard()`, por día: el
    /// detalle que abre Hoy al tocarla. Las compras y los recurrentes van
    /// aparte: unos se decidieron, los otros ya se sabía que venían. Solo es
    /// recurrente lo ligado a uno; lo que se le parece se pregunta en "Por
    /// revisar" (ADR-0061), no se adivina.
    func carriedInSections(for cardID: CardID, in currency: Currency, recurring: Bool) -> [DaySection] {
        carriedInCreditPurchases()
            .filter {
                $0.paymentMethod == .credit(cardID: cardID) && $0.amount.currency == currency
                    && ($0.recurringItemID != nil) == recurring
            }
            .groupedByDay(calendar: calendar)
    }

    /// Qué parte de "Gastaste" del mes, en 0...1, son estas compras.
    func spentShare(of money: Money) -> Double {
        guard let spent = statistics.total(in: money.currency)?.expenses, spent > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: money.amount / spent).doubleValue)
    }

    /// Lo que ya se pregunta en "Por revisar": ¿esto salió de un recurrente?
    /// Cubre lo que Hoy y Mes tienen cargado —el mes anterior y este—, que es
    /// lo que mueve sus cifras (ADR-0061).
    public var recurringLinkSuggestions: [RecurringLinkSuggestion] {
        var seen = Set<ExpenseID>()
        let loaded = (expenses + calendarExpenses).filter { seen.insert($0.id).inserted }
        return RecurringLinking.suggestions(for: loaded, recurringItems: recurringItems, calendar: calendar)
    }

    private func carriedInCreditPurchases() -> [Expense] {
        expenses.filter { expense in
            guard expense.date < month, expense.kind == .expense,
                  case .credit = expense.paymentMethod else { return false }
            return true
        }
    }
}
