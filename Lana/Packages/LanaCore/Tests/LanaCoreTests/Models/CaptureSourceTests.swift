import Foundation
import Testing
@testable import LanaCore

/// El origen de un movimiento viaja en el payload JSON del evento raíz
/// (ADR-0049). Lo registrado antes no lo trae y tiene que seguir leyéndose.
@Suite("CaptureSource — origen de un movimiento (ADR-0049)")
struct CaptureSourceTests {
    private let date = Date(timeIntervalSince1970: 780_000_000)

    private func expenseAdded(source: CaptureSource?) -> ExpenseAdded {
        ExpenseAdded(
            amount: Money(amount: 89, currency: .mxn),
            concept: "OXXO",
            category: "comida",
            date: date,
            paymentMethod: .cash,
            source: source,
            needsReview: true)
    }

    @Test("Un gasto guardado antes de que existiera el origen decodifica sin él")
    func gastoViejoDecodificaSinOrigen() throws {
        let encoded = try JSONEncoder().encode(expenseAdded(source: .applePay))
        var json = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(json.removeValue(forKey: "source") != nil)
        let legacy = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ExpenseAdded.self, from: legacy)

        #expect(decoded.concept == "OXXO")
        #expect(decoded.source == nil)
        #expect(ExpenseProjection.expenses(from: [.expenseAdded(decoded)]).first?.source == nil)
    }

    @Test("Confirmar un pago de Apple Pay no le cambia el origen")
    func corregirConservaElOrigen() {
        let added = expenseAdded(source: .applePay)
        let confirmation = ExpenseCorrected(
            correctsEventID: added.id,
            concept: "OXXO Reforma",
            needsReview: false)

        let expense = ExpenseProjection.expenses(from: [.expenseAdded(added), .expenseCorrected(confirmation)]).first

        #expect(expense?.needsReview == false)
        #expect(expense?.source == .applePay)
    }

    @Test("Un ingreso conserva su origen al ir y volver del JSON")
    func ingresoConservaElOrigen() throws {
        let income = IncomeAdded(
            amount: Money(amount: 18000, currency: .mxn),
            concept: "quincena",
            date: date,
            source: .recurring)

        let decoded = try JSONDecoder().decode(IncomeAdded.self, from: JSONEncoder().encode(income))

        #expect(ExpenseProjection.expenses(from: [.incomeAdded(decoded)]).first?.source == .recurring)
    }
}
