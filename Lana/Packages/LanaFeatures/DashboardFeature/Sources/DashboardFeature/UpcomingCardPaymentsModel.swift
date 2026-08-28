import Foundation
import LanaCore
import Observation

/// Cuánto toca pagar de tarjetas en la quincena vigente — pedido explícito
/// del usuario ("esta quincena vas a pagar tanto de estas tarjetas").
/// Quincena = días 1-15 o 16-fin de mes, según el día de hoy. Usa
/// `CardLedger` de verdad (ya wireado en Fase 7.5) — el monto por tarjeta
/// es lo que falta del último estado de cuenta
/// (`outstandingStatementBalance`), lo mismo que ya usa el botón "Pagar" en
/// el detalle de cada tarjeta, no una cifra nueva inventada aquí.
@MainActor
@Observable
public final class UpcomingCardPaymentsModel {
    /// Una tarjeta con pago pendiente dentro de la quincena vigente.
    public struct CardDue: Identifiable, Sendable {
        public let card: Card
        public let amount: Money
        public var id: CardID {
            card.id
        }
    }

    /// El total pendiente, por moneda — separado, nunca sumado entre
    /// monedas distintas (Docs/CONVENTIONS.md → Multi-moneda).
    public struct CurrencyTotal: Identifiable, Sendable {
        public var id: Currency {
            currency
        }

        public let currency: Currency
        public let amount: Decimal
    }

    /// Las tarjetas con pago pendiente esta quincena, por alias.
    public private(set) var dueThisPayPeriod: [CardDue] = []
    /// La suma de lo pendiente, por moneda.
    public private(set) var totalsByCurrency: [CurrencyTotal] = []

    private let cardStore: any CardStore
    private let cardPaymentStore: any CardPaymentStore
    private let calendar: Calendar

    /// - Parameters:
    ///   - cardStore: de dónde se leen las tarjetas.
    ///   - cardPaymentStore: de dónde se leen los eventos crudos que
    ///     `CardLedger` necesita.
    public init(cardStore: any CardStore, cardPaymentStore: any CardPaymentStore, calendar: Calendar = .current) {
        self.cardStore = cardStore
        self.cardPaymentStore = cardPaymentStore
        self.calendar = calendar
    }

    /// Se llama cuando la pantalla aparece.
    public func onAppear(asOf date: Date = Date()) async {
        await load(asOf: date)
    }

    private func load(asOf date: Date) async {
        guard let cards = try? await cardStore.cards() else { return }
        guard let events = try? await cardPaymentStore.events() else { return }
        guard let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count else { return }
        let ledger = CardLedger(events: events)
        let payPeriod = Self.currentPayPeriod(for: date, calendar: calendar)

        var dues: [CardDue] = []
        for card in cards {
            guard card.kind == .credit, let dueDay = card.dueDay else { continue }
            let effectiveDueDay = min(dueDay, daysInMonth)
            guard payPeriod.contains(effectiveDueDay) else { continue }
            let amount = ledger.outstandingStatementBalance(for: card, asOf: date, calendar: calendar)
            guard amount.amount > 0 else { continue }
            dues.append(CardDue(card: card, amount: amount))
        }
        dueThisPayPeriod = dues.sorted { $0.card.alias < $1.card.alias }

        var byCurrency: [Currency: Decimal] = [:]
        for due in dues {
            byCurrency[due.amount.currency, default: 0] += due.amount.amount
        }
        totalsByCurrency = byCurrency.map { CurrencyTotal(currency: $0.key, amount: $0.value) }
            .sorted { $0.currency.rawValue < $1.currency.rawValue }
    }

    /// Días 1-15 si hoy cae en esa mitad del mes; si no, del 16 al último
    /// día real del mes (28-31, según el mes).
    private static func currentPayPeriod(for date: Date, calendar: Calendar) -> ClosedRange<Int> {
        let today = calendar.component(.day, from: date)
        guard today > 15, let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count else {
            return 1 ... 15
        }
        return 16 ... daysInMonth
    }
}
