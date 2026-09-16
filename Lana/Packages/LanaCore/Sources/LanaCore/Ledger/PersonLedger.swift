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

    /// Quién le paga a quién para quedar a mano, sin que nadie pague ni cobre
    /// más que su saldo (ADR-0053).
    ///
    /// Cada deudor reparte lo que debe entre quienes cobran, en proporción a
    /// lo que cobra cada uno. Así la lista siempre suma el saldo de arriba —"
    /// debes $21.21" son $21.21 en pagos, no $93 que pagas y $72 que te
    /// pagan—, y quienes compartieron lo mismo deben lo mismo a las mismas
    /// personas, que era lo que la simplificación no respetaba.
    ///
    /// Cuadra al centavo en las dos direcciones: lo de cada deudor suma su
    /// saldo y lo de cada acreedor suma el suyo.
    public func settlementPlan(in sharedListID: SharedListID, currency: Currency) -> [Debt] {
        let balances = netBalances(in: sharedListID)[currency] ?? [:]
        let creditors = balances.filter { $0.value > 0 }.keys.sorted()
        let debtors = balances.filter { $0.value < 0 }.keys.sorted()
        let totalCredit = creditors.reduce(Decimal(0)) { $0 + (balances[$1] ?? 0) }
        guard totalCredit > 0, !debtors.isEmpty else { return [] }

        let cent = Decimal(string: "0.01") ?? 0
        var cells: [ParticipantID: [ParticipantID: Decimal]] = [:]
        for debtor in debtors {
            let owed = -(balances[debtor] ?? 0)
            var row: [ParticipantID: Decimal] = [:]
            var remainders: [(creditor: ParticipantID, remainder: Decimal)] = []
            for creditor in creditors {
                let exact = (owed * (balances[creditor] ?? 0) / totalCredit).rounded(scale: 6, mode: .plain)
                let truncated = exact.rounded(scale: 2, mode: .down)
                row[creditor] = truncated
                remainders.append((creditor, exact - truncated))
            }
            let leftover = owed - row.values.reduce(0, +)
            let leftoverCents = NSDecimalNumber(decimal: (leftover / cent).rounded(scale: 0, mode: .plain)).intValue
            let order = remainders
                .sorted { $0.remainder == $1.remainder ? $0.creditor < $1.creditor : $0.remainder > $1.remainder }
            for index in 0 ..< max(leftoverCents, 0) {
                row[order[index % order.count].creditor, default: 0] += cent
            }
            cells[debtor] = row
        }

        /// Cada fila ya suma exacto; si una columna quedó un centavo arriba y
        /// otra abajo, se mueve el centavo dentro de una fila, que no la
        /// descuadra.
        func received(_ creditor: ParticipantID) -> Decimal {
            debtors.reduce(0) { $0 + (cells[$1]?[creditor] ?? 0) }
        }
        var moves = 0
        while moves < 10000,
              let over = creditors.first(where: { received($0) > (balances[$0] ?? 0) }),
              let under = creditors.first(where: { received($0) < (balances[$0] ?? 0) }),
              let debtor = debtors.first(where: { (cells[$0]?[over] ?? 0) >= cent }) {
            cells[debtor]?[over, default: 0] -= cent
            cells[debtor]?[under, default: 0] += cent
            moves += 1
        }

        return debtors.flatMap { debtor in
            creditors.compactMap { creditor -> Debt? in
                guard let amount = cells[debtor]?[creditor], amount > 0 else { return nil }
                return Debt(from: debtor, to: creditor, amount: Money(amount: amount, currency: currency))
            }
        }
    }

    /// Cómo se llegó al saldo de `participant`, movimiento por movimiento: lo
    /// que puso en cada gasto que pagó, lo que le tocó en cada gasto, y lo que
    /// pagó o recibió al liquidar. Los efectos suman exactamente su saldo en
    /// `netBalances` (ADR-0053).
    public func balanceEntries(
        for participant: ParticipantID,
        in sharedListID: SharedListID,
        currency: Currency) -> [BalanceEntry] {
        var entries: [BalanceEntry] = []
        for transaction in LedgerFold.resolve(events).values {
            guard transaction.kind == .expense,
                  !transaction.isVoided,
                  transaction.sharedListID == sharedListID,
                  transaction.amount.currency == currency,
                  let payer = transaction.payer,
                  let portions = try? transaction.split?.portions(of: transaction.amount)
            else { continue }
            let share = portions[participant]?.amount ?? 0
            let othersShares = portions.filter { $0.key != participant }.values.reduce(Decimal(0)) { $0 + $1.amount }
            let effect = payer == participant ? othersShares : -share
            guard payer == participant || share > 0 else { continue }
            entries.append(BalanceEntry(
                id: transaction.id,
                date: transaction.date,
                concept: transaction.concept,
                amount: transaction.amount,
                payer: payer,
                share: Money(amount: share, currency: currency),
                effect: effect))
        }
        for event in events {
            guard case let .settlementRecorded(settlement) = event,
                  settlement.sharedListID == sharedListID,
                  settlement.amount.currency == currency,
                  settlement.from == participant || settlement.to == participant
            else { continue }
            entries.append(BalanceEntry(
                id: settlement.id,
                date: settlement.date,
                concept: "Liquidación",
                amount: settlement.amount,
                payer: settlement.from,
                share: Money(amount: 0, currency: currency),
                isSettlement: true,
                effect: settlement.from == participant ? settlement.amount.amount : -settlement.amount.amount))
        }
        return entries.sorted { ($0.date, $0.id.rawValue.uuidString) < ($1.date, $1.id.rawValue.uuidString) }
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
