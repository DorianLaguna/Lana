import LanaCore
import SwiftUI

/// El picker de categoría, con el catálogo que le toca al tipo de movimiento:
/// las once de gasto (`SuggestedCategory`) o las ocho de ingreso
/// (`IncomeCategory`). Son listas distintas y nunca se mezclan (ADR-0040).
///
/// Existe como componente porque lo usan los dos formularios —el de una
/// transacción (`EditExpenseView`) y el de un recurrente
/// (`AddRecurringItemView`)— y tener el `switch` duplicado en ambos es
/// exactamente cómo se desincronizan.
struct CategoryPicker: View {
    let kind: Expense.Kind
    @Binding var category: String

    var body: some View {
        switch kind {
        case .expense:
            Picker("Categoría", selection: $category) {
                ForEach(SuggestedCategory.allCases) { category in
                    Text(category.displayName).tag(category.rawValue)
                }
            }
        case .income:
            Picker("De dónde vino", selection: $category) {
                ForEach(IncomeCategory.allCases) { category in
                    // La pista va junto al nombre: "sueldo" y "freelance" se
                    // entienden solos, pero "renta" e "inversión" no dicen de
                    // qué lado están sin ella.
                    Text(verbatim: "\(category.displayName) · \(category.hint)")
                        .tag(category.rawValue)
                }
            }
        }
    }
}
