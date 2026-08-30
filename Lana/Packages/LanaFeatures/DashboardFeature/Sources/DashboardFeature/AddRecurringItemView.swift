import LanaCore
import LanaDesign
import SwiftUI

/// El formulario de agregar/editar un recurrente. Sin lógica propia —
/// refleja `AddRecurringItemModel`.
public struct AddRecurringItemView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: AddRecurringItemModel
    @State private var isEnteringCustomSubcategory = false
    private let onDone: () -> Void

    public init(model: AddRecurringItemModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    /// Solo para ingreso — "sueldo" no tiene sentido como atajo al dar de
    /// alta un gasto recurrente (renta, suscripciones, ...), que no
    /// comparte esos nombres.
    private static let quickNames = ["Sueldo", "Nómina", "Extra"]

    private var quickNameOptions: some View {
        HStack(spacing: Space.xs.rawValue) {
            ForEach(Self.quickNames, id: \.self) { name in
                Button(name) {
                    model.name = name
                }
                .buttonStyle(.bordered)
                .tint(model.name == name ? lana.highlight : lana.textSecondary)
            }
        }
    }

    /// Un recurrente es una plantilla que se usa mes tras mes — a
    /// diferencia de la categoría al capturar por voz (que se deja como
    /// texto libre, a propósito, para no frenar una captura rápida), aquí
    /// vale la pena un dropdown cerrado: se llena una sola vez.
    private var categoryPicker: some View {
        Picker("Categoría", selection: $model.category) {
            ForEach(SuggestedCategory.allCases) { category in
                Text(category.displayName).tag(category.rawValue)
            }
        }
    }

    /// Mismo patrón que `EditExpenseView.subcategoryPicker` — sin opción
    /// "Automático", la selección refleja `model.subcategory` directamente.
    private var subcategoryPicker: some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            Picker("Subcategoría", selection: subcategorySelection) {
                Text("Sin subcategoría").tag(SubcategorySelection.none)
                ForEach(subcategoryOptions, id: \.self) { subcategory in
                    Text(subcategory.capitalized).tag(SubcategorySelection.existing(subcategory))
                }
                Text("Otra…").tag(SubcategorySelection.custom)
            }

            if isEnteringCustomSubcategory {
                LanaTextField("Nombre de la subcategoría", text: $model.subcategory)
            }
        }
    }

    private enum SubcategorySelection: Hashable {
        case none
        case existing(String)
        case custom
    }

    private var subcategoryOptions: [String] {
        var options = Set(model.allSubcategories[model.category] ?? [])
        if !model.subcategory.isEmpty, !isEnteringCustomSubcategory {
            options.insert(model.subcategory)
        }
        return options.sorted()
    }

    private var subcategorySelection: Binding<SubcategorySelection> {
        Binding(
            get: {
                if isEnteringCustomSubcategory {
                    return .custom
                }
                if model.subcategory.isEmpty {
                    return .none
                }
                return .existing(model.subcategory)
            },
            set: { selection in
                switch selection {
                case .none:
                    isEnteringCustomSubcategory = false
                    model.subcategory = ""
                case let .existing(name):
                    isEnteringCustomSubcategory = false
                    model.subcategory = name
                case .custom:
                    isEnteringCustomSubcategory = true
                    model.subcategory = ""
                }
            })
    }

    private var paymentMethodPicker: some View {
        Picker("Método de pago", selection: $model.paymentMethod) {
            Text("Efectivo").tag(PaymentMethod.cash)
            Text("Transferencia").tag(PaymentMethod.transfer)
            ForEach(model.cards) { card in
                Text(card.alias)
                    .tag(card.kind == .credit ? PaymentMethod.credit(cardID: card.id) : .debit(cardID: card.id))
            }
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $model.kind) {
                        Text("Gasto").tag(Expense.Kind.expense)
                        Text("Ingreso").tag(Expense.Kind.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .padding(Space.sm.rawValue)
                }

                Section {
                    // Botones de un toque para lo más común — solo tiene
                    // sentido para ingreso ("sueldo" no aplica a un gasto
                    // recurrente). El campo sigue editable para quien
                    // quiera afinar el nombre después de tocar uno.
                    if model.kind == .income {
                        quickNameOptions
                    }
                    LanaTextField("Nombre", text: $model.name)
                    if model.kind == .expense {
                        categoryPicker
                        subcategoryPicker
                    }
                }

                Section {
                    HStack {
                        Text("Monto")
                            .foregroundStyle(lana.textPrimary)
                        Spacer()
                        TextField("0", value: $model.amount, format: .number)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                    }
                    HStack {
                        Text("Día del mes")
                            .foregroundStyle(lana.textPrimary)
                        Spacer()
                        TextField("1-31", value: $model.dayOfMonth, format: .number)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                    }
                } footer: {
                    // Lo que ya se registró queda con su monto original —
                    // cambiar esto no reescribe el pasado (Docs/CLAUDE.md →
                    // "los eventos son inmutables").
                    Text("Los cambios aplican solo hacia adelante — lo ya registrado no se toca.")
                }

                // Con qué se paga — solo aplica a gastos (un ingreso no se
                // "paga"), mismo picker que usa la revisión de captura.
                if model.kind == .expense {
                    Section {
                        paymentMethodPicker
                    }
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.critical)
                }
            }
            .task { await model.onAppear() }
            .navigationTitle("Recurrente")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                if await model.save() {
                                    onDone()
                                }
                            }
                        } label: {
                            if model.isSaving {
                                ProgressView()
                            } else {
                                Text("Guardar")
                            }
                        }
                        .disabled(model.isSaving)
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        AddRecurringItemView(
            model: AddRecurringItemModel(
                recurringItemStore: InMemoryRecurringItemStore(),
                store: InMemoryExpenseStore()),
            onDone: {})
            .lanaTheme(theme)
    }
}
