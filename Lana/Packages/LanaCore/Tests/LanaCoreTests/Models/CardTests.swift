import Foundation
import Testing
@testable import LanaCore

@Suite("Card")
struct CardTests {
    @Test("Últimos cuatro dígitos inválidos truena")
    func ultimosCuatroInvalidoTruena() {
        #expect(throws: CardError.self) {
            _ = try Card(alias: "Nu", lastFourDigits: "12a4", limit: .zero(.mxn), cutoffDay: 20, dueDay: 5)
        }
        #expect(throws: CardError.self) {
            _ = try Card(alias: "Nu", lastFourDigits: "123", limit: .zero(.mxn), cutoffDay: 20, dueDay: 5)
        }
    }

    @Test("Día de corte fuera de 1-31 truena")
    func diaDeCorteInvalidoTruena() {
        #expect(throws: CardError.self) {
            _ = try Card(alias: "Nu", lastFourDigits: "1234", limit: .zero(.mxn), cutoffDay: 32, dueDay: 5)
        }
    }

    @Test("Una tarjeta válida se crea sin problema")
    func tarjetaValida() throws {
        let card = try Card(
            alias: "Nu",
            lastFourDigits: "1234",
            limit: Money(amount: 5000, currency: .mxn),
            cutoffDay: 20,
            dueDay: 5)
        #expect(card.alias == "Nu")
        #expect(card.lastFourDigits == "1234")
    }

    @Test("Sin especificar, una tarjeta es de crédito por default")
    func porDefaultEsDeCredito() throws {
        let card = try Card(alias: "Nu", lastFourDigits: "1234", limit: .zero(.mxn), cutoffDay: 20, dueDay: 5)
        #expect(card.kind == .credit)
    }

    @Test("El tipo y el color se guardan tal cual se dieron de alta")
    func elTipoYElColorSeGuardan() throws {
        let card = try Card(
            alias: "Nu débito",
            lastFourDigits: "1234",
            limit: .zero(.mxn),
            cutoffDay: 20,
            dueDay: 5,
            kind: .debit,
            colorHex: "#6C4FB3")
        #expect(card.kind == .debit)
        #expect(card.colorHex == "#6C4FB3")
    }

    @Test("Los últimos 4 dígitos no son obligatorios")
    func ultimosCuatroDigitosNoSonObligatorios() throws {
        let card = try Card(
            alias: "Nu",
            lastFourDigits: "",
            limit: Money(amount: 5000, currency: .mxn),
            cutoffDay: 20,
            dueDay: 5)
        #expect(card.lastFourDigits == nil)
    }

    @Test("Espacios en blanco cuentan como no capturados, no como inválidos")
    func espaciosEnBlancoCuentanComoNoCapturados() throws {
        let card = try Card(
            alias: "Nu",
            lastFourDigits: "   ",
            limit: Money(amount: 5000, currency: .mxn),
            cutoffDay: 20,
            dueDay: 5)
        #expect(card.lastFourDigits == nil)
    }

    @Test("Un débito nunca guarda límite, corte ni fecha límite de pago — no existen en la realidad")
    func unDebitoNuncaGuardaLimiteNiFechas() throws {
        let card = try Card(
            alias: "Nu débito",
            lastFourDigits: "1234",
            limit: Money(amount: 5000, currency: .mxn),
            cutoffDay: 20,
            dueDay: 5,
            kind: .debit)
        #expect(card.limit == nil)
        #expect(card.cutoffDay == nil)
        #expect(card.dueDay == nil)
    }

    @Test("Un crédito sin límite truena")
    func unCreditoSinLimiteTruena() {
        #expect(throws: CardError.self) {
            _ = try Card(alias: "Nu", lastFourDigits: "1234", limit: nil, cutoffDay: 20, dueDay: 5)
        }
    }

    @Test("Un crédito sin día de corte truena")
    func unCreditoSinDiaDeCorteTruena() {
        #expect(throws: CardError.self) {
            _ = try Card(alias: "Nu", lastFourDigits: "1234", limit: .zero(.mxn), cutoffDay: nil, dueDay: 5)
        }
    }
}
