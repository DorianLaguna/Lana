import LanaCore
import LanaDesign
import SwiftUI

/// El preview del parseo, editable inline (Docs/PLAN.md → Fase 5: "Edición
/// inline antes de guardar"). Un `Binding` porque la vista no decide nada —
/// solo refleja y edita lo que `EntryModel` ya resolvió. `kind` y
/// `paymentMethod` son editables aquí — antes eran de solo lectura, lo que
/// no dejaba corregir un ingreso mal detectado como gasto ni elegir con qué
/// se pagó.
public struct DraftCard: View {
    @Environment(\.lana) private var lana
    @Binding private var draft: DraftTransaction
    private let cards: [Card]
    private let allSubcategories: [String: [String]]
    @State private var isEnteringCustomSubcategory = false

    public init(draft: Binding<DraftTransaction>, cards: [Card], allSubcategories: [String: [String]] = [:]) {
        _draft = draft
        self.cards = cards
        self.allSubcategories = allSubcategories
    }

    public var body: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                HStack {
                    Picker("", selection: $draft.kind) {
                        Text("Gasto").tag(Expense.Kind.expense)
                        Text("Ingreso").tag(Expense.Kind.income)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()

                    Spacer()

                    if draft.needsReview {
                        Label("Revisar", systemImage: "exclamationmark.circle")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.warning)
                    }
                }

                HStack {
                    Text("$")
                        .lanaFont(.largeAmount)
                        .foregroundStyle(lana.textSecondary)
                    TextField("0", value: $draft.amount, format: .number)
                        .lanaFont(.largeAmount)
                        .foregroundStyle(draft.kind == .income ? lana.positive : lana.textPrimary)
                        .monospacedDigit()
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                }

                LanaTextField("Concepto", text: $draft.concept)
                if draft.kind == .expense {
                    categoryPicker
                    subcategoryPicker
                }

                DatePicker("Fecha", selection: $draft.date, displayedComponents: .date)
                    .lanaFont(.body)
                    .foregroundStyle(lana.textPrimary)

                if draft.kind == .expense {
                    paymentMethodPicker
                }
            }
        }
    }

    /// Dropdown, no texto libre — pedido explícito del usuario, mismo
    /// patrón que ya usan `AddRecurringItemView`/`EditExpenseView`. Antes
    /// se dejó como texto libre a propósito para no frenar una captura por
    /// voz rápida, pero aquí ya no se está dictando, se está revisando —
    /// el usuario ya tiene el teclado en la mano si va a tocar algo.
    private var categoryPicker: some View {
        Picker("Categoría", selection: $draft.category) {
            ForEach(SuggestedCategory.allCases) { category in
                Text(category.displayName).tag(category.rawValue)
            }
        }
        .lanaFont(.body)
        .foregroundStyle(lana.textPrimary)
    }

    /// Sin opción "Automático" — antes mostraba ese texto literal aunque el
    /// parser sí hubiera resuelto algo, así que no había forma de saber si
    /// de verdad detectó una subcategoría o la dejó vacía (pedido explícito
    /// del usuario: "cuando lo cheque no tenga que decir automático, si no
    /// la subcategoria a la que pertenece ya"). Ahora la selección refleja
    /// el valor real de `draft.subcategory` directamente (capitalizado),
    /// esté ya en el historial o recién propuesto por el parser — la única
    /// opción con texto especial es "Otra…", para escribir una que nunca
    /// se ha usado.
    private var subcategoryPicker: some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            Picker("Subcategoría", selection: subcategorySelection) {
                Text("Sin subcategoría").tag(SubcategorySelection.none)
                ForEach(subcategoryOptions, id: \.self) { subcategory in
                    Text(subcategory.capitalized).tag(SubcategorySelection.existing(subcategory))
                }
                Text("Otra…").tag(SubcategorySelection.custom)
            }
            .lanaFont(.body)
            .foregroundStyle(lana.textPrimary)

            if isEnteringCustomSubcategory {
                LanaTextField("Nombre de la subcategoría", text: $draft.subcategory)
            }
        }
    }

    private enum SubcategorySelection: Hashable {
        case none
        case existing(String)
        case custom
    }

    /// El historial de la categoría, más el valor actual si el parser
    /// propuso algo que todavía no está en ese historial (p. ej. la
    /// primera vez que se usa "mamá" en regalos) — así se ve de inmediato,
    /// en vez de perderse hasta la siguiente vez que se use.
    private var subcategoryOptions: [String] {
        var options = Set(allSubcategories[draft.category] ?? [])
        if !draft.subcategory.isEmpty, !isEnteringCustomSubcategory {
            options.insert(draft.subcategory)
        }
        return options.sorted()
    }

    private var subcategorySelection: Binding<SubcategorySelection> {
        Binding(
            get: {
                if isEnteringCustomSubcategory {
                    return .custom
                }
                if draft.subcategory.isEmpty {
                    return .none
                }
                return .existing(draft.subcategory)
            },
            set: { selection in
                switch selection {
                case .none:
                    isEnteringCustomSubcategory = false
                    draft.subcategory = ""
                case let .existing(name):
                    isEnteringCustomSubcategory = false
                    draft.subcategory = name
                case .custom:
                    isEnteringCustomSubcategory = true
                    draft.subcategory = ""
                }
            })
    }

    /// Una opción por tarjeta, no dos — el tipo (crédito/débito) ya es fijo
    /// en `Card.kind`, no algo que se elige por transacción.
    private var paymentMethodPicker: some View {
        Picker("Método de pago", selection: $draft.paymentMethod) {
            Text("Efectivo").tag(PaymentMethod.cash)
            Text("Transferencia").tag(PaymentMethod.transfer)
            ForEach(cards) { card in
                Text(card.alias)
                    .tag(card.kind == .credit ? PaymentMethod.credit(cardID: card.id) : .debit(cardID: card.id))
            }
        }
        .lanaFont(.body)
        .foregroundStyle(lana.textPrimary)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                DraftCard(
                    draft: .constant(DraftTransaction(
                        amount: 131,
                        concept: "Dulces",
                        category: "despensa",
                        needsReview: true)),
                    cards: [])
                    .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}
