import LanaCore
import LanaDesign
import SwiftUI

/// Un borrador en la revisión (rediseño, sección 08): concepto y monto
/// editables en línea, y todo lo demás como chips que abren su propio
/// selector. Va sobre `bg`, más oscuro que la hoja, no más claro.
///
/// Un `Binding` porque la vista no decide nada: refleja y edita lo que
/// `EntryModel` ya resolvió.
public struct DraftCard: View {
    @Environment(\.lana) private var lana
    @Binding private var draft: DraftTransaction
    private let cards: [Card]
    private let allSubcategories: [String: [String]]
    private let sharedLists: [SharedList]
    /// Cómo mostrar el nombre de un participante — `EntryModel` es quien sabe
    /// cuál es "yo" en cada lista, este componente no.
    private let viewerName: (ParticipantID, SharedListID) -> String
    /// `nil` cuando es el único borrador: borrarlo ya lo cubre cerrar la hoja.
    private let onDelete: (() -> Void)?
    @State private var isEnteringCustomSubcategory = false
    @State private var showsDatePicker = false

    public init(
        draft: Binding<DraftTransaction>,
        cards: [Card],
        allSubcategories: [String: [String]] = [:],
        sharedLists: [SharedList] = [],
        viewerName: @escaping (ParticipantID, SharedListID) -> String = { _, _ in "Alguien" },
        onDelete: (() -> Void)? = nil) {
        _draft = draft
        self.cards = cards
        self.allSubcategories = allSubcategories
        self.sharedLists = sharedLists
        self.viewerName = viewerName
        self.onDelete = onDelete
    }

    public var body: some View {
        LanaCard(fill: .background) {
            VStack(alignment: .leading, spacing: 0) {
                headline
                    .padding(.bottom, Space.p12.rawValue)

                FlowLayout {
                    kindChip
                    categoryChip
                    if draft.kind == .expense {
                        subcategoryChip
                    }
                    dateChip
                    if draft.kind == .expense {
                        paymentChip
                    }
                    if draft.currency != .mxn {
                        Chip(draft.currency.rawValue)
                    }
                    ForEach(draft.doubts) { doubt in
                        Chip(doubt.label, tone: .doubt)
                    }
                }

                if isEnteringCustomSubcategory {
                    LanaTextField("Nombre de la subcategoría", text: $draft.subcategory)
                        .padding(.top, Space.p10.rawValue)
                }

                if !draft.doubts.isEmpty {
                    Text("Se guarda igual y queda por revisar.")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                        .padding(.top, Space.p10.rawValue)
                }

                DraftSharedBlock(draft: $draft, sharedLists: sharedLists, viewerName: viewerName)
            }
        }
        .sheet(isPresented: $showsDatePicker) {
            datePickerSheet
        }
    }

    // MARK: - Concepto y monto

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
            TextField("Concepto", text: $draft.concept)
                .lanaFont(.rowTitle)
                .foregroundStyle(lana.ink)

            HStack(alignment: .firstTextBaseline, spacing: Space.p2.rawValue) {
                Text("$")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                TextField("0", value: $draft.amount, format: .number)
                    .lanaFont(.draftAmount)
                    .foregroundStyle(draft.kind == .income ? lana.positive : lana.ink)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
            }

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink35)
                        .frame(width: LanaMetrics.minTouchTarget / 2, height: LanaMetrics.minTouchTarget / 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quitar este movimiento")
            }
        }
    }

    // MARK: - Chips

    private var kindChip: some View {
        Menu {
            Button("Gasto") { draft.kind = .expense }
            Button("Ingreso") { draft.kind = .income }
        } label: {
            Chip(draft.kind == .income ? "Ingreso" : "Gasto")
        }
        .accessibilityLabel("Tipo: \(draft.kind == .income ? "ingreso" : "gasto")")
    }

    private var categoryChip: some View {
        Menu {
            if draft.kind == .expense {
                ForEach(SuggestedCategory.allCases) { category in
                    Button(category.displayName) { draft.category = category.rawValue }
                }
            } else {
                ForEach(IncomeCategory.allCases) { category in
                    Button(category.displayName) { draft.category = category.rawValue }
                }
            }
        } label: {
            Chip(categoryLabel, tone: draft.category.isEmpty ? .doubt : .neutral)
        }
        .accessibilityLabel("Categoría: \(categoryLabel)")
    }

    private var categoryLabel: String {
        guard !draft.category.isEmpty else { return "Sin categoría" }
        if draft.kind == .income {
            return IncomeCategory(rawValue: draft.category)?.displayName ?? draft.category.capitalized
        }
        return SuggestedCategory(rawValue: draft.category)?.displayName ?? draft.category.capitalized
    }

    /// Dropdown, no texto libre: aquí ya no se está dictando, se está
    /// revisando. "Otra…" abre el campo para una que nunca se ha usado.
    private var subcategoryChip: some View {
        Menu {
            Button("Sin subcategoría") {
                isEnteringCustomSubcategory = false
                draft.subcategory = ""
            }
            ForEach(subcategoryOptions, id: \.self) { subcategory in
                Button(subcategory.capitalized) {
                    isEnteringCustomSubcategory = false
                    draft.subcategory = subcategory
                }
            }
            Button("Otra…") {
                isEnteringCustomSubcategory = true
                draft.subcategory = ""
            }
        } label: {
            Chip(subcategoryLabel)
        }
        .accessibilityLabel("Subcategoría: \(subcategoryLabel)")
    }

    private var subcategoryLabel: String {
        guard !draft.subcategory.isEmpty else { return "Sin subcategoría" }
        return "\(categoryLabel) › \(draft.subcategory.capitalized)"
    }

    /// El historial de la categoría más lo que el parser acaba de proponer,
    /// para que se vea de inmediato y no hasta la próxima vez que se use.
    private var subcategoryOptions: [String] {
        var options = Set(allSubcategories[draft.category] ?? [])
        if !draft.subcategory.isEmpty, !isEnteringCustomSubcategory {
            options.insert(draft.subcategory)
        }
        return options.sorted()
    }

    private var dateChip: some View {
        Button {
            showsDatePicker = true
        } label: {
            Chip(Self.dateLabel(for: draft.date))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fecha: \(Self.dateLabel(for: draft.date))")
    }

    /// "Hoy", "Ayer" o "14 de septiembre" — siempre en español.
    static func dateLabel(for date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Hoy"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ayer"
        }
        let day = calendar.component(.day, from: date)
        return "\(day) de \(LanaDateFormat.monthNameLowercased(date, calendar: calendar))"
    }

    private var datePickerSheet: some View {
        VStack(spacing: Space.md.rawValue) {
            DatePicker("Fecha", selection: $draft.date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(lana.accentFill)
            Button("Listo") { showsDatePicker = false }
                .buttonStyle(.lana(size: .large, isExpanded: true))
        }
        .padding(Space.md.rawValue)
        .background(lana.surface)
        .presentationDetents([.medium])
    }

    /// Una opción por tarjeta, no dos: el tipo (crédito/débito) ya es fijo en
    /// `Card.kind`, no algo que se elija por movimiento.
    private var paymentChip: some View {
        Menu {
            Button("Efectivo") { draft.paymentMethod = .cash }
            Button("Transferencia") { draft.paymentMethod = .transfer }
            ForEach(cards) { card in
                Button(card.alias) {
                    draft.paymentMethod = card.kind == .credit
                        ? .credit(cardID: card.id)
                        : .debit(cardID: card.id)
                }
            }
        } label: {
            Chip(paymentLabel)
        }
        .accessibilityLabel("Forma de pago: \(paymentLabel)")
    }

    private var paymentLabel: String {
        switch draft.paymentMethod {
        case .cash: "Efectivo"
        case .transfer: "Transferencia"
        case let .credit(cardID): cardAlias(cardID, kind: "Crédito")
        case let .debit(cardID): cardAlias(cardID, kind: "Débito")
        }
    }

    private func cardAlias(_ cardID: CardID, kind: String) -> String {
        guard let card = cards.first(where: { $0.id == cardID }) else { return kind }
        return "\(kind) \(card.alias)"
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.p12.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                DraftCard(
                    draft: .constant(DraftTransaction(
                        amount: 300,
                        concept: "Súper",
                        category: "despensa",
                        subcategory: "súper",
                        needsReview: true)),
                    cards: [])
                    .padding(LanaMetrics.screenMargin)
                    .background(LanaColors(theme: theme, colorScheme: .dark).surface)
                    .lanaTheme(theme)
            }
        }
    }
}
