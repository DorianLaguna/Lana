import Foundation
import Testing
@testable import LanaCore

@Suite("Hallazgos: lo que no sabías, calculado")
struct FindingsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    private func expense(
        _ amount: Decimal,
        concept: String = "algo",
        category: String = "despensa",
        subcategory: String? = nil,
        on date: Date,
        recurringItemID: RecurringItemID? = nil) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: concept,
            category: category,
            subcategory: subcategory,
            date: date,
            recurringItemID: recurringItemID)
    }

    private func resolve(_ expenses: [Expense], month: Date, asOf: Date) -> [Finding] {
        Findings.resolve(
            Findings.Input(month: month, currency: .mxn, expenses: expenses, asOf: asOf),
            calendar: calendar)
    }

    // MARK: - Cómo vas

    @Test("Compara contra el mismo día del mes pasado, no contra el mes completo")
    func elRitmoComparaElMismoDia() throws {
        let expenses = try [
            // Mes pasado: 700 hasta el día 15, y 5,000 más después.
            expense(700, on: date(2026, 8, 10)),
            expense(5000, on: date(2026, 8, 25)),
            expense(1900, on: date(2026, 9, 10))
        ]

        let findings = try resolve(expenses, month: date(2026, 9, 1), asOf: date(2026, 9, 15))
        let pace = try #require(findings.first { $0.kind == .pace })

        // El día de la frase es el de hoy, no el del gasto: lo que compara el
        // hallazgo es "hasta el mismo día del mes".
        #expect(pace.headline == "Vas $1,200.00 arriba de como ibas el 15 de agosto")
        #expect(pace.detail == "Hasta hoy llevas $1,900.00; a estas alturas del mes pasado, $700.00.")
    }

    @Test("Sin mes anterior con qué comparar, no se inventa un ritmo")
    func sinMesAnteriorNoHayRitmo() throws {
        let findings = try resolve(
            [expense(1900, on: date(2026, 9, 10))],
            month: date(2026, 9, 1),
            asOf: date(2026, 9, 15))

        #expect(!findings.contains { $0.kind == .pace })
    }

    // MARK: - Cobros que se repiten

    @Test("Un cobro mensual de monto parecido se detecta")
    func elCobroMensualSeDetecta() throws {
        let expenses = try [
            expense(199, concept: "Netflix", category: "ocio", on: date(2026, 7, 5)),
            expense(199, concept: "netflix", category: "ocio", on: date(2026, 8, 5)),
            expense(219, concept: "Netflix", category: "ocio", on: date(2026, 9, 5))
        ]

        let findings = try resolve(expenses, month: date(2026, 9, 1), asOf: date(2026, 9, 20))
        let repeated = try #require(findings.first { $0.kind == .repeatedCharges })

        // El monto que se toma es el más reciente: si subió de precio, lo que
        // importa es lo que cuesta ahora.
        #expect(repeated.headline == "Un cobro se repite cada mes: $219.00")
    }

    @Test("Lo que ya está dado de alta como recurrente no se propone otra vez")
    func loYaRecurrenteNoSePropone() throws {
        let renta = RecurringItemID()
        let expenses = try [
            expense(9000, concept: "Renta", category: "hogar", on: date(2026, 7, 1), recurringItemID: renta),
            expense(9000, concept: "Renta", category: "hogar", on: date(2026, 8, 1), recurringItemID: renta),
            expense(9000, concept: "Renta", category: "hogar", on: date(2026, 9, 1), recurringItemID: renta)
        ]

        let findings = try resolve(expenses, month: date(2026, 9, 1), asOf: date(2026, 9, 20))

        #expect(!findings.contains { $0.kind == .repeatedCharges })
    }

    @Test("Un café diario no es un cobro que se repite: se pide una vez por mes")
    func elCafeDiarioNoEsUnCobro() throws {
        let expenses = try (1 ... 12).map { day in
            try expense(50, concept: "café", category: "comida", on: date(2026, 9, day))
        }

        let findings = try resolve(expenses, month: date(2026, 9, 1), asOf: date(2026, 9, 20))

        #expect(!findings.contains { $0.kind == .repeatedCharges })
    }

    // MARK: - Desvío contra el propio promedio

    @Test("Una categoría que se sale de su promedio se reporta con el promedio al lado")
    func elDesvioContraElPromedio() throws {
        let expenses = try [
            expense(1000, category: "despensa", on: date(2026, 7, 5)),
            expense(1000, category: "despensa", on: date(2026, 8, 5)),
            expense(1800, category: "despensa", on: date(2026, 9, 5))
        ]

        let findings = try resolve(expenses, month: date(2026, 9, 1), asOf: date(2026, 9, 20))
        let deviation = try #require(findings.first { $0.kind == .categoryDeviation })

        #expect(deviation.headline == "Despensa: $800.00 arriba de tu promedio")
        #expect(deviation.detail == "Tu promedio de los últimos 2 meses es $1,000.00.")
    }

    @Test("Gastar menos que tu promedio no es un hallazgo: no hay nada que hacer con eso")
    func gastarMenosNoEsHallazgo() throws {
        let expenses = try [
            expense(2000, category: "despensa", on: date(2026, 7, 5)),
            expense(2000, category: "despensa", on: date(2026, 8, 5)),
            expense(500, category: "despensa", on: date(2026, 9, 5))
        ]

        let findings = try resolve(expenses, month: date(2026, 9, 1), asOf: date(2026, 9, 20))

        #expect(!findings.contains { $0.kind == .categoryDeviation })
    }

    // MARK: - Orden y silencio

    @Test("Se ordenan por el dinero que mueven, no por cómo se calcularon")
    func seOrdenanPorDinero() throws {
        let expenses = try [
            expense(1000, category: "despensa", on: date(2026, 7, 5)),
            expense(1000, category: "despensa", on: date(2026, 8, 5)),
            expense(9000, category: "despensa", on: date(2026, 9, 5))
        ]

        let findings = try resolve(expenses, month: date(2026, 9, 1), asOf: date(2026, 9, 20))

        #expect(findings.count >= 2)
        let magnitudes = findings.map(\.magnitude)
        #expect(magnitudes == magnitudes.sorted(by: >))
    }

    @Test("Sin historial no se dice nada, en vez de decir algo flojo")
    func sinHistorialNoSeDiceNada() throws {
        #expect(try resolve([], month: date(2026, 9, 1), asOf: date(2026, 9, 15)).isEmpty)
    }
}
