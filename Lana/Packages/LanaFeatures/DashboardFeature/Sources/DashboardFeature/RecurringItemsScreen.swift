import LanaCore
import LanaDesign
import SwiftUI

/// Los recurrentes como pantalla propia, empujada desde Mes. Provisional:
/// reutiliza `RecurringItemsSection` hasta que llegue el diseño de la sección
/// 11 (pendientes arriba, registrados apagados, swipe para editar).
struct RecurringItemsScreen: View {
    @Environment(\.lana) private var lana
    let model: RecurringItemsModel
    let onAdd: () -> Void
    let onEdit: (RecurringItem) -> Void
    let onChanged: () async -> Void

    var body: some View {
        ScrollView {
            RecurringItemsSection(
                items: model.items,
                registrations: model.registrations,
                onAdd: onAdd,
                onEdit: onEdit,
                onRegister: { item in
                    Task {
                        try? await model.register(item)
                        await onChanged()
                    }
                },
                onDelete: { item in
                    Task {
                        try? await model.delete(item)
                        await onChanged()
                    }
                })
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.p18.rawValue)
                .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle("Recurrentes")
        .lanaInlineNavigationTitle()
    }
}
