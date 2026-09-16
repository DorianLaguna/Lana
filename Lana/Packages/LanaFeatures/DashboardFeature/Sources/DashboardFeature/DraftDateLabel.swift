import Foundation
import LanaDesign

/// Cómo se nombra una fecha en un chip: "Hoy", "Ayer" o "14 de septiembre".
///
/// Vive aquí y no en `LanaDesign` porque es copy, no diseño; y aparte de
/// `DraftCard` (que tiene el suyo en `EntryFeature`, y las features no se
/// importan entre sí) lo usa el formulario de un movimiento.
enum DraftDateLabel {
    static func text(for date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Hoy"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ayer"
        }
        let day = calendar.component(.day, from: date)
        return "\(day) de \(LanaDateFormat.monthNameLowercased(date, calendar: calendar))"
    }
}
