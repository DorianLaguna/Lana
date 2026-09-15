import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// Captura manual de un gasto compartido — pagador + regla de división de
/// un segmented control con las 5 opciones de `SplitRule`, con
/// previsualización de cuánto le toca a cada quien vía
/// `SplitRule.portions(of:)` antes de guardar. Sin lenguaje natural
/// todavía (v1: el picker manual alcanza para el riesgo de este bloque).
public struct SharedExpenseCaptureView: View {
    /// `decimalPad` no tiene tecla de retorno — sin resignar el foco a
    /// mano antes de guardar, un monto recién tecleado puede no haber
    /// llegado todavía al binding de `Decimal` (los `TextField` con
    /// `format:` solo confirman el texto al perder el foco, no tecla por
    /// tecla) y el split truena en silencio ("no se pudo guardar" aunque
    /// se haya llenado todo bien).
    private enum FocusedField: Hashable {
        case amount
        case share(ParticipantID)
    }

    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusedField?
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

    /// Deriva el `SplitRuleKind` del picker y las `shares` a precargar de un
    /// `SplitRule` ya guardado — lo opuesto de `splitRule`. Para
    /// `.proportional`/`.percentage`/`.exactAmounts`, lo que se precarga son
    /// las fracciones/montos ya resueltos que quedaron en el evento, no los
    /// números crudos que se hayan escrito originalmente (ADR-0007: el
    /// split se congela resuelto) — se pueden editar igual, solo que no son
    /// literalmente lo que se tecleó la primera vez.
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
            Form {
                Section {
                    HStack {
                        Text("Monto")
                        Spacer()
                        TextField("0", value: $amount, format: .number)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .amount)
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                    }
                    LanaTextField("Concepto", text: $concept)
                        .onChange(of: concept) { _, newValue in
                            scheduleSuggestion(for: newValue)
                        }
                    Picker("Categoría", selection: $category) {
                        ForEach(SuggestedCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    LanaTextField("Subcategoría (opcional)", text: $subcategory)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    Picker("Pagó", selection: $payer) {
                        ForEach(model.list.participants) { participant in
                            Text(model.displayName(for: participant.id)).tag(participant.id)
                        }
                    }
                }

                Section {
                    // Sin `.pickerStyle(.segmented)` a propósito — con 5
                    // opciones y nombres parecidos, el segmented control
                    // truncaba el texto y no se alcanzaba a leer cuál era
                    // cuál. El estilo default (fila con el valor actual +
                    // lista completa al tocar) sí muestra el nombre entero.
                    Picker("División", selection: $ruleKind) {
                        ForEach(SplitRuleKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    Text(ruleKind.helpText)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.ink50)

                    if ruleKind.needsPerParticipantInput {
                        ForEach(model.list.participants) { participant in
                            HStack {
                                Text(model.displayName(for: participant.id))
                                Spacer()
                                TextField(
                                    ruleKind.fieldPlaceholder,
                                    value: shareBinding(for: participant.id),
                                    format: .number)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.trailing)
                                    .focused($focusedField, equals: .share(participant.id))
                                #if os(iOS)
                                    .keyboardType(.decimalPad)
                                #endif
                            }
                        }
                    }

                    preview
                }

                if existingExpense != nil {
                    Section {
                        // Sacar un gasto de la lista sin borrarlo — el caso
                        // real que lo hizo necesario: la detección por voz
                        // mandó gastos personales aquí por error (ADR-0027),
                        // y borrarlos habría sido perder el gasto, no
                        // corregirlo. Deja de contar en los saldos entre
                        // personas y pasa a valer completo en el Dashboard.
                        Button("Quitar de esta lista") {
                            Task { await convertToPersonal() }
                        }
                        Button("Borrar gasto", role: .destructive) {
                            Task { await delete() }
                        }
                    } footer: {
                        Text("«Quitar de esta lista» conserva el gasto como personal — no lo borra.")
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.attention)
                }
            }
            .navigationTitle(existingExpense == nil ? "Gasto compartido" : "Editar gasto")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            // Sin esto, tocar "Guardar" con el teclado
                            // numérico todavía abierto puede dejar el
                            // último dígito tecleado sin confirmar en el
                            // binding — ver el doc comment de `FocusedField`.
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
        .presentationDragIndicator(.visible)
    }
}

/// Helpers separados del `body` a propósito — con todo en un solo bloque,
/// el type-checker/`type_body_length` de swiftlint se ponían al límite
/// (mismo espíritu que ya documenta `DaySectionListView.row(for:)`).
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

    private func shareBinding(for participant: ParticipantID) -> Binding<Decimal> {
        Binding(
            get: { shares[participant] ?? 0 },
            set: { shares[participant] = $0 })
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

    @ViewBuilder
    private var preview: some View {
        if let splitRule, let portions = try? splitRule.portions(of: Money(amount: amount, currency: .mxn)) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(model.list.participants) { participant in
                    if let portion = portions[participant.id] {
                        HStack {
                            Text(participant.displayName)
                            Spacer()
                            Text(portion.formatted())
                                .monospacedDigit()
                        }
                        .lanaFont(.caption)
                        .foregroundStyle(lana.ink50)
                    }
                }
            }
        } else if let splitRule, amount > 0 {
            Text(previewError(for: splitRule))
                .lanaFont(.caption)
                .foregroundStyle(lana.attention)
        }
    }

    private func previewError(for splitRule: SplitRule) -> String {
        do {
            _ = try splitRule.portions(of: Money(amount: amount, currency: .mxn))
            return ""
        } catch {
            return error.localizedDescription
        }
    }

    private func save() async {
        guard let splitRule else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        guard (try? splitRule.portions(of: Money(amount: amount, currency: .mxn))) != nil else {
            errorMessage = previewError(for: splitRule)
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
