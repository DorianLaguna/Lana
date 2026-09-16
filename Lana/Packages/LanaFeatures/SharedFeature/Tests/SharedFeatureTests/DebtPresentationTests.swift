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

    @Test("Primero lo que te deben, luego lo que debes, luego lo de los demás")
    func ordenaPorQuienMira() {
        let others = debt(kin, iori, 500)
        let owedToMe = debt(evan, yo, 20)
        let iOwe = debt(yo, iori, 100)
        let owedToMeMore = debt(kin, yo, 90)

        let ordered = orderedDebts([others, owedToMe, iOwe, owedToMeMore], viewer: yo)

        #expect(ordered.map(\.amount.amount) == [90, 20, 100, 500])
    }
}
