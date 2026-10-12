import Foundation
import Testing
@testable import LanaCore

@Suite("Moverse entre ciclos de corte")
struct StatementCycleTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .current
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    private func startOfDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: date(year, month, day))
    }

    @Test("El ciclo anterior termina donde empieza el actual")
    func elAnteriorTerminaDondeEmpiezaElActual() {
        let actual = StatementCycle.containing(date(2026, 10, 5), cutoffDay: 12, calendar: calendar)
        let anterior = actual.previous(cutoffDay: 12, calendar: calendar)

        #expect(anterior.end == actual.start)
    }

    @Test("El ciclo anterior empieza en el corte de dos meses atrás")
    func elAnteriorEmpiezaDosCortesAtras() {
        let actual = StatementCycle.containing(date(2026, 10, 5), cutoffDay: 12, calendar: calendar)
        let anterior = actual.previous(cutoffDay: 12, calendar: calendar)

        #expect(anterior.start == startOfDay(2026, 8, 12))
    }

    @Test("El ciclo siguiente empieza donde termina el actual")
    func elSiguienteEmpiezaDondeTerminaElActual() {
        let actual = StatementCycle.containing(date(2026, 10, 5), cutoffDay: 12, calendar: calendar)
        let siguiente = actual.next(cutoffDay: 12, calendar: calendar)

        #expect(siguiente.start == actual.end)
    }

    @Test("Con corte 31, el ciclo siguiente a enero cierra el 28 de febrero")
    func corte31EnFebrero() {
        let enero = StatementCycle.containing(date(2026, 1, 15), cutoffDay: 31, calendar: calendar)
        let febrero = enero.next(cutoffDay: 31, calendar: calendar)

        #expect(febrero.end == startOfDay(2026, 2, 28))
    }

    @Test("Con corte 31, después de febrero el corte vuelve al 31")
    func corte31VuelveAl31DespuesDeFebrero() {
        let enero = StatementCycle.containing(date(2026, 1, 15), cutoffDay: 31, calendar: calendar)
        let marzo = enero
            .next(cutoffDay: 31, calendar: calendar)
            .next(cutoffDay: 31, calendar: calendar)

        #expect(marzo.end == startOfDay(2026, 3, 31))
    }

    @Test("Con corte 31, ir hacia atrás desde marzo pasa por el 28 de febrero")
    func corte31HaciaAtrasPasaPorFebrero() {
        let marzo = StatementCycle.containing(date(2026, 3, 15), cutoffDay: 31, calendar: calendar)
        let febrero = marzo.previous(cutoffDay: 31, calendar: calendar)

        #expect(febrero.end == startOfDay(2026, 2, 28))
    }

    @Test("Ir al anterior y regresar al siguiente deja el mismo ciclo")
    func idaYVueltaDejaElMismoCiclo() {
        let actual = StatementCycle.containing(date(2026, 10, 5), cutoffDay: 12, calendar: calendar)
        let ida = actual
            .previous(cutoffDay: 12, calendar: calendar)
            .next(cutoffDay: 12, calendar: calendar)

        #expect(ida.start == actual.start && ida.end == actual.end)
    }

    @Test("El ciclo anterior cruza el año sin perderse")
    func elAnteriorCruzaElAnio() {
        let enero = StatementCycle.containing(date(2026, 1, 5), cutoffDay: 12, calendar: calendar)
        let diciembre = enero.previous(cutoffDay: 12, calendar: calendar)

        #expect(diciembre.start == startOfDay(2025, 11, 12))
    }
}
