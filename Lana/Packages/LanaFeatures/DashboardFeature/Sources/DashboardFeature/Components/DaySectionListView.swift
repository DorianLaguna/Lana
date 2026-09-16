import LanaCore
import LanaDesign
import SwiftUI

/// Movimientos agrupados por día, para los drill-downs de una categoría o de
/// una forma de pago.
///
/// Usa las mismas filas que Hoy y Mes: sin punto de color, con "Categoría ·
/// Forma de pago" debajo del concepto.
struct DaySectionListView: View {
    @Environment(\.lana) private var lana

    private let sections: [DaySection]
    private let source: any ExpenseProviding
    private let onSelect: (Expense) -> Void

    init(sections: [DaySection], source: any ExpenseProviding, onSelect: @escaping (Expense) -> Void = { _ in }) {
        self.sections = sections
        self.source = source
        self.onSelect = onSelect
    }

    var body: some View {
        if sections.isEmpty {
            EmptyStateView(
                systemImage: "tray",
                title: "Sin movimientos",
                message: "Cuando registres algo, aparece aquí.")
        } else {
            LazyVStack(alignment: .leading, spacing: Space.p20.rawValue) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(LanaDateFormat.dayHeader(section.day), style: .minor)
                        MovementRows(expenses: section.items, source: source, onSelect: onSelect)
                    }
                }
            }
        }
    }
}
