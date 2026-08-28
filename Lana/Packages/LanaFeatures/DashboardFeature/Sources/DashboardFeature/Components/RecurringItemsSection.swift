import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// Ingresos y gastos recurrentes en el Dashboard — sueldo, renta,
/// suscripciones. Cada fila se registra este mes con un toque; nunca se
/// postea sola (`RecurringItem`).
public struct RecurringItemsSection: View {
    @Environment(\.lana) private var lana
    // Colapsado por default: con varios recurrentes dados de alta, la lista
    // completa desplegada siempre empujaba el resto del Dashboard hacia
    // abajo — el conteo ya dice lo esencial sin tener que desplegarla.
    @State private var isExpanded = false
    @State private var itemPendingDelete: RecurringItem?
    private let items: [RecurringItem]
    private let onAdd: () -> Void
    private let onEdit: (RecurringItem) -> Void
    private let onRegister: (RecurringItem) -> Void
    private let onDelete: (RecurringItem) -> Void

    public init(
        items: [RecurringItem],
        onAdd: @escaping () -> Void,
        onEdit: @escaping (RecurringItem) -> Void,
        onRegister: @escaping (RecurringItem) -> Void,
        onDelete: @escaping (RecurringItem) -> Void) {
        self.items = items
        self.onAdd = onAdd
        self.onEdit = onEdit
        self.onRegister = onRegister
        self.onDelete = onDelete
    }

    public var body: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                HStack {
                    Text("Recurrentes")
                        .lanaFont(.caption)
                        .foregroundStyle(lana.textSecondary)
                    Spacer()
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                    }
                }

                if items.isEmpty {
                    Text("Agrega tu quincena, renta u otros pagos fijos, para registrarlos en un toque cada mes.")
                        .lanaFont(.caption)
                        .foregroundStyle(lana.textSecondary)
                } else {
                    DisclosureGroup(isExpanded: $isExpanded) {
                        VStack(spacing: 0) {
                            ForEach(items) { item in
                                row(for: item)
                                if item.id != items.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.top, Space.xs.rawValue)
                    } label: {
                        Text("\(items.count) \(items.count == 1 ? "recurrente" : "recurrentes")")
                            .lanaFont(.body)
                            .foregroundStyle(lana.textPrimary)
                    }
                }
            }
        }
    }

    private func row(for item: RecurringItem) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            // El color nunca es el único portador de información — antes solo
            // el monto se teñía de verde para ingreso, fácil de pasar por
            // alto; el ícono lo deja inequívoco de un vistazo.
            Image(systemName: item.kind == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(item.kind == .income ? lana.positive : lana.textSecondary)

            label(for: item)

            Spacer()

            Text(item.amount.formatted())
                .lanaFont(.body)
                .monospacedDigit()
                .foregroundStyle(item.kind == .income ? lana.positive : lana.textPrimary)

            rowActions(for: item)
        }
        .padding(.vertical, Space.xs.rawValue)
        .contentShape(Rectangle())
        .onTapGesture { onEdit(item) }
    }

    private func label(for item: RecurringItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .lanaFont(.body)
                .foregroundStyle(lana.textPrimary)
            HStack(spacing: 4) {
                Text("Día \(item.dayOfMonth)")
                if let label = paymentMethodLabel(item.paymentMethod) {
                    Text("·")
                    Text(label)
                }
            }
            .lanaFont(.caption)
            .foregroundStyle(lana.textSecondary)
        }
    }

    private func rowActions(for item: RecurringItem) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            // Ya se registra solo cuando vence (`registerDueItems()`) — si
            // ya se registró este mes, ofrecer la palomita otra vez solo
            // invita a duplicar sin dar nada a cambio (no hay dedup en el
            // registro manual, a propósito). Sigue visible antes de que
            // venza, para quien quiera adelantarlo.
            if !isRegisteredThisMonth(item) {
                Button {
                    onRegister(item)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(lana.highlight)
                }
                .buttonStyle(.plain)
            }

            // Reemplaza `.swipeActions`, que no hacía nada aquí — ese
            // modificador solo funciona dentro de un `List`, y esta fila
            // vive en un `VStack` normal dentro de `LanaCard` (se ignoraba
            // en silencio; nunca hubo forma real de borrar un recurrente).
            Button {
                itemPendingDelete = item
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(lana.critical)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "¿Borrar \(item.name)?",
                isPresented: Binding(
                    get: { itemPendingDelete?.id == item.id },
                    set: { isPresented in
                        if !isPresented {
                            itemPendingDelete = nil
                        }
                    })) {
                Button("Borrar", role: .destructive) {
                    onDelete(item)
                    itemPendingDelete = nil
                }
            }
        }
    }

    private func isRegisteredThisMonth(_ item: RecurringItem) -> Bool {
        guard let lastRegisteredMonth = item.lastRegisteredMonth,
              let currentMonthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start else {
            return false
        }
        return lastRegisteredMonth == currentMonthStart
    }

    private func paymentMethodLabel(_ method: PaymentMethod?) -> String? {
        switch method {
        case .cash: "Efectivo"
        case .debit: "Débito"
        case .credit: "Crédito"
        case .transfer: "Transferencia"
        case nil: nil
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                RecurringItemsSection(
                    items: [
                        (try? RecurringItem(
                            name: "Renta",
                            amount: Money(amount: 8000, currency: .mxn),
                            kind: .expense,
                            category: "hogar",
                            dayOfMonth: 5)),
                        (try? RecurringItem(
                            name: "Sueldo",
                            amount: Money(amount: 15000, currency: .mxn),
                            kind: .income,
                            dayOfMonth: 15))
                    ].compactMap(\.self),
                    onAdd: {},
                    onEdit: { _ in },
                    onRegister: { _ in },
                    onDelete: { _ in })
                    .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}
