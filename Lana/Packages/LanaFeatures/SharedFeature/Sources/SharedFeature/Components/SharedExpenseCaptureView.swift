import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// Captura manual de un gasto compartido: la misma tarjeta de borrador que la
/// captura personal —concepto y monto arriba, lo demás en chips— más la regla
/// de división, lo único propio de Compartido. Sin lenguaje natural todavía.
public struct SharedExpenseCaptureView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: SharedCaptureField?
    private let model: SharedListDetailModel
    /// `nil` = capturar uno nuevo. Con valor = editando este — mismo
    /// formulario, `save()` corrige en vez de crear, y aparece "Borrar".
    private let existingExpense: Expense?
    private let onDone: () -> Void

    @State private var amount: Decimal = 0
    @State private var concept = ""
    @State private var category: SuggestedCategory = .otro
    @State private var subcategory = ""
    @State private var date = Date()
    @State private var payer: ParticipantID
    @State private var ruleKind: SplitRuleKind = .equally
    @State private var shares: [ParticipantID: Decimal] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showsDatePicker = false
    @State private var isConfirmingDelete = false
    /// Se cancela y se vuelve a armar en cada tecleo — evita mandar una
    /// sugerencia al modelo por cada letra (Docs/.claude/skills/foundation-models).
    @State private var suggestionTask: Task<Void, Never>?

    public init(model: SharedListDetailModel, existingExpense: Expense? = nil, onDone: @escaping () -> Void) {
        self.model = model
        self.existingExpense = existingExpense
        self.onDone = onDone
        guard let existingExpense else {
            // Un gasto nuevo arranca con el pagador puesto en "yo" cuando la
            // identidad ya está marcada (ADR-0022) — es quien captura, el
            // caso abrumadoramente común — y con la división proporcional ya
            // resuelta de los ingresos de la lista si están capturados
            // (ADR-0028), en vez de obligar a teclear la proporción cada vez.
            _payer = State(
                initialValue: model.viewerParticipantID ?? model.list.participants.first?.id ?? ParticipantID())
            let (kind, initialShares) = Self.ruleKind(for: model.list.preferredSplit)
            _ruleKind = State(initialValue: kind)
            _shares = State(initialValue: initialShares)
            return
        }
        _amount = State(initialValue: existingExpense.amount.amount)
        _concept = State(initialValue: existingExpense.concept)
        _category = State(initialValue: existingExpense.category.flatMap(SuggestedCategory.init(rawValue:)) ?? .otro)
        _subcategory = State(initialValue: existingExpense.subcategory ?? "")
        _date = State(initialValue: existingExpense.date)
        _payer = State(
            initialValue: existingExpense.payer ?? model.list.participants.first?.id ?? ParticipantID())
        let (kind, initialShares) = Self.ruleKind(for: existingExpense.split)
        _ruleKind = State(initialValue: kind)
        _shares = State(initialValue: initialShares)
    }

    /// Deriva el `SplitRuleKind` de los chips y las `shares` a precargar de un
    /// `SplitRule` ya guardado — lo opuesto de `splitRule`. Lo que se precarga
    /// son las fracciones ya resueltas que quedaron en el evento (ADR-0007: el
    /// split se congela resuelto), no los números crudos que se teclearon.
    private static func ruleKind(for split: SplitRule?) -> (SplitRuleKind, [ParticipantID: Decimal]) {
        switch split {
        case .equally, nil:
            (.equally, [:])
        case .payerOnly:
            (.payerOnly, [:])
        case let .proportional(shares):
            (.proportional, shares)
        case let .percentage(shares):
            (.percentage, shares)
        case let .exactAmounts(amounts):
            (.exactAmounts, amounts)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headline
                        .padding(.bottom, Space.p18.rawValue)

                    FlowLayout {
                        categoryChip
                        dateChip
                        payerChip
                    }

                    LanaTextField("Subcategoría (opcional)", text: $subcategory)
                        .padding(.top, Space.p12.rawValue)

                    SharedExpenseSplitSection(
                        focusedField: $focusedField,
                        ruleKind: $ruleKind,
                        shares: $shares,
                        participants: model.list.participants,
                        displayName: { model.displayName(for: $0) },
                        splitRule: splitRule,
                        amount: amount)
                        .padding(.top, Space.p22.rawValue)

                    if let errorMessage {
                        Text(errorMessage)
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.attention)
                            .padding(.top, Space.p12.rawValue)
                    }

                    if existingExpense != nil {
                        removalSection
                            .padding(.top, Space.p30.rawValue)
                    }
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.p18.rawValue)
                .padding(.bottom, Space.p40.rawValue)
            }
            .background(lana.bg)
            .navigationTitle(existingExpense == nil ? "Gasto compartido" : "Editar gasto")
            .lanaInlineNavigationTitle()
            .toolbar { toolbarContent }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                // Sin esto, tocar "Guardar" con el teclado numérico todavía
                // abierto puede dejar el último dígito tecleado sin confirmar
                // en el binding — ver el doc comment de `SharedCaptureField`.
                focusedField = nil
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Guardar")
                }
            }
            .disabled(isSaving || splitRule == nil)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Listo") { focusedField = nil }
        }
    }
}

// MARK: - Concepto, monto y chips

extension SharedExpenseCaptureView {
    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
            TextField("Concepto", text: $concept)
                .lanaFont(.rowTitle)
                .foregroundStyle(lana.ink)
                .onChange(of: concept) { _, newValue in
                    scheduleSuggestion(for: newValue)
                }

            HStack(alignment: .firstTextBaseline, spacing: Space.p2.rawValue) {
                Text("$")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                TextField("0", value: $amount, format: .number)
                    .lanaFont(.draftAmount)
                    .foregroundStyle(lana.ink)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .focused($focusedField, equals: .amount)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
            }
        }
    }

    private var categoryChip: some View {
        Menu {
            ForEach(SuggestedCategory.allCases) { category in
                Button(category.displayName) { self.category = category }
            }
        } label: {
            Chip(category.displayName)
        }
        .accessibilityLabel("Categoría: \(category.displayName)")
    }

    private var dateChip: some View {
        Button {
            showsDatePicker = true
        } label: {
            Chip(LanaDateFormat.dayLabel(date))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fecha: \(LanaDateFormat.dayLabel(date))")
    }

    private var payerChip: some View {
        Menu {
            ForEach(model.list.participants) { participant in
                Button(model.displayName(for: participant.id)) { payer = participant.id }
            }
        } label: {
            Chip("Pagó \(model.displayName(for: payer))")
        }
        .accessibilityLabel("Pagó \(model.displayName(for: payer))")
    }

    private var datePickerSheet: some View {
        VStack(spacing: Space.md.rawValue) {
            DatePicker("Fecha", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(lana.accentFill)
            Button("Listo") { showsDatePicker = false }
                .buttonStyle(.lana(size: .large, isExpanded: true))
        }
        .padding(Space.md.rawValue)
        .background(lana.surface)
        .presentationDetents([.medium])
    }

    /// Sacar un gasto de la lista sin borrarlo — el caso real que lo hizo
    /// necesario: la detección por voz mandó gastos personales aquí por error
    /// (ADR-0027), y borrarlos habría sido perder el gasto, no corregirlo.
    /// Deja de contar en los saldos entre personas y pasa a valer completo en
    /// el Dashboard.
    private var removalSection: some View {
        VStack(alignment: .leading, spacing: Space.p12.rawValue) {
            Button("Quitar de esta lista") {
                Task { await convertToPersonal() }
            }
            .buttonStyle(.lana(.secondary, isExpanded: true))
            .disabled(isSaving)

            Text("«Quitar de esta lista» conserva el gasto como personal — no lo borra.")
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
                .fixedSize(horizontal: false, vertical: true)

            // El rojo lo pone el sistema, en el diálogo: la app no lo usa por
            // su cuenta (ADR-0044).
            Button("Borrar gasto", role: .destructive) {
                isConfirmingDelete = true
            }
            .lanaFont(.bodyEmphasis)
            .frame(maxWidth: .infinity)
            .frame(minHeight: LanaMetrics.minTouchTarget)
            .disabled(isSaving)
            .confirmationDialog(
                "¿Borrar este gasto?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible) {
                    Button("Borrar", role: .destructive) {
                        Task { await delete() }
                    }
            }
        }
    }
}

// MARK: - Guardar, borrar y sugerir

extension SharedExpenseCaptureView {
    /// Sugiere categoría/subcategoría del concepto escrito, con el mismo
    /// parser que la captura personal — nunca bloquea guardar, solo
    /// prellena. Si el usuario ya eligió categoría a mano (se alejó de
    /// `.otro`, el default) o ya escribió una subcategoría, no la
    /// sobrescribe: la sugerencia solo llena lo que sigue vacío.
    private func scheduleSuggestion(for concept: String) {
        suggestionTask?.cancel()
        suggestionTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let result = await model.suggestCategory(for: concept) else { return }
            if category == .otro, let categoryRaw = result.category,
               let suggested = SuggestedCategory(rawValue: categoryRaw) {
                category = suggested
            }
            if subcategory.isEmpty, let suggestedSubcategory = result.subcategory {
                subcategory = suggestedSubcategory
            }
        }
    }

    /// `nil` cuando la regla no valida — `SplitRule.portions(of:)` es la
    /// única fuente de verdad de si un split cierra, no se reimplementa
    /// aquí (porcentajes que suman 100, montos exactos que suman el total).
    /// La única excepción es `.proportional`: ver `ProportionalShares`.
    private var splitRule: SplitRule? {
        let participantIDs = model.list.participants.map(\.id)
        switch ruleKind {
        case .equally:
            return .equally(among: participantIDs)
        case .payerOnly:
            return .payerOnly
        case .proportional:
            return .proportional(shares: ProportionalShares.normalized(weights: shares, among: participantIDs))
        case .percentage:
            return .percentage(shares: shares)
        case .exactAmounts:
            return .exactAmounts(amounts: shares)
        }
    }

    private func save() async {
        guard let splitRule else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try splitRule.portions(of: Money(amount: amount, currency: .mxn))
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let saved: Bool = if let existingExpense {
            await model.updateExpense(
                id: existingExpense.id,
                amount: Money(amount: amount, currency: .mxn),
                concept: concept,
                category: category.rawValue,
                subcategory: subcategory.isEmpty ? nil : subcategory,
                date: date,
                payer: payer,
                split: splitRule)
        } else {
            await model.recordExpense(
                amount: Money(amount: amount, currency: .mxn),
                concept: concept,
                category: category.rawValue,
                subcategory: subcategory.isEmpty ? nil : subcategory,
                date: date,
                payer: payer,
                split: splitRule)
        }
        if saved {
            onDone()
        } else {
            errorMessage = "No se pudo guardar."
        }
    }

    private func delete() async {
        guard let existingExpense else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        if await model.deleteExpense(id: existingExpense.id) {
            onDone()
        } else {
            errorMessage = "No se pudo borrar."
        }
    }

    /// Saca el gasto de la lista compartida conservándolo como personal
    /// (ADR-0027). No lo borra ni lo vuelve a capturar: es una corrección
    /// sobre el mismo `id`, así que el historial queda completo.
    private func convertToPersonal() async {
        guard let existingExpense else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        if await model.convertToPersonal(id: existingExpense.id) {
            onDone()
        } else {
            errorMessage = "No se pudo quitar de la lista."
        }
    }
}

#Preview {
    let alice = Participant(displayName: "Tú")
    let bob = Participant(displayName: "Sam")
    let list = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .equally(among: [alice.id, bob.id]))
    ForEach(LanaTheme.allCases) { theme in
        SharedExpenseCaptureView(
            model: SharedListDetailModel(
                list: list,
                sharedListStore: InMemorySharedListStore(seed: [list]),
                expenseStore: InMemoryExpenseStore(),
                parser: InMemoryExpenseParsing()),
            onDone: {})
            .lanaTheme(theme)
    }
}
