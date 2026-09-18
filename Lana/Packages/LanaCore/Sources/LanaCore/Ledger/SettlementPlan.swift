import Foundation

public extension PersonLedger {
    /// Quién le paga a quién para quedar a mano, sin que nadie pague ni cobre
    /// más que su saldo (ADR-0053).
    ///
    /// Se arma **una sola vez sobre los gastos** —cada deudor reparte lo que
    /// debe entre quienes cobran, en proporción a lo que cobra cada uno— y a
    /// cada fila se le resta lo que ese par ya se liquidó (ADR-0054). Por eso
    /// marcar una fila como pagada la cierra y deja las demás iguales; si el
    /// plan se recalculara desde el saldo, el resto se repartiría otra vez
    /// entre todos y volvería a aparecer una fila hacia quien ya cobró.
    ///
    /// Cuadra al centavo en las dos direcciones: lo de cada deudor suma su
    /// saldo y lo de cada acreedor suma el suyo.
    func settlementPlan(in sharedListID: SharedListID, currency: Currency) -> [Debt] {
        let net = netBalances(in: sharedListID)[currency] ?? [:]
        var cells = Self.proportionalCells(expenseBalances(in: sharedListID)[currency] ?? [:])
        for settlement in settlements(in: sharedListID) where settlement.amount.currency == currency {
            Self.apply(settlement, to: &cells)
        }

        // Un pago que no cuadra con su fila —de más, a quien no le tocaba, o
        // uno viejo registrado con otro reparto— deja el plan sin sumar los
        // saldos. Se parcha **la diferencia**, no se rehace el plan: rehacerlo
        // movía filas que nadie tocó, que es justo lo que se quería evitar
        // (ADR-0054).
        Self.patch(&cells, toSettle: net)
        return Self.debts(from: cells, currency: currency)
    }

    /// Cómo se llegó al saldo de `participant`, movimiento por movimiento: lo
    /// que puso en cada gasto que pagó, lo que le tocó en cada gasto, y lo que
    /// pagó o recibió al liquidar. Los efectos suman exactamente su saldo en
    /// `netBalances` (ADR-0053).
    func balanceEntries(
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
        for settlement in settlements(in: sharedListID)
            where settlement.amount.currency == currency
            && (settlement.from == participant || settlement.to == participant) {
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
}

private extension PersonLedger {
    /// Lo que cada deudor le paga a cada acreedor, en proporción a lo que cobra
    /// cada uno. Cuadra al centavo por fila y por columna.
    static func proportionalCells(_ balances: [ParticipantID: Decimal]) -> [ParticipantID: [ParticipantID: Decimal]] {
        let creditors = balances.filter { $0.value > 0 }.keys.sorted()
        let debtors = balances.filter { $0.value < 0 }.keys.sorted()
        let totalCredit = creditors.reduce(Decimal(0)) { $0 + (balances[$1] ?? 0) }
        guard totalCredit > 0, !debtors.isEmpty else { return [:] }

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
            let order = remainders.sorted {
                $0.remainder == $1.remainder ? $0.creditor < $1.creditor : $0.remainder > $1.remainder
            }
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
        return cells
    }

    /// Descuenta una liquidación **solo de la fila de ese par**. Pagarle a
    /// alguien no puede mover lo que se le debe a un tercero: si el pago no
    /// cabe en su fila, la diferencia la resuelve `patch(_:toSettle:)`.
    static func apply(_ settlement: SettlementRecorded, to cells: inout [ParticipantID: [ParticipantID: Decimal]]) {
        let planned = cells[settlement.from]?[settlement.to] ?? 0
        guard planned > 0 else { return }
        cells[settlement.from]?[settlement.to, default: 0] = max(0, planned - settlement.amount.amount)
    }

    /// Suma al plan lo que le falte para saldar los saldos vigentes, sin tocar
    /// lo que ya tiene: reparte **la diferencia** con el mismo criterio
    /// proporcional y la mezcla. Las filas que ya estaban se quedan como
    /// están, incluidas las que un pago dejó en cero.
    static func patch(
        _ cells: inout [ParticipantID: [ParticipantID: Decimal]],
        toSettle balances: [ParticipantID: Decimal]) {
        var residual = balances
        for (debtor, row) in cells {
            for (creditor, amount) in row where amount > 0 {
                residual[debtor, default: 0] += amount
                residual[creditor, default: 0] -= amount
            }
        }
        guard residual.values.contains(where: { $0 != 0 }) else { return }

        for (debtor, row) in proportionalCells(residual) {
            for (creditor, amount) in row where amount > 0 {
                // Pagar de más deja una deuda al revés (quien cobraba ahora
                // debe): se netea contra la fila contraria en vez de mostrar
                // las dos.
                let opposite = min(cells[creditor]?[debtor] ?? 0, amount)
                if opposite > 0 {
                    cells[creditor]?[debtor, default: 0] -= opposite
                }
                cells[debtor, default: [:]][creditor, default: 0] += amount - opposite
            }
        }
    }

    static func debts(from cells: [ParticipantID: [ParticipantID: Decimal]], currency: Currency) -> [Debt] {
        cells.keys.sorted().flatMap { debtor in
            (cells[debtor] ?? [:]).keys.sorted().compactMap { creditor -> Debt? in
                guard let amount = cells[debtor]?[creditor], amount > 0 else { return nil }
                return Debt(from: debtor, to: creditor, amount: Money(amount: amount, currency: currency))
            }
        }
    }

    static var cent: Decimal {
        Decimal(string: "0.01") ?? 0
    }
}
