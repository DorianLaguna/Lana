import Foundation
import LanaCore
import Testing
@testable import SharedFeature

@Suite("Cómo se lee quién le debe a quién")
struct DebtPresentationTests {
    private let yo = ParticipantID()
    private let evan = ParticipantID()
    private let iori = ParticipantID()
    private let kin = ParticipantID()

    private func name(_ id: ParticipantID) -> String {
        switch id {
        case yo: "Yo"
        case evan: "Evan"
        case iori: "Iori"
        default: "Kin"
        }
    }

    private func debt(_ from: ParticipantID, _ to: ParticipantID, _ amount: Decimal) -> Debt {
        Debt(from: from, to: to, amount: Money(amount: amount, currency: .mxn))
    }

    @Test("Habla de tú cuando quien mira está en la deuda")
    func hablaDeTu() {
        #expect(debtPhrase(debt(evan, yo, 10), viewer: yo, name: name) == "Evan te debe")
        #expect(debtPhrase(debt(yo, iori, 10), viewer: yo, name: name) == "Le debes a Iori")
        #expect(debtPhrase(debt(kin, iori, 10), viewer: yo, name: name) == "Kin le debe a Iori")
        #expect(balanceLabel(isOwed: true, isViewer: true) == "te deben")
        #expect(balanceLabel(isOwed: false, isViewer: false) == "debe")
    }

    @Test("Agrupa por quien debe: tú primero, luego de mayor a menor, y a ti primero dentro de cada grupo")
    func agrupaPorDeudor() {
        let groups = debtGroups([
            debt(kin, iori, 60),
            debt(evan, iori, 70),
            debt(kin, yo, 50),
            debt(yo, iori, 10),
            debt(evan, yo, 5)
        ], viewer: yo)

        #expect(groups.map(\.debtor) == [yo, kin, evan])
        #expect(groups.map(\.total.amount) == [10, 110, 75])
        #expect(groups[1].debts.map(\.to) == [yo, iori])
        #expect(groups[2].debts.map(\.to) == [yo, iori])
    }
}
