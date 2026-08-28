import LanaCore
import Testing
@testable import LanaParsing

@Suite("FoundationModelsExpenseParsing.paymentMethodHint")
struct PaymentMethodHintTests {
    @Test("Reconoce los términos del @Guide, con o sin acento", arguments: [
        ("efectivo", PaymentMethodHint.cash),
        ("Efectivo", .cash),
        ("débito", .debit),
        ("debito", .debit),
        ("crédito", .credit),
        ("credito", .credit),
        ("transferencia", .transfer)
    ])
    func reconoceLosTerminos(raw: String, expected: PaymentMethodHint) {
        #expect(FoundationModelsExpenseParsing.paymentMethodHint(from: raw) == expected)
    }

    @Test("Vacío o texto no reconocido es 'no mencionado', no un error")
    func vacioONoReconocidoEsNil() {
        #expect(FoundationModelsExpenseParsing.paymentMethodHint(from: "") == nil)
        #expect(FoundationModelsExpenseParsing.paymentMethodHint(from: "quién sabe") == nil)
    }
}
