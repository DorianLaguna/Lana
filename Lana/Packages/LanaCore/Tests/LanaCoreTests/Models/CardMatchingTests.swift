import Foundation
import Testing
@testable import LanaCore

@Suite("Card.bestMatch")
struct CardMatchingTests {
    func nu() throws -> Card {
        try Card(alias: "Nu", lastFourDigits: "1234", limit: .zero(.mxn), cutoffDay: 20, dueDay: 5)
    }

    func bbva() throws -> Card {
        try Card(alias: "BBVA Azul", lastFourDigits: "5678", limit: .zero(.mxn), cutoffDay: 15, dueDay: 1)
    }

    @Test("Últimos 4 dígitos en el texto ganan sobre cualquier otra señal")
    func matchPorUltimosCuatro() throws {
        let nuCard = try nu()
        let match = try Card.bestMatch(for: "Tarjeta terminación 1234", in: [nuCard, bbva()])
        #expect(match?.id == nuCard.id)
    }

    @Test("Sin dígitos, el alias como substring resuelve")
    func matchPorAlias() throws {
        let bbvaCard = try bbva()
        let match = try Card.bestMatch(for: "BBVA Azul Crédito Mastercard", in: [nu(), bbvaCard])
        #expect(match?.id == bbvaCard.id)
    }

    @Test("Match de alias ignora acentos y mayúsculas")
    func matchDeAliasIgnoraAcentosYMayusculas() throws {
        let cafe = try Card(alias: "Café", lastFourDigits: "9999", limit: .zero(.mxn), cutoffDay: 1, dueDay: 10)
        let match = Card.bestMatch(for: "CAFE Credito", in: [cafe])
        #expect(match?.id == cafe.id)
    }

    @Test("Ningún dígito ni alias calza: nil, nunca adivina")
    func sinMatchDevuelveNil() throws {
        let match = try Card.bestMatch(for: "Amex Platino", in: [nu(), bbva()])
        #expect(match == nil)
    }

    @Test("Dos tarjetas comparten alias en el texto: ambiguo, nil")
    func aliasAmbiguoDevuelveNil() throws {
        let nuDebito = try Card(
            alias: "Nu Débito",
            lastFourDigits: "4321",
            limit: nil,
            cutoffDay: nil,
            dueDay: nil,
            kind: .debit)
        let match = try Card.bestMatch(for: "Nu Débito Mastercard", in: [nu(), nuDebito])
        #expect(match == nil)
    }

    @Test("Lista de tarjetas vacía: nil")
    func listaVaciaDevuelveNil() {
        #expect(Card.bestMatch(for: "cualquier cosa", in: []) == nil)
    }
}
