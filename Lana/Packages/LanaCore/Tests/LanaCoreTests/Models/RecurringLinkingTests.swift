import Foundation
import Testing
@testable import LanaCore

@Suite("Ligar a su recurrente lo registrado sin vínculo (ADR-0061)")
struct RecurringLinkingTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ month: Int, _ day: Int) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func expense(_ concept: String, _ amount: Decimal, month: Int = 9, day: Int) -> Expense {
        Expense(kind: .expense, amount: Money(amount: amount, currency: .mxn), concept: concept, date: date(month, day))
    }

    private func item(_ name: String, _ amount: Decimal, kind: Expense.Kind = .expense) throws -> RecurringItem {
        try RecurringItem(name: name, amount: Money(amount: amount, currency: .mxn), kind: kind, dayOfMonth: 26)
    }

    @Test("Mismo nombre, o nombre contenido con el mismo monto; si no, es una compra")
    func comoSeParece() throws {
        let netflix = try item("Netflix", 139)
        let icloud = try item("iCloud", 49)
        let suggestions = RecurringLinking.suggestions(
            for: [
                expense("netflix", 159, day: 26),
                expense("Pago iCloud", 49, day: 28),
                expense("Súper", 500, day: 29)
            ],
            recurringItems: [netflix, icloud],
            calendar: calendar)

        #expect(suggestions.map(\.item.name) == ["Netflix", "iCloud"])
        #expect(suggestions.map(\.expense.concept) == ["netflix", "Pago iCloud"])
    }

    @Test("Contener el nombre con otro monto no alcanza")
    func otroMontoNoAlcanza() throws {
        let suggestions = RecurringLinking.suggestions(
            for: [expense("iCloud+ anual", 900, day: 28)],
            recurringItems: [try item("iCloud", 49)],
            calendar: calendar)

        #expect(suggestions.isEmpty)
    }

    @Test("No se sugiere lo ligado, lo rechazado, lo por revisar ni un segundo del mismo mes")
    func loQueNoSeSugiere() throws {
        let netflix = try item("Netflix", 139)
        var linked = expense("Netflix", 139, month: 8, day: 26)
        linked.recurringItemID = netflix.id
        var declined = expense("Netflix", 139, month: 7, day: 26)
        declined.declinedRecurringItemIDs = [netflix.id]
        var pending = expense("Netflix", 139, month: 6, day: 26)
        pending.needsReview = true

        let suggestions = RecurringLinking.suggestions(
            for: [
                linked,
                expense("Netflix", 139, month: 8, day: 27),
                declined,
                pending,
                expense("Netflix", 139, month: 9, day: 26),
                expense("Netflix", 139, month: 9, day: 30)
            ],
            recurringItems: [netflix],
            calendar: calendar)

        #expect(suggestions.map(\.expense.date) == [date(9, 26)])
    }

    @Test("Un ingreso se liga a un recurrente de ingreso, no a uno de gasto")
    func ingresoConIngreso() throws {
        let sueldo = try item("Sueldo", 12000, kind: .income)
        let income = Expense(
            kind: .income,
            amount: Money(amount: 12000, currency: .mxn),
            concept: "sueldo",
            date: date(9, 15))
        let suggestions = RecurringLinking.suggestions(
            for: [income, expense("Sueldo", 12000, day: 16)],
            recurringItems: [sueldo],
            calendar: calendar)

        #expect(suggestions.map(\.expense.kind) == [.income])
    }

    @Test("Una corrección liga el movimiento y suma rechazos sin importar el orden")
    func laCorreccionLigaYRechaza() {
        let added = ExpenseAdded(
            amount: Money(amount: 139, currency: .mxn),
            concept: "Netflix",
            category: "suscripciones",
            date: date(9, 26),
            paymentMethod: .cash)
        let netflix = RecurringItemID()
        let other = RecurringItemID()
        let declines = ExpenseCorrected(
            correctsEventID: added.id,
            declinedRecurringItemIDs: [other],
            recordedAt: date(9, 27))
        let links = ExpenseCorrected(
            correctsEventID: added.id,
            amount: Money(amount: 139, currency: .mxn),
            recurringItemID: netflix,
            recordedAt: date(9, 28))
        // Una edición posterior que no trae recurrente no lo quita.
        let edit = ExpenseCorrected(correctsEventID: added.id, concept: "Netflix Premium", recordedAt: date(9, 29))

        let inOrder: [ExpenseEvent] = [
            .expenseAdded(added), .expenseCorrected(declines), .expenseCorrected(links), .expenseCorrected(edit)
        ]
        for events in [inOrder, inOrder.reversed()] {
            let projected = ExpenseProjection.expenses(from: events).first
            #expect(projected?.recurringItemID == netflix)
            #expect(projected?.declinedRecurringItemIDs == [other])
            #expect(projected?.concept == "Netflix Premium")
        }
    }
}
