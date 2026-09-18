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

    @Test("Solo lo que te toca a ti: lo de terceros entre sí no se muestra")
    func soloLoQueTeToca() {
        let mine = myDebts([
            debt(kin, iori, 60),
            debt(evan, yo, 5),
            debt(kin, yo, 50),
            debt(yo, iori, 10)
        ], viewer: yo)

        #expect(mine.owedToMe.map(\.amount.amount) == [50, 5])
        #expect(mine.iOwe.map(\.amount.amount) == [10])
    }

    @Test("Sin saber quién eres en la lista, no se muestra ninguna")
    func sinViewerNoHayFilas() {
        let mine = myDebts([debt(kin, iori, 60)], viewer: nil)

        #expect(mine.owedToMe.isEmpty)
        #expect(mine.iOwe.isEmpty)
    }
}
