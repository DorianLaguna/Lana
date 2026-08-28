import Foundation
import Testing
@testable import LanaParsing

@Suite("RelativeDateExtractor")
struct RelativeDateExtractorTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func day(_ resolved: Date?) -> DateComponents? {
        resolved.map { calendar.dateComponents([.year, .month, .day], from: $0) }
    }

    @Test("Sin mención de fecha, devuelve nil")
    func sinMencionDevuelveNil() {
        let result = RelativeDateExtractor().date(in: "300 de gasolina", now: date(2026, 8, 27), calendar: calendar)
        #expect(result == nil)
    }

    @Test("Hoy resuelve al mismo día")
    func hoyResuelveAlMismoDia() {
        let now = date(2026, 8, 27)
        let result = RelativeDateExtractor().date(in: "hoy gasté 300 en gasolina", now: now, calendar: calendar)
        #expect(result == now)
    }

    @Test("Ayer resuelve un día antes")
    func ayerResuelveUnDiaAntes() {
        let now = date(2026, 8, 27)
        let result = RelativeDateExtractor().date(in: "ayer gasté 300 en gasolina", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 8, 26)))
    }

    @Test("Anteayer resuelve dos días antes")
    func anteayerResuelveDosDiasAntes() {
        let now = date(2026, 8, 27)
        let result = RelativeDateExtractor().date(in: "anteayer pagué la renta", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 8, 25)))
    }

    @Test("Un día del mes que ya pasó es de este mes — el bug reportado")
    func unDiaQueYaPasoEsDeEsteMes() {
        let now = date(2026, 8, 27)
        let result = RelativeDateExtractor().date(in: "el 24 gasté 300 en gasolina", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 8, 24)))
    }

    @Test("Un día del mes que todavía no llega es del mes pasado")
    func unDiaQueNoLlegaEsDelMesPasado() {
        let now = date(2026, 8, 10)
        let result = RelativeDateExtractor().date(in: "el 24 gasté 300 en gasolina", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 7, 24)))
    }

    @Test("El mismo día de hoy es de este mes, no del pasado")
    func elMismoDiaDeHoyEsDeEsteMes() {
        let now = date(2026, 8, 24)
        let result = RelativeDateExtractor().date(in: "el 24 gasté 300 en gasolina", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 8, 24)))
    }

    @Test("Decir explícitamente 'del mes pasado' siempre gana, aunque el día ya haya pasado este mes")
    func delMesPasadoSiempreGana() {
        let now = date(2026, 8, 27)
        let result = RelativeDateExtractor().date(
            in: "el 24 del mes pasado gasté 300",
            now: now,
            calendar: calendar)
        #expect(day(result) == day(date(2026, 7, 24)))
    }

    @Test("Un día que no existe en el mes destino se acota al último día de ese mes")
    func unDiaQueNoExisteSeAcota() {
        // Hoy es 5 de marzo; "el 31" (día 31 > 5) cae al mes pasado — febrero, que no tiene 31.
        let now = date(2026, 3, 5)
        let result = RelativeDateExtractor().date(in: "el 31 gasté 300", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 2, 28)))
    }

    @Test("Un día con mes explícito no necesita inferir nada")
    func unDiaConMesExplicitoNoInfiereNada() {
        let now = date(2026, 8, 27)
        let result = RelativeDateExtractor().date(in: "el 24 de julio gasté 300", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 7, 24)))
    }

    @Test("Un mes explícito que todavía no llega este año cae al año pasado")
    func unMesExplicitoFuturoCaeAlAnoPasado() {
        let now = date(2026, 3, 1)
        let result = RelativeDateExtractor().date(in: "el 24 de diciembre gasté 300", now: now, calendar: calendar)
        #expect(day(result) == day(date(2025, 12, 24)))
    }

    @Test("Un día de la semana resuelve a su ocurrencia más reciente")
    func unDiaDeLaSemanaResuelveALaMasReciente() {
        // 27 de agosto de 2026 es jueves.
        let now = date(2026, 8, 27)
        let result = RelativeDateExtractor().date(in: "el lunes pagué la renta", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 8, 24)))
    }

    @Test("Un día de la semana que es hoy resuelve a hoy, no a hace una semana")
    func unDiaDeLaSemanaQueEsHoyResuelveAHoy() {
        // 27 de agosto de 2026 es jueves.
        let now = date(2026, 8, 27)
        let result = RelativeDateExtractor().date(in: "el jueves pagué la renta", now: now, calendar: calendar)
        #expect(day(result) == day(date(2026, 8, 27)))
    }
}
