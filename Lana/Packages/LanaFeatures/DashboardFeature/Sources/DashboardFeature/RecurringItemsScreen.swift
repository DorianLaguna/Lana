import LanaCore
import LanaDesign
import SwiftUI

/// Los recurrentes como pantalla propia, empujada desde Mes (rediseño,
/// sección 11).
///
/// El diseño anterior ponía nueve filas idénticas, cada una con un check y un
/// bote de basura rojo: dieciocho botones, dos de ellos destructivos y a un
/// dedo del de confirmar. Aquí lo pendiente va arriba con un botón ancho que
/// dice qué hace, lo ya registrado va apagado abajo, y borrar se esconde
/// detrás de un swipe.
struct RecurringItemsScreen: View {
    @Environment(\.lana) private var lana
    @Bindable var model: RecurringItemsModel
    let onAdd: () -> Void
    let onEdit: (RecurringItem) -> Void
    let onChanged: () async -> Void

    @State private var itemPendingDelete: RecurringItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if model.items.isEmpty, !model.isLoading {
                    emptyState
                } else {
                    Text(summary)
                        .lanaFont(.callout)
                        .foregroundStyle(lana.ink50)
                        .padding(.bottom, Space.p26.rawValue)

                    pendingSection
                    registeredSection
                    upcomingSection

                    // Dice "mantén presionada" y no "desliza" porque
                    // `.swipeActions` solo existe dentro de un `List`, y estas
                    // filas viven en un `VStack`: ahí el modificador se ignora
                    // en silencio — el mismo bug que ya había tenido la versión
                    // anterior de esta pantalla.
                    Text("""
                    Mantén presionada una fila para editarla o borrarla. Editar solo afecta lo que viene; \
                    lo ya registrado se queda.
                    """)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink35)
                    .padding(.top, Space.p20.rawValue)
                }
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle("Recurrentes")
        .lanaInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nuevo", action: onAdd)
            }
        }
        .confirmationDialog(
            "¿Borrar \(itemPendingDelete?.name ?? "este recurrente")?",
            isPresented: isDeletingBinding,
            titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    if let item = itemPendingDelete {
                        Task {
                            try? await model.delete(item)
                            await onChanged()
                        }
                    }
                    itemPendingDelete = nil
                }
        } message: {
            Text("Lo ya registrado se queda en tus movimientos.")
        }
    }

    /// "9 fijos · $22,443 al mes · 3 sin registrar".
    private var summary: String {
        var parts = [model.items.count == 1 ? "1 fijo" : "\(model.items.count) fijos"]
        if let total = model.monthlyExpenseTotal.first {
            parts.append("\(total.formatted()) al mes")
        }
        let pending = model.pendingCount()
        if pending > 0 {
            parts.append(pending == 1 ? "1 sin registrar" : "\(pending) sin registrar")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Pendientes

    @ViewBuilder
    private var pendingSection: some View {
        let pending = model.pending()
        if !pending.isEmpty {
            SectionHeader("Pendientes", style: .attention)
                .padding(.bottom, Space.p12.rawValue)
            VStack(spacing: Space.p10.rawValue) {
                ForEach(pending) { item in
                    pendingCard(item)
                }
            }
            .padding(.bottom, Space.p30.rawValue)
        }
    }

    /// Registrar no pide confirmación: es reversible con un swipe, y pedirla
    /// convertiría un toque en tres.
    private func pendingCard(_ item: RecurringItem) -> some View {
        LanaCard(padding: .p15, fill: .attention) {
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                HStack(alignment: .firstTextBaseline, spacing: Space.p10.rawValue) {
                    VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                        Text(item.name)
                            .lanaFont(.rowTitle)
                            .foregroundStyle(lana.ink)
                        Text(subtitle(for: item))
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.ink50)
                    }
                    Spacer(minLength: Space.sm.rawValue)
                    Text(amountText(for: item))
                        .lanaFont(.statAmount)
                        .foregroundStyle(item.kind == .income ? lana.positive : lana.ink)
                }

                Button("Registrar hoy") {
                    Task {
                        try? await model.register(item)
                        await onChanged()
                    }
                }
                .buttonStyle(.lana(.attention, size: .medium, isExpanded: true))
            }
        }
        .contextMenu { rowActions(item) }
    }

    // MARK: - Ya registrados

    @ViewBuilder
    private var registeredSection: some View {
        let registered = model.registered()
        if !registered.isEmpty {
            SectionHeader("Ya se registraron en \(LanaDateFormat.monthNameLowercased(Date()))", style: .minor)
                .padding(.bottom, Space.p12.rawValue)
            LanaCard(padding: nil) {
                VStack(spacing: 0) {
                    ForEach(Array(registered.enumerated()), id: \.element.id) { index, item in
                        quietRow(item, isMuted: true)
                        if index < registered.count - 1 {
                            HairlineDivider()
                        }
                    }
                }
            }
            .padding(.bottom, Space.p30.rawValue)
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = model.upcoming()
        if !upcoming.isEmpty {
            SectionHeader("Todavía no caen", style: .minor)
                .padding(.bottom, Space.p12.rawValue)
            LanaCard(padding: nil) {
                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, item in
                        quietRow(item, isMuted: false)
                        if index < upcoming.count - 1 {
                            HairlineDivider()
                        }
                    }
                }
            }
        }
    }

    private func quietRow(_ item: RecurringItem, isMuted: Bool) -> some View {
        HStack(spacing: Space.p10.rawValue) {
            VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                Text(item.name)
                    .lanaFont(.rowTitle)
                    .fontWeight(.medium)
                    .foregroundStyle(isMuted ? lana.ink70 : lana.ink)
                Text(subtitle(for: item))
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(isMuted ? lana.ink35 : lana.ink42)
            }
            Spacer(minLength: Space.sm.rawValue)
            Text(amountText(for: item))
                .lanaFont(.rowAmount)
                .foregroundStyle(isMuted ? lana.ink50 : lana.ink)
        }
        .padding(Space.md.rawValue)
        .frame(minHeight: LanaMetrics.minRowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .contextMenu { rowActions(item) }
    }

    // MARK: - Acciones

    /// Editar y borrar viven detrás de una pulsación larga: no compiten con
    /// "Registrar hoy", y el rojo de borrar solo aparece dentro del menú, que
    /// es cosa del sistema.
    @ViewBuilder
    private func rowActions(_ item: RecurringItem) -> some View {
        Button("Editar") { onEdit(item) }
        Button("Borrar", role: .destructive) { itemPendingDelete = item }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "arrow.triangle.2.circlepath",
            title: "Sin gastos fijos",
            message: "Registra la renta o tu sueldo y Lana los anota solo.",
            actionTitle: "Nuevo recurrente",
            action: onAdd)
            .padding(.top, Space.xxl.rawValue)
    }

    /// "Hogar · día 30 · Transferencia".
    private func subtitle(for item: RecurringItem) -> String {
        var parts: [String] = []
        if let category = item.category, !category.isEmpty {
            parts.append(DashboardModel.categoryDisplayName(category))
        }
        parts.append("día \(dueDay(of: item))")
        if let method = paymentLabel(item.paymentMethod) {
            parts.append(method)
        }
        return parts.joined(separator: " · ")
    }

    /// Un ingreso lleva su signo además del color.
    private func amountText(for item: RecurringItem) -> String {
        item.kind == .income ? "+\(item.amount.formatted())" : item.amount.formatted()
    }

    /// El día en que cae este mes — uno del 31 cae el 30 en septiembre.
    private func dueDay(of item: RecurringItem) -> Int {
        guard let occurrence = item.occurrence(inMonthOf: Date()) else { return item.dayOfMonth }
        return Calendar.current.component(.day, from: occurrence)
    }

    private func paymentLabel(_ method: PaymentMethod?) -> String? {
        switch method {
        case .cash: "Efectivo"
        case .debit: "Débito"
        case .credit: "Crédito"
        case .transfer: "Transferencia"
        case nil: nil
        }
    }

    private var isDeletingBinding: Binding<Bool> {
        Binding(
            get: { itemPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    itemPendingDelete = nil
                }
            })
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            RecurringItemsScreen(
                model: RecurringItemsModel(
                    recurringItemStore: InMemoryRecurringItemStore(),
                    store: InMemoryExpenseStore(),
                    cardStore: InMemoryCardStore()),
                onAdd: {},
                onEdit: { _ in },
                onChanged: {})
        }
        .lanaTheme(theme)
    }
}
