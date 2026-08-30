import Foundation

/// Pliega los eventos de una lista compartida en saldos entre participantes.
/// Puro, sin dependencias del sistema — se prueba sin simulador
/// (Docs/PLAN.md). Es, según el propio plan, la suite más importante del
/// repo.
///
/// Deuda con personas (este tipo) y deuda con tarjetas (`CardLedger`) son
/// ledgers independientes que **nunca** se suman ni se mezclan
/// (Docs/CLAUDE.md) — un gasto compartido pagado con tarjeta alimenta los
/// dos, pero cada uno se lee por separado.
public struct PersonLedger: Sendable {
    private let events: [ExpenseEvent]

    public init(events: [ExpenseEvent] = []) {
        self.events = events
    }

    public func appending(_ event: ExpenseEvent) -> PersonLedger {
        PersonLedger(events: events + [event])
    }

    /// Saldo neto de cada participante en `sharedListID`, por moneda.
    /// Positivo significa que se le debe; negativo, que debe. La deuda
    /// compartida se fija en la moneda del gasto — nunca se convierte
    /// (Docs/CONVENTIONS.md → Multi-moneda), por eso el resultado está
    /// separado por `Currency` en vez de sumado en una sola cifra.
    public func netBalances(in sharedListID: SharedListID) -> [Currency: [ParticipantID: Decimal]] {
        var balances: [Currency: [ParticipantID: Decimal]] = [:]

        func adjust(_ participant: ParticipantID, by amount: Decimal, currency: Currency) {
            balances[currency, default: [:]][participant, default: 0] += amount
        }

        let resolved = LedgerFold.resolve(events)
        for transaction in resolved.values {
            guard transaction.kind == .expense,
                  !transaction.isVoided,
                  transaction.sharedListID == sharedListID,
                  let payer = transaction.payer,
                  let split = transaction.split
            else { continue }

            guard let portions = try? split.portions(of: transaction.amount) else { continue }
            for (participant, owed) in portions where participant != payer {
                adjust(participant, by: -owed.amount, currency: transaction.amount.currency)
                adjust(payer, by: owed.amount, currency: transaction.amount.currency)
            }
        }

        for event in events {
            guard case let .settlementRecorded(settlement) = event,
                  settlement.sharedListID == sharedListID
            else { continue }
            adjust(settlement.from, by: settlement.amount.amount, currency: settlement.amount.currency)
            adjust(settlement.to, by: -settlement.amount.amount, currency: settlement.amount.currency)
        }

        return balances
    }

    /// Simplifica las deudas de `sharedListID` en `currency` a un número
    /// mínimo de transferencias que las salda (Docs/PLAN.md → "Simplificación
    /// de deudas para 3+ personas").
    public func simplifiedDebts(in sharedListID: SharedListID, currency: Currency) -> [Debt] {
        let balances = netBalances(in: sharedListID)[currency] ?? [:]
        return Self.simplify(balances, currency: currency)
    }

    /// El detalle, gasto por gasto, de la relación directa entre `from` y
    /// `to` en `sharedListID` — el "por qué" detrás de un `Debt`. A
    /// diferencia de `simplifiedDebts`, que con 3+ participantes puede
    /// combinar deudas transitivas (A le debe a B, B le debe a C se
    /// simplifica a A le debe a C directamente), esto es literalmente "qué
    /// gastos involucraron a estos dos y cuánto le tocó a cada quien" —
    /// ignora a cualquier tercer participante. Con exactamente dos
    /// participantes en la lista, la suma de `signedEffect` siempre coincide
    /// con el `Debt` simplificado; con 3+, es la historia real entre ambos,
    /// que puede no ser idéntica a la cifra ya simplificada (ADR-0024).
    /// Un gasto `.payerOnly` nunca contribuye — nadie más debe nada de él.
    public func contributions(
        between from: ParticipantID,
        and to: ParticipantID,
        in sharedListID: SharedListID) -> [DebtContribution] {
        let resolved = LedgerFold.resolve(events)
        var results: [DebtContribution] = []
        for transaction in resolved.values {
            guard transaction.kind == .expense,
                  !transaction.isVoided,
                  transaction.sharedListID == sharedListID,
                  let payer = transaction.payer,
                  payer == from || payer == to,
                  let split = transaction.split,
                  let portions = try? split.portions(of: transaction.amount),
                  let fromShare = portions[from],
                  let toShare = portions[to]
            else { continue }

            let signedEffect = payer == to ? fromShare.amount : -toShare.amount
            results.append(DebtContribution(
                id: transaction.id,
                date: transaction.date,
                concept: transaction.concept,
                amount: transaction.amount,
                payer: payer,
                fromShare: fromShare,
                toShare: toShare,
                signedEffect: signedEffect))
        }
        return results.sorted { $0.date < $1.date }
    }

    private static func simplify(_ balances: [ParticipantID: Decimal], currency: Currency) -> [Debt] {
        var remaining = balances.filter { $0.value != 0 }
        var debts: [Debt] = []

        while true {
            guard let (creditorID, creditorAmount) = largest(in: remaining, positive: true) else { break }
            guard let (debtorID, debtorAmount) = largest(in: remaining, positive: false) else { break }

            let transfer = min(creditorAmount, -debtorAmount)
            debts.append(Debt(from: debtorID, to: creditorID, amount: Money(amount: transfer, currency: currency)))

            remaining[creditorID] = creditorAmount - transfer
            remaining[debtorID] = debtorAmount + transfer
            if remaining[creditorID] == 0 {
                remaining.removeValue(forKey: creditorID)
            }
            if remaining[debtorID] == 0 {
                remaining.removeValue(forKey: debtorID)
            }
        }

        return debts
    }

    /// El acreedor (o deudor) con mayor magnitud; empates se rompen por
    /// `ParticipantID` para que el resultado sea determinista.
    private static func largest(
        in balances: [ParticipantID: Decimal],
        positive: Bool) -> (ParticipantID, Decimal)? {
        balances
            .filter { positive ? $0.value > 0 : $0.value < 0 }
            .max { lhs, rhs in
                let magnitude = positive ? (lhs.value, rhs.value) : (-lhs.value, -rhs.value)
                return magnitude.0 == magnitude.1 ? lhs.key < rhs.key : magnitude.0 < magnitude.1
            }
            .map { ($0.key, $0.value) }
    }
}
