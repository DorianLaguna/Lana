import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// Ingresos y gastos recurrentes en el Dashboard — sueldo, renta,
/// suscripciones. Cada fila dice si ya se registró este mes; lo pendiente se
/// registra solo el día que vence, o antes con un toque (`RecurringItem`).
public struct RecurringItemsSection: View {
    @Environment(\.lana) private var lana
    // Colapsado por default: con varios recurrentes dados de alta, la lista
    // completa desplegada siempre empujaba el resto del Dashboard hacia
    // abajo — el conteo ya dice lo esencial sin tener que desplegarla.
    @State private var isExpanded = false
    @State private var itemPendingDelete: RecurringItem?
    @State private var itemPendingEarlyRegister: RecurringItem?
    private let items: [RecurringItem]
    private let registrations: [RecurringItemID: RecurringItem.Registration]
    private let onAdd: () -> Void
    private let onEdit: (RecurringItem) -> Void
    private let onRegister: (RecurringItem) -> Void
    private let onDelete: (RecurringItem) -> Void

    /// - Parameter registrations: qué recurrentes ya se registraron este mes;
    ///   uno sin entrada sigue pendiente (`RecurringItemsModel.registrations`).
    public init(
        items: [RecurringItem],
        registrations: [RecurringItemID: RecurringItem.Registration],
        onAdd: @escaping () -> Void,
        onEdit: @escaping (RecurringItem) -> Void,
        onRegister: @escaping (RecurringItem) -> Void,
        onDelete: @escaping (RecurringItem) -> Void) {
        self.items = items
        self.registrations = registrations
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
                    Text("Agrega tu quincena, renta u otros pagos fijos. Lana los registra sola el día que caen.")
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
        // Registrar antes de tiempo fue justo lo que confundió: la palomita
        // parecía un "¿ya pasó?" y en realidad registraba el movimiento con
        // fecha de hoy. Preguntar solo cuando todavía no vence deja claro qué
        // hace, sin estorbar cuando ya llegó.
        .confirmationDialog(
            itemPendingEarlyRegister.map(earlyRegisterTitle) ?? "",
            isPresented: Binding(
                get: { itemPendingEarlyRegister != nil },
                set: { isPresented in
                    if !isPresented {
                        itemPendingEarlyRegister = nil
                    }
                }),
            titleVisibility: .visible,
            presenting: itemPendingEarlyRegister) { item in
                Button("Sí, registrar hoy") {
                    onRegister(item)
                    itemPendingEarlyRegister = nil
                }
        } message: { item in
            Text("""
            Se registra con fecha de hoy. Si todavía no, no hagas nada: \
            Lana lo registra sola el día \(dueDay(of: item)).
            """)
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
            HStack(spacing: Space.xs.rawValue) {
                Text(statusText(for: item))
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
            // La palomita es el estado: llena = ya registrado este mes, vacía
            // = pendiente, y tocarla lo registra. Antes solo existía la vacía
            // y desaparecía al registrar, así que no había forma de saber si
            // faltaba o si ya estaba.
            if registrations[item.id] != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(lana.accent)
                    .accessibilityLabel("Registrado este mes")
            } else {
                Button {
                    if item.isDue(asOf: Date()) {
                        onRegister(item)
                    } else {
                        itemPendingEarlyRegister = item
                    }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(lana.highlight)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Registrar \(item.name)")
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
            .accessibilityLabel("Borrar \(item.name)")
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

    private func statusText(for item: RecurringItem) -> String {
        switch registrations[item.id] {
        case let .linked(expense):
            "Registrado el \(expense.date.formatted(.dateTime.day().month(.abbreviated)))"
        case .legacy:
            "Registrado este mes"
        case nil:
            "Pendiente · día \(dueDay(of: item))"
        }
    }

    /// El día en que cae este mes — un recurrente del 31 cae el 30 en septiembre.
    private func dueDay(of item: RecurringItem) -> Int {
        guard let occurrence = item.occurrence(inMonthOf: Date()) else { return item.dayOfMonth }
        return Calendar.current.component(.day, from: occurrence)
    }

    private func earlyRegisterTitle(for item: RecurringItem) -> String {
        item.kind == .income ? "¿Ya te llegó \(item.name)?" : "¿Ya pagaste \(item.name)?"
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
    let rent = try? RecurringItem(
        name: "Renta",
        amount: Money(amount: 8000, currency: .mxn),
        kind: .expense,
        category: "hogar",
        dayOfMonth: 5)
    let salary = try? RecurringItem(
        name: "Sueldo",
        amount: Money(amount: 15000, currency: .mxn),
        kind: .income,
        dayOfMonth: 15)
    let items = [rent, salary].compactMap(\.self)
    let registrations: [RecurringItemID: RecurringItem.Registration] = rent.map { rent in
        [rent.id: .linked(Expense(kind: .expense, amount: rent.amount, concept: rent.name, date: Date()))]
    } ?? [:]

    return ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                RecurringItemsSection(
                    items: items,
                    registrations: registrations,
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
