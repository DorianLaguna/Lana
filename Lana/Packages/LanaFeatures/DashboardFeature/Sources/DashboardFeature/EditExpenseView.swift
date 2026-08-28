import LanaCore
import LanaDesign
import SwiftUI

/// El formulario de editar un gasto/ingreso ya guardado. Sin lógica propia
/// — refleja `EditExpenseModel`.
public struct EditExpenseView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: EditExpenseModel
    @State private var isConfirmingDelete = false
    @State private var isEnteringCustomSubcategory = false
    private let onDone: () -> Void

    public init(model: EditExpenseModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
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
                    LanaTextField("Concepto", text: $model.concept)
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
                    DatePicker("Fecha", selection: $model.date, displayedComponents: .date)
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.critical)
                }

                Section {
                    Button("Borrar", role: .destructive) {
                        isConfirmingDelete = true
                    }
                    .disabled(model.isSaving)
                    // En el botón que lo dispara, no en el Form/NavigationStack
                    // — colgarlo más arriba en el árbol de vistas lo desanclaba
                    // del botón real y lo dejaba apareciendo hasta arriba de la
                    // pantalla en vez de junto a "Borrar".
                    .confirmationDialog(
                        "¿Borrar este gasto?",
                        isPresented: $isConfirmingDelete,
                        titleVisibility: .visible) {
                            Button("Borrar", role: .destructive) {
                                Task {
                                    if await model.delete() {
                                        onDone()
                                    }
                                }
                            }
                    }
                }
            }
            .task { await model.onAppear() }
            .navigationTitle("Editar")
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

    private var categoryPicker: some View {
        Picker("Categoría", selection: $model.category) {
            ForEach(SuggestedCategory.allCases) { category in
                Text(category.displayName).tag(category.rawValue)
            }
        }
    }

    /// Sin opción "Automático" — mismo patrón que `DraftCard.subcategoryPicker`
    /// (ver ese archivo para el porqué): la selección refleja el valor real
    /// de `model.subcategory` directamente, nunca un texto especial que
    /// esconde si de verdad se resolvió algo.
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
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        EditExpenseView(
            model: EditExpenseModel(
                expense: Expense(
                    kind: .expense,
                    amount: Money(amount: 131, currency: .mxn),
                    concept: "Dulces",
                    category: "despensa",
                    date: .now),
                store: InMemoryExpenseStore(),
                vocabularyStore: InMemoryCorrectionVocabularyStore()),
            onDone: {})
            .lanaTheme(theme)
    }
}
