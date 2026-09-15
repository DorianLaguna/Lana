import LanaCore
import LanaDesign
import SwiftUI

/// El formulario de un gasto/ingreso: el mismo para editar uno ya guardado y
/// para registrar uno nuevo a mano (ADR-0035) — lo que cambia entre los dos
/// lo dice `EditExpenseModel.mode`. Sin lógica propia — refleja
/// `EditExpenseModel`.
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
                    // Los ingresos también se categorizan (ADR-0040) — con su
                    // propio catálogo, no con el de gastos.
                    categoryPicker
                    subcategoryPicker
                }

                Section {
                    HStack {
                        Text("Monto")
                            .foregroundStyle(lana.ink)
                        Spacer()
                        TextField("0", value: $model.amount, format: .number)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                    }
                    DatePicker("Fecha", selection: $model.date, displayedComponents: .date)
                    if model.kind == .expense {
                        paymentMethodPicker
                    }
                }

                if model.kind == .expense, !model.sharedLists.isEmpty {
                    sharedListSection
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.attention)
                }

                // Nada que borrar en un registro que todavía no existe —
                // cancelar la hoja ya cubre "mejor no".
                if model.mode == .editing {
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
            }
            .task { await model.onAppear() }
            .navigationTitle(model.mode == .creating ? "Nuevo" : "Editar")
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
                        .disabled(model.isSaving || !model.canSave)
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }

    /// Una opción por tarjeta, no dos — el tipo (crédito/débito) ya es fijo
    /// en `Card.kind`, no algo que se elige por transacción (mismo criterio
    /// que `DraftCard.paymentMethodPicker` en `EntryFeature`). Sin opción de
    /// "sin especificar": no habría forma honesta de guardarla — ver
    /// `EditExpenseModel.paymentMethod`.
    private var paymentMethodPicker: some View {
        Picker("Método de pago", selection: $model.paymentMethod) {
            Text("Efectivo").tag(PaymentMethod.cash)
            Text("Transferencia").tag(PaymentMethod.transfer)
            ForEach(model.cards) { card in
                Text(card.alias)
                    .tag(card.kind == .credit ? PaymentMethod.credit(cardID: card.id) : .debit(cardID: card.id))
            }
            // La tarjeta con la que se pagó ya no existe. Se puede ver y
            // conservar; si el usuario elige otra cosa, se pierde — que es
            // justo lo que quiere quien viene a corregirla.
            if let orphaned = model.orphanedCardPaymentMethod {
                Text("Tarjeta eliminada").tag(orphaned)
            }
        }
    }

    private var categoryPicker: some View {
        CategoryPicker(kind: model.kind, category: $model.category)
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

    /// Mover el gasto entre personal y una lista compartida sin borrarlo ni
    /// recapturarlo (ADR-0027), y elegir cómo se divide (ADR-0030). Solo se
    /// ofrecen las reglas que la lista resuelve sola con lo que ya sabe;
    /// `.percentage`/`.exactAmounts` piden un número por participante y se
    /// capturan en el formulario completo de Compartido — este editor lo
    /// comparte Tarjetas, que no tiene nada que hacer con eso.
    private var sharedListSection: some View {
        Section {
            Picker("Lista", selection: $model.sharedListID) {
                Text("Personal").tag(SharedListID?.none)
                ForEach(model.sharedLists) { list in
                    Text(list.name).tag(SharedListID?.some(list.id))
                }
            }
            .onChange(of: model.sharedListID) { _, _ in
                model.sharedListChanged()
            }

            if model.sharedListID != nil {
                Picker("Pagó", selection: $model.payer) {
                    ForEach(model.participantsOfSelectedList) { participant in
                        Text(model.displayName(for: participant.id)).tag(ParticipantID?.some(participant.id))
                    }
                }
                splitBreakdown
            }
        } header: {
            Text("Compartido")
        } footer: {
            Text(model.sharedListID == nil
                ? "Este gasto cuenta completo como tuyo. Muévelo a una lista para dividirlo con alguien más."
                : "En tu Dashboard solo cuenta la parte que te toca. Ajusta cómo se divide desde la lista.")
        }
    }

    /// Cómo queda repartido el gasto, con el monto y la regla vigentes del
    /// formulario (ADR-0029). Sin esto, el editor decía a qué lista va y
    /// quién pagó, pero no cuánto acaba tocándole a cada quien — que es
    /// justo el número que el Dashboard suma y el que el usuario venía a
    /// entender.
    @ViewBuilder
    private var splitBreakdown: some View {
        if model.effectiveSplit != nil {
            Picker("División", selection: $model.selectedSplitKind) {
                ForEach(model.selectableSplitKinds) { kind in
                    Text(kind.displayName).tag(SplitRuleKind?.some(kind))
                }
            }
            ForEach(model.splitShares) { share in
                LabeledContent {
                    Text(share.amount.formatted())
                        .monospacedDigit()
                } label: {
                    HStack(spacing: Space.xs.rawValue) {
                        Text(model.displayName(for: share.participant))
                        if share.isPayer {
                            Text("pagó")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.ink50)
                        }
                    }
                }
            }
        }
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
                vocabularyStore: InMemoryCorrectionVocabularyStore(),
                cardStore: InMemoryCardStore(),
                sharedListStore: InMemorySharedListStore()),
            onDone: {})
            .lanaTheme(theme)
    }
}
