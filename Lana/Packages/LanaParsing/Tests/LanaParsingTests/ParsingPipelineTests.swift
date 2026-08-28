import Foundation
import Testing
@testable import LanaParsing

@Suite("ParsingPipeline")
struct ParsingPipelineTests {
    private func transaction(
        isIncome: Bool = false,
        amount: Double,
        currencyCode: String = "MXN",
        concept: String = "algo",
        category: ExpenseCategory = .otro,
        subcategory: String = "",
        cardHint: String = "",
        needsReview: Bool = false) -> ParsedTransaction {
        ParsedTransaction(
            isIncome: isIncome,
            amount: amount,
            currencyCode: currencyCode,
            concept: concept,
            category: category,
            subcategory: subcategory,
            paymentMethodHint: "",
            cardHint: cardHint,
            needsReview: needsReview)
    }

    @Test("Un gasto de monto 0 se descarta")
    func gastoDeMontoCeroSeDescarta() {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: 0)])
        let result = ParsingPipeline.process(batch, rawText: "algo gratis")
        #expect(result.transactions.isEmpty)
    }

    @Test("Un gasto de monto negativo se descarta")
    func gastoDeMontoNegativoSeDescarta() {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: -50)])
        let result = ParsingPipeline.process(batch, rawText: "algo raro")
        #expect(result.transactions.isEmpty)
    }

    @Test("El monto del regex gana y marca needsReview cuando el modelo se equivoca")
    func regexGanaYMarcaNeedsReview() {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: 45000)])
        let result = ParsingPipeline.process(batch, rawText: "45 de estacionamiento")
        #expect(result.transactions.count == 1)
        #expect(result.transactions.first?.validatedAmount == 45)
        #expect(result.transactions.first?.needsReview == true)
    }

    @Test("Un número no reclamado por ningún gasto queda como unclaimed, sin marcar needsReview")
    func numeroNoReclamadoQuedaComoUnclaimed() {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: 380)])
        let result = ParsingPipeline.process(batch, rawText: "2 boletos, 380 pesos")

        #expect(result.transactions.count == 1)
        #expect(result.transactions.first?.needsReview == false)
        #expect(result.unclaimedAmounts == [2])
    }

    @Test("needsReview del modelo se conserva aunque el monto sea válido")
    func needsReviewDelModeloSeConserva() {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: 100, needsReview: true)])
        let result = ParsingPipeline.process(batch, rawText: "100 de algo ambiguo")
        #expect(result.transactions.first?.needsReview == true)
    }

    @Test("Una tarjeta que el modelo inventó, sin mención en el texto, se descarta — el bug reportado")
    func unaTarjetaInventadaSeDescarta() {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: 300, cardHint: "Banamex")])
        let result = ParsingPipeline.process(batch, rawText: "300 de gasolina")
        #expect(result.transactions.first?.transaction.cardHint.isEmpty == true)
    }

    @Test("Una tarjeta que sí aparece en el texto se conserva")
    func unaTarjetaMencionadaSeConserva() {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: 300, cardHint: "Banamex")])
        let result = ParsingPipeline.process(batch, rawText: "300 de gasolina con la Banamex")
        #expect(result.transactions.first?.transaction.cardHint == "Banamex")
    }
}
