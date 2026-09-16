import LanaCore
import LanaDesign
import SwiftUI

/// El formulario de un movimiento: el mismo para editar uno guardado y para
/// registrar uno a mano (ADR-0035; rediseño, sección 14).
///
/// Es la tarjeta de borrador de la captura, en blanco o con lo que ya existe:
/// concepto y monto en línea arriba, y todo lo demás como chips que abren su
/// propio selector. Sin lógica propia — refleja `EditExpenseModel`.
public struct EditExpenseView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: EditExpenseModel
    @State private var isConfirmingDelete = false
    @State private var isEnteringCustomSubcategory = false
    @State private var showsDatePicker = false
    private let onDone: () -> Void

    public init(model: EditExpenseModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headline
                        .padding(.bottom, Space.p18.rawValue)

                    FlowLayout {
                        kindChip
                        categoryChip
                        subcategoryChip
                        dateChip
                        if model.kind == .expense {
                            paymentChip
                        }
                    }

                    if isEnteringCustomSubcategory {
                        LanaTextField("Nombre de la subcategoría", text: $model.subcategory)
                            .padding(.top, Space.p12.rawValue)
                    }

                    if model.kind == .expense, !model.sharedLists.isEmpty {
                        EditExpenseSharedSection(model: model)
                            .padding(.top, Space.p22.rawValue)
                    }

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.attention)
                            .padding(.top, Space.p12.rawValue)
                    }

                    // Nada que borrar en algo que todavía no existe: cancelar
                    // la hoja ya cubre "mejor no".
                    if model.mode == .editing {
                        deleteButton
                            .padding(.top, Space.p30.rawValue)
                    }
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.p18.rawValue)
                .padding(.bottom, Space.p40.rawValue)
            }
            .background(lana.bg)
            .task { await model.onAppear() }
            .navigationTitle(model.mode == .creating ? "Nuevo" : "Editar")
            .lanaInlineNavigationTitle()
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
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
    }

    // MARK: - Concepto y monto

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
            TextField("Concepto", text: $model.concept)
                .lanaFont(.rowTitle)
                .foregroundStyle(lana.ink)

            HStack(alignment: .firstTextBaseline, spacing: Space.p2.rawValue) {
                Text("$")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                TextField("0", value: $model.amount, format: .number)
                    .lanaFont(.draftAmount)
                    .foregroundStyle(model.kind == .income ? lana.positive : lana.ink)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
            }
        }
    }

    // MARK: - Chips

    private var kindChip: some View {
        Menu {
            Button("Gasto") { model.kind = .expense }
            Button("Ingreso") { model.kind = .income }
        } label: {
            Chip(model.kind == .income ? "Ingreso" : "Gasto")
        }
        .accessibilityLabel("Tipo: \(model.kind == .income ? "ingreso" : "gasto")")
    }

    /// Los ingresos también se categorizan (ADR-0040), con su propio catálogo.
    private var categoryChip: some View {
        Menu {
            if model.kind == .expense {
                ForEach(SuggestedCategory.allCases) { category in
                    Button(category.displayName) { model.category = category.rawValue }
                }
            } else {
                ForEach(IncomeCategory.allCases) { category in
                    Button(category.displayName) { model.category = category.rawValue }
                }
            }
        } label: {
            Chip(categoryLabel, tone: model.category.isEmpty ? .doubt : .neutral)
        }
        .accessibilityLabel("Categoría: \(categoryLabel)")
    }

    private var categoryLabel: String {
        guard !model.category.isEmpty else { return "Sin categoría" }
        if model.kind == .income {
            return IncomeCategory(rawValue: model.category)?.displayName ?? model.category.capitalized
        }
        return DashboardModel.categoryDisplayName(model.category)
    }

    /// Dropdown, no texto libre; "Otra…" abre el campo para una nueva.
    private var subcategoryChip: some View {
        Menu {
            Button("Sin subcategoría") {
                isEnteringCustomSubcategory = false
                model.subcategory = ""
            }
            ForEach(subcategoryOptions, id: \.self) { subcategory in
                Button(subcategory.capitalized) {
                    isEnteringCustomSubcategory = false
                    model.subcategory = subcategory
                }
            }
            Button("Otra…") {
                isEnteringCustomSubcategory = true
                model.subcategory = ""
            }
        } label: {
            Chip(subcategoryLabel)
        }
        .accessibilityLabel("Subcategoría: \(subcategoryLabel)")
    }

    private var subcategoryLabel: String {
        guard !model.subcategory.isEmpty else { return "Sin subcategoría" }
        return "\(categoryLabel) › \(model.subcategory.capitalized)"
    }

    private var subcategoryOptions: [String] {
        var options = Set(model.allSubcategories[model.category] ?? [])
        if !model.subcategory.isEmpty, !isEnteringCustomSubcategory {
            options.insert(model.subcategory)
        }
        return options.sorted()
    }

    private var dateChip: some View {
        Button {
            showsDatePicker = true
        } label: {
            Chip(DraftDateLabel.text(for: model.date))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fecha: \(DraftDateLabel.text(for: model.date))")
    }

    private var datePickerSheet: some View {
        VStack(spacing: Space.md.rawValue) {
            DatePicker("Fecha", selection: $model.date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(lana.accentFill)
            Button("Listo") { showsDatePicker = false }
                .buttonStyle(.lana(size: .large, isExpanded: true))
        }
        .padding(Space.md.rawValue)
        .background(lana.surface)
        .presentationDetents([.medium])
    }

    /// Una opción por tarjeta: el tipo ya es fijo en `Card.kind`, no algo que
    /// se elija por movimiento. Sin "sin especificar" — no habría forma honesta
    /// de guardarla.
    private var paymentChip: some View {
        Menu {
            Button("Efectivo") { model.paymentMethod = .cash }
            Button("Transferencia") { model.paymentMethod = .transfer }
            ForEach(model.cards) { card in
                Button(card.alias) {
                    model.paymentMethod = card.kind == .credit
                        ? .credit(cardID: card.id)
                        : .debit(cardID: card.id)
                }
            }
        } label: {
            Chip(paymentLabel, tone: model.orphanedCardPaymentMethod != nil ? .doubt : .neutral)
        }
        .accessibilityLabel("Forma de pago: \(paymentLabel)")
    }

    /// La tarjeta con la que se pagó puede ya no existir: se ve y se conserva,
    /// y elegir otra cosa la reemplaza — que es a lo que viene quien la corrige.
    private var paymentLabel: String {
        if model.orphanedCardPaymentMethod != nil {
            return "Tarjeta eliminada"
        }
        switch model.paymentMethod {
        case .cash: return "Efectivo"
        case .transfer: return "Transferencia"
        case let .credit(cardID): return cardAlias(cardID, kind: "Crédito")
        case let .debit(cardID): return cardAlias(cardID, kind: "Débito")
        }
    }

    private func cardAlias(_ cardID: CardID, kind: String) -> String {
        guard let card = model.cards.first(where: { $0.id == cardID }) else { return kind }
        return "\(kind) \(card.alias)"
    }

    // MARK: - Borrar

    /// El rojo lo pone el sistema, en el diálogo: la app no lo usa por su
    /// cuenta (ADR-0044).
    private var deleteButton: some View {
        Button("Borrar este movimiento", role: .destructive) {
            isConfirmingDelete = true
        }
        .lanaFont(.bodyEmphasis)
        .frame(maxWidth: .infinity)
        .frame(minHeight: LanaMetrics.minTouchTarget)
        .disabled(model.isSaving)
        // En el botón que lo dispara, no más arriba en el árbol: colgado
        // arriba, el diálogo se desanclaba y salía hasta el tope de la pantalla.
        .confirmationDialog(
            "¿Borrar este movimiento?",
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
