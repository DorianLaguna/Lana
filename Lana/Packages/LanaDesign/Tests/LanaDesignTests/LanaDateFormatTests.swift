import Foundation
import Testing
@testable import LanaDesign

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

    @Test("La inicial del mes")
    func inicialDelMes() {
        #expect(LanaDateFormat.monthInitial(date(2026, 3, 1), calendar: calendar) == "M")
    }
}
