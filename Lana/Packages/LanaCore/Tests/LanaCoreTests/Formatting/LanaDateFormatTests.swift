import Foundation
import Testing
@testable import LanaCore

@Suite("Fechas en español")
struct LanaDateFormatTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .current
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    @Test("El mes sale en español con mayúscula inicial aunque el sistema esté en inglés")
    func mesEnEspanol() {
        #expect(LanaDateFormat.monthName(date(2026, 9, 15), calendar: calendar) == "Septiembre")
    }

    @Test("El mes en minúscula para frases")
    func mesEnMinuscula() {
        #expect(LanaDateFormat.monthNameLowercased(date(2026, 8, 1), calendar: calendar) == "agosto")
    }

    @Test("Mes y año sin preposición")
    func mesYAnio() {
        #expect(LanaDateFormat.monthYear(date(2026, 9, 15), calendar: calendar) == "Septiembre 2026")
    }

    @Test("El encabezado de día es día de la semana y número, sin mes")
    func encabezadoDeDia() {
        #expect(LanaDateFormat.dayHeader(date(2026, 9, 14), calendar: calendar) == "Lunes 14")
    }

    @Test("Una fecha de chip dice Hoy, Ayer o el día con su mes")
    func etiquetaDeDia() {
        let hoy = date(2026, 9, 15)
        #expect(LanaDateFormat.dayLabel(hoy, calendar: calendar, now: hoy) == "Hoy")
        #expect(LanaDateFormat.dayLabel(date(2026, 9, 14), calendar: calendar, now: hoy) == "Ayer")
        #expect(LanaDateFormat.dayLabel(date(2026, 9, 3), calendar: calendar, now: hoy) == "3 de septiembre")
    }

    @Test("La inicial del mes")
    func inicialDelMes() {
        #expect(LanaDateFormat.monthInitial(date(2026, 3, 1), calendar: calendar) == "M")
    }

    @Test("Un corte se nombra por el día en que cierra")
    func nombreDelCorte() {
        let corte = calendar.startOfDay(for: date(2026, 10, 12))
        #expect(LanaDateFormat.cycleName(end: corte, calendar: calendar, now: date(2026, 10, 5))
            == "Corte del 12 de octubre")
    }

    @Test("Un corte de otro año trae el año")
    func nombreDelCorteDeOtroAnio() {
        let corte = calendar.startOfDay(for: date(2025, 10, 12))
        #expect(LanaDateFormat.cycleName(end: corte, calendar: calendar, now: date(2026, 10, 5))
            == "Corte del 12 de octubre de 2025")
    }
}
