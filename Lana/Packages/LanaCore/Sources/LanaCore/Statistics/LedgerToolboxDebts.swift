import Foundation

/// Las herramientas de deuda: con personas y con los bancos.
///
/// Viven aparte de `LedgerToolbox.swift` para que ese archivo no rebase el
/// tamaño máximo (`swiftlint`, `type_body_length`), y la línea de corte no es
/// arbitraria: **estas dos son las que nunca se suman entre sí**
/// (Docs/CLAUDE.md). Tenerlas juntas y separadas del resto deja esa regla a la
/// vista de quien venga a tocarlas.
public extension LedgerToolbox {
    // MARK: - Deudas

    /// Quién le debe a quién en una lista compartida.
    func saldoDeLista(name: String) async -> String {
        guard let lists = try? await sharedListStore.lists(), !lists.isEmpty else {
            return "No hay listas compartidas."
        }
        let normalized = Self.normalize(name)
        guard let list = lists.first(where: { Self.normalize($0.name) == normalized })
            ?? lists.first(where: { Self.normalize($0.name).contains(normalized) })
        else {
            let names = lists.map(\.name).joined(separator: ", ")
            return "No hay una lista que se llame \"\(name)\". Las que existen son: \(names)."
        }

        guard let events = try? await sharedListStore.events() else {
            return "No se pudieron leer los movimientos de la lista."
        }
        let ledger = PersonLedger(events: events)
        let balances = ledger.netBalances(in: list.id)
        guard !balances.isEmpty else {
            return "En \"\(list.name)\" no hay saldos pendientes."
        }

        let names = Dictionary(uniqueKeysWithValues: list.participants.map { ($0.id, $0.displayName) })
        let lines = balances.keys.sorted { $0.rawValue < $1.rawValue }.flatMap { currency in
            ledger.simplifiedDebts(in: list.id, currency: currency).map { debt in
                let from = names[debt.from] ?? "alguien"
                let to = names[debt.to] ?? "alguien"
                return "  \(from) le debe \(debt.amount.formatted()) a \(to)"
            }
        }
        guard !lines.isEmpty else {
            return "En \"\(list.name)\" están a mano: nadie le debe nada a nadie."
        }
        return "En \"\(list.name)\":\n\(lines.joined(separator: "\n"))"
    }

    /// Cuánto se debe en cada tarjeta de crédito.
    ///
    /// - Important: es la deuda con el banco, y **nunca se suma** con la deuda
    ///   entre personas (`saldoDeLista`): son dos ledgers separados y juntarlos
    ///   daría un número sin significado (Docs/CLAUDE.md).
    func deudaPorTarjeta(asOf date: Date = Date()) async -> String {
        guard let cards = try? await cardStore.cards() else {
            return "No se pudieron leer las tarjetas."
        }
        let credit = cards.filter { $0.cutoffDay != nil }
        guard !credit.isEmpty else {
            return "No hay tarjetas de crédito registradas."
        }
        guard let events = try? await cardPaymentStore.events() else {
            return "No se pudieron leer los movimientos de las tarjetas."
        }

        let ledger = CardLedger(events: events)
        let lines = credit.map { card in
            let statement = ledger.outstandingStatementBalance(for: card, asOf: date, calendar: calendar)
            let cycle = ledger.currentCycleBalance(for: card, asOf: date, calendar: calendar)
            return """
              \(card.alias): \(statement.formatted()) ya facturado y pendiente, \
            más \(cycle.formatted()) acumulado en el ciclo abierto
            """
        }
        return "Deuda por tarjeta:\n\(lines.joined(separator: "\n"))"
    }

    /// Los movimientos de los meses completos que toca el periodo, no solo
    /// los del periodo — ver `PayPeriod.commitments(from:registeredIn:asOf:calendar:)`.
    private func expensesInFullMonths(of period: PayPeriod) async -> [Expense]? {
        guard let firstMonth = calendar.dateInterval(of: .month, for: period.start),
              let lastMonth = calendar.dateInterval(of: .month, for: period.end) else { return nil }
        return try? await store.expenses(in: DateInterval(start: firstMonth.start, end: lastMonth.end))
    }

    /// Cuánto queda del periodo de pago vigente.
    ///
    /// El saldo no viene del banco —Lana no lo conoce— sino de lo registrado
    /// desde el último sueldo, más los compromisos con fecha que faltan
    /// (ADR-0008). La respuesta **siempre** incluye de qué está hecha la cifra:
    /// sin esa línea, un usuario nuevo la leería como el saldo de su cuenta.
    func disponibleProyectado(asOf date: Date = Date()) async -> String {
        guard let recurringItemStore else {
            return "Todavía no puedo calcular eso."
        }
        let items = await (try? recurringItemStore.items()) ?? []
        let period = PayPeriod.current(for: date, recurringItems: items, calendar: calendar)

        guard let expenses = try? await store.expenses(in: DateInterval(start: period.start, end: period.through))
        else { return "No se pudieron leer los movimientos." }
        let identities = await sharedListStore.viewerIdentities(for: expenses)

        guard let registrations = await expensesInFullMonths(of: period)
        else { return "No se pudieron leer los movimientos." }

        var upcoming = period.commitments(from: items, registeredIn: registrations, asOf: date, calendar: calendar)
        if let cards = try? await cardStore.cards(), let events = try? await cardPaymentStore.events() {
            upcoming += period.cardCommitments(
                cards: cards,
                ledger: CardLedger(events: events),
                asOf: date,
                calendar: calendar)
        }

        // Una proyección por moneda; nunca una que las cruce.
        let currencies = Set(expenses.map(\.amount.currency)).union(upcoming.map(\.amount.currency))
        guard !currencies.isEmpty else {
            return """
            No hay nada registrado en este periodo, así que no hay de dónde \
            sacar el disponible. \(period.explanationFallback)
            """
        }

        let blocks = currencies.sorted { $0.rawValue < $1.rawValue }.map { currency -> String in
            let projection = AvailableProjection(
                period: period,
                currency: currency,
                expenses: expenses,
                viewerIdentities: identities,
                upcoming: upcoming,
                asOf: date)
            let pending = projection.upcoming
                .map { "  \($0.concept): \($0.amount.formatted())" }
                .joined(separator: "\n")
            let pendingBlock = pending.isEmpty ? "No falta ningún pago con fecha." : "Falta por pagar:\n\(pending)"
            return """
            En \(currency.rawValue), del \(Self.day(period.start)) al \(Self.day(period.through)):
            Entró \(Money(amount: projection.received, currency: currency).formatted()) y \
            salió \(Money(amount: projection.spent, currency: currency).formatted()), \
            así que ahora traes \(projection.balance.formatted()).
            \(pendingBlock)
            Disponible al final del periodo: \(projection.available.formatted()).
            \(projection.explanation)
            """
        }
        return blocks.joined(separator: "\n\n")
    }
}
