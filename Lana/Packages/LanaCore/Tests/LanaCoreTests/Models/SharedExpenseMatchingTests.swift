import Foundation
import Testing
@testable import LanaCore

@Suite("SharedExpenseMatch.bestMatch")
struct SharedExpenseMatchingTests {
    let alice = Participant(displayName: "Alice")
    let bob = Participant(displayName: "Bob")

    func list(participants: [Participant], defaultSplit: SplitRule) -> SharedList {
        SharedList(name: "Depa", participants: participants, defaultSplit: defaultSplit)
    }

    @Test("payerHint vacío: nil, sin señal de gasto compartido")
    func payerHintVacioDevuelveNil() {
        let depa = list(participants: [alice, bob], defaultSplit: .payerOnly)
        let match = SharedExpenseMatch.bestMatch(payerHint: "", splitHint: nil, in: [depa], viewerIdentities: [:])
        #expect(match == nil)
    }

    @Test("Nombre que calza con un solo participante resuelve la lista y el pagador")
    func nombreCalzaConUnSoloParticipanteResuelve() {
        let depa = list(participants: [alice, bob], defaultSplit: .payerOnly)
        let match = SharedExpenseMatch.bestMatch(
            payerHint: "Alice", splitHint: nil, in: [depa], viewerIdentities: [:])
        #expect(match?.sharedListID == depa.id)
        #expect(match?.payer == alice.id)
    }

    @Test("Match ignora acentos y mayúsculas")
    func matchIgnoraAcentosYMayusculas() {
        let ana = Participant(displayName: "Ana María")
        let depa = list(participants: [ana, bob], defaultSplit: .payerOnly)
        let match = SharedExpenseMatch.bestMatch(
            payerHint: "ANA MARIA", splitHint: nil, in: [depa], viewerIdentities: [:])
        #expect(match?.payer == ana.id)
    }

    @Test("El mismo nombre en 2 listas distintas: ambiguo, nil")
    func mismoNombreEnDosListasEsAmbiguo() {
        let viaje = list(participants: [alice, Participant(displayName: "Carol")], defaultSplit: .payerOnly)
        let depa = list(participants: [alice, bob], defaultSplit: .payerOnly)
        let match = SharedExpenseMatch.bestMatch(
            payerHint: "Alice", splitHint: nil, in: [viaje, depa], viewerIdentities: [:])
        #expect(match == nil)
    }

    @Test("Ningún participante calza: nil, nunca adivina")
    func sinMatchDevuelveNil() {
        let depa = list(participants: [alice, bob], defaultSplit: .payerOnly)
        let match = SharedExpenseMatch.bestMatch(
            payerHint: "Zoe", splitHint: nil, in: [depa], viewerIdentities: [:])
        #expect(match == nil)
    }

    @Test("'yo' resuelve contra la identidad marcada en esa lista")
    func yoResuelveContraLaIdentidadMarcada() {
        let depa = list(participants: [alice, bob], defaultSplit: .payerOnly)
        let match = SharedExpenseMatch.bestMatch(
            payerHint: "yo", splitHint: nil, in: [depa], viewerIdentities: [depa.id: bob.id])
        #expect(match?.payer == bob.id)
    }

    @Test("'yo' sin identidad marcada en ninguna lista: nil")
    func yoSinIdentidadMarcadaDevuelveNil() {
        let depa = list(participants: [alice, bob], defaultSplit: .payerOnly)
        let match = SharedExpenseMatch.bestMatch(payerHint: "yo", splitHint: nil, in: [depa], viewerIdentities: [:])
        #expect(match == nil)
    }

    @Test("splitHint 'igual' resuelve a partes iguales entre todo el roster")
    func splitHintIgualResuelveAPartesIguales() {
        let depa = list(participants: [alice, bob], defaultSplit: .payerOnly)
        let match = SharedExpenseMatch.bestMatch(
            payerHint: "Alice", splitHint: "igual", in: [depa], viewerIdentities: [:])
        #expect(match?.split == .equally(among: [alice.id, bob.id]))
    }

    @Test("splitHint 'yo' resuelve a payerOnly")
    func splitHintYoResuelveAPayerOnly() {
        let depa = list(participants: [alice, bob], defaultSplit: .equally(among: [alice.id, bob.id]))
        let match = SharedExpenseMatch.bestMatch(
            payerHint: "Alice", splitHint: "yo", in: [depa], viewerIdentities: [:])
        #expect(match?.split == .payerOnly)
    }

    @Test("splitHint no reconocido o ausente cae al preferredSplit — sin ingresos, el default guardado")
    func splitHintNoReconocidoCaeAlPreferredSplit() {
        let depa = list(participants: [alice, bob], defaultSplit: .equally(among: [alice.id, bob.id]))
        let matchSinHint = SharedExpenseMatch.bestMatch(
            payerHint: "Alice", splitHint: nil, in: [depa], viewerIdentities: [:])
        let matchHintRaro = SharedExpenseMatch.bestMatch(
            payerHint: "Alice", splitHint: "60-40", in: [depa], viewerIdentities: [:])
        #expect(matchSinHint?.split == .equally(among: [alice.id, bob.id]))
        #expect(matchHintRaro?.split == .equally(among: [alice.id, bob.id]))
    }

    @Test("Lista de listas vacía: nil")
    func listaDeListasVaciaDevuelveNil() {
        let match = SharedExpenseMatch.bestMatch(payerHint: "Alice", splitHint: nil, in: [], viewerIdentities: [:])
        #expect(match == nil)
    }
}

@Suite("SplitRuleKind (ADR-0030)")
struct SplitRuleKindTests {
    let alice = Participant(displayName: "Alice", monthlyIncome: 30000)
    let bob = Participant(displayName: "Bob", monthlyIncome: 10000)

    func list(withIncomes: Bool) -> SharedList {
        let participants = withIncomes
            ? [alice, bob]
            : [Participant(displayName: "Alice"), Participant(displayName: "Bob")]
        return SharedList(
            name: "Depa",
            participants: participants,
            defaultSplit: .equally(among: participants.map(\.id)))
    }

    @Test("Con ingresos, proporcional es una opción ofrecible y resuelve sola")
    func conIngresosProporcionalEsOfrecible() throws {
        let depa = list(withIncomes: true)
        #expect(SplitRuleKind.resolvable(in: depa).contains(.proportional))

        let resolved = try #require(SplitRuleKind.proportional.resolve(in: depa))
        guard case .proportional = resolved else {
            Issue.record("Debería resolver a .proportional")
            return
        }
    }

    @Test("Sin ingresos, proporcional no se ofrece — no se puede resolver sin números")
    func sinIngresosProporcionalNoSeOfrece() {
        let depa = list(withIncomes: false)
        #expect(!SplitRuleKind.resolvable(in: depa).contains(.proportional))
        #expect(SplitRuleKind.proportional.resolve(in: depa) == nil)
    }

    @Test("Porcentaje y montos exactos nunca se ofrecen fuera del formulario completo")
    func porcentajeYMontosExactosNuncaSeOfrecen() {
        let offered = SplitRuleKind.resolvable(in: list(withIncomes: true))
        #expect(!offered.contains(.percentage))
        #expect(!offered.contains(.exactAmounts))
    }

    @Test("Proporcional va primero en el picker — es el default que se quiere")
    func proporcionalVaPrimero() {
        #expect(SplitRuleKind.allCases.first == .proportional)
        #expect(SplitRuleKind.resolvable(in: list(withIncomes: true)).first == .proportional)
    }
}

@Suite("SharedExpenseMatch — split por default (ADR-0030)")
struct SharedExpenseMatchSplitTests {
    let alice = Participant(displayName: "Alice", monthlyIncome: 30000)
    let bob = Participant(displayName: "Bob", monthlyIncome: 10000)

    @Test("Sin splitHint, una lista con ingresos divide proporcional — el bug reportado")
    func sinSplitHintConIngresosDivideProporcional() throws {
        // Antes caía a `defaultSplit`, que en una lista creada normalmente
        // es partes iguales — el proporcional nunca llegaba a la captura
        // por voz aunque la lista tuviera los ingresos.
        let depa = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let match = try #require(SharedExpenseMatch.bestMatch(
            payerHint: "Alice",
            splitHint: nil,
            in: [depa],
            viewerIdentities: [:]))

        guard case .proportional = match.split else {
            Issue.record("Debería haber caído en proporcional, cayó en \(match.split)")
            return
        }
    }

    @Test("Decir «mitad y mitad» sigue ganando sobre el proporcional de la lista")
    func decirMitadYMitadGanaSobreElProporcional() throws {
        let depa = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let match = try #require(SharedExpenseMatch.bestMatch(
            payerHint: "Alice",
            splitHint: "igual",
            in: [depa],
            viewerIdentities: [:]))

        #expect(match.split == .equally(among: [alice.id, bob.id]))
    }
}
