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
        isShared: Bool = false,
        payerHint: String = "",
        splitHint: String = "",
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
            isShared: isShared,
            payerHint: payerHint,
            splitHint: splitHint,
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

    @Test("""
    En un lote, una tarjeta mencionada solo en una transacción no se le pega a las \
    demás — el bug reportado: "pica fresa 2, iPhone 703.96, PPR 2592 con Banamex" \
    dejaba las tres con Banamex en vez de solo la última
    """)
    func tarjetaDeUnaTransaccionNoContaminaElLote() {
        let batch = ParsedTransactionBatch(transactions: [
            transaction(amount: 2, concept: "pica fresa", cardHint: "Banamex"),
            transaction(amount: 703.96, concept: "iPhone", cardHint: "Banamex"),
            transaction(amount: 2592, concept: "PPR", cardHint: "Banamex")
        ])
        let result = ParsingPipeline.process(batch, rawText: "pica fresa 2, iPhone 703.96, PPR 2592 con Banamex")

        #expect(result.transactions.count == 3)
        #expect(result.transactions[0].transaction.cardHint.isEmpty == true)
        #expect(result.transactions[1].transaction.cardHint.isEmpty == true)
        #expect(result.transactions[2].transaction.cardHint == "Banamex")
    }

    @Test("En un lote con montos repetidos, cada cláusula se reclama en orden, sin duplicarse")
    func montosRepetidosEnLoteSeReclamanEnOrden() {
        let batch = ParsedTransactionBatch(transactions: [
            transaction(amount: 50, concept: "café", cardHint: "Bancomer"),
            transaction(amount: 50, concept: "agua", cardHint: "Bancomer")
        ])
        let result = ParsingPipeline.process(batch, rawText: "café 50, agua 50 con Bancomer")

        #expect(result.transactions.count == 2)
        #expect(result.transactions[0].transaction.cardHint.isEmpty == true)
        #expect(result.transactions[1].transaction.cardHint == "Bancomer")
    }

    /// La coma de miles NO parte cláusula: si lo hiciera, "renta 1,200"
    /// quedaría como "renta 1" y "200 con Banamex", ninguna con el monto
    /// 1200, y el alcance caería al texto completo — donde "Banamex" sí
    /// aparece, reintroduciendo la contaminación de tarjeta entre gastos.
    @Test("Un monto con separador de miles no parte la cláusula en dos")
    func separadorDeMilesNoParteLaClausula() {
        let batch = ParsedTransactionBatch(transactions: [
            transaction(amount: 1200, concept: "renta", cardHint: "Banamex"),
            transaction(amount: 45, concept: "café", cardHint: "Banamex")
        ])
        let result = ParsingPipeline.process(batch, rawText: "renta 1,200 con Banamex, café 45")

        #expect(result.transactions.count == 2)
        #expect(result.transactions[0].transaction.cardHint == "Banamex")
        #expect(result.transactions[1].transaction.cardHint.isEmpty == true)
    }

    @Test("Decir solo quién pagó NUNCA es un gasto compartido — el bug reportado (ADR-0027)")
    func decirQuienPagoNoEsCompartido() {
        // Exactamente lo que el modelo hacía en producción: llenar `isShared`
        // y `payerHint: "yo"` en un "pagué X" cualquiera. Sin vocabulario de
        // compartir en el texto crudo, la guardia determinista lo anula —
        // antes de esto, todos los gastos personales acababan en la lista
        // compartida.
        let batch = ParsedTransactionBatch(transactions: [
            transaction(amount: 300, isShared: true, payerHint: "yo", splitHint: "igual")
        ])
        let result = ParsingPipeline.process(batch, rawText: "pagué 300 de gasolina")

        #expect(result.transactions.first?.transaction.isShared == false)
        #expect(result.transactions.first?.transaction.payerHint.isEmpty == true)
        #expect(result.transactions.first?.transaction.splitHint.isEmpty == true)
    }

    @Test("Con vocabulario de compartir en el texto, isShared y sus hints sobreviven")
    func conVocabularioDeCompartirSobrevive() {
        let batch = ParsedTransactionBatch(transactions: [
            transaction(amount: 300, isShared: true, payerHint: "Ana", splitHint: "igual")
        ])
        let result = ParsingPipeline.process(batch, rawText: "300 de gasolina, lo dividimos con Ana")

        #expect(result.transactions.first?.transaction.isShared == true)
        #expect(result.transactions.first?.transaction.payerHint == "Ana")
        #expect(result.transactions.first?.transaction.splitHint == "igual")
    }

    @Test("Varias formas de decir 'compartido' se reconocen", arguments: [
        "cena 300, la dividimos",
        "cena 300 a medias con Ana",
        "cena 300, mitad y mitad",
        "cena 300 entre los dos",
        "cena 300, es compartido",
        "cena 300, cada quien puso la mitad"
    ])
    func variasFormasDeDecirCompartido(rawText: String) {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: 300, isShared: true, payerHint: "yo")])
        let result = ParsingPipeline.process(batch, rawText: rawText)
        #expect(result.transactions.first?.transaction.isShared == true)
    }

    @Test("Un payerHint inventado se descarta aunque el texto sí hable de compartir")
    func unPayerHintInventadoSeDescarta() {
        let batch = ParsedTransactionBatch(transactions: [
            transaction(amount: 300, isShared: true, payerHint: "Ana")
        ])
        let result = ParsingPipeline.process(batch, rawText: "300 de gasolina, lo dividimos")
        #expect(result.transactions.first?.transaction.isShared == true)
        #expect(result.transactions.first?.transaction.payerHint.isEmpty == true)
    }

    @Test("'yo' como payerHint sobrevive sin aparecer literal, si el gasto sí es compartido")
    func payerHintYoSobreviveSiEsCompartido() {
        let batch = ParsedTransactionBatch(transactions: [transaction(amount: 300, isShared: true, payerHint: "yo")])
        let result = ParsingPipeline.process(batch, rawText: "300 de gasolina, lo dividimos")
        #expect(result.transactions.first?.transaction.payerHint == "yo")
    }
}
