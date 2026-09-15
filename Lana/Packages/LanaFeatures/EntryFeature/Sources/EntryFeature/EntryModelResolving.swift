import Foundation
import LanaCore

/// Los helpers puros de `EntryModel`: resolver texto contra los datos
/// reales del usuario y precargar lo que `onAppear()` necesita. Viven
/// aparte porque no tocan estado — el modelo se quedó con la máquina de
/// estados, que es lo que hay que leer para entender la captura.
extension EntryModel {
    /// Mismo patrón que `DashboardModel.loadViewerIdentities(for:from:)`
    /// (DashboardFeature) — copia local a propósito, las features no se
    /// importan entre sí (Docs/ARCHITECTURE.md).
    static func loadViewerIdentities(
        for lists: [SharedList],
        from sharedListStore: any SharedListStore) async -> [SharedListID: ParticipantID] {
        var result: [SharedListID: ParticipantID] = [:]
        for list in lists {
            if let viewerID = try? await sharedListStore.viewerParticipantID(for: list.id) {
                result[list.id] = viewerID
            }
        }
        return result
    }

    /// Rango amplio (2 años), no acotado al mes vigente — se ofrecen todas
    /// las subcategorías que el usuario ya ha usado alguna vez, filtradas y
    /// agrupadas por categoría del lado del cliente (sin protocolo nuevo).
    static func loadSubcategories(from store: any ExpenseStore) async -> [String: [String]] {
        guard let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) else { return [:] }
        guard let expenses = try? await store.expenses(in: DateInterval(start: start, end: Date())) else {
            return [:]
        }
        var bySubcategory: [String: Set<String>] = [:]
        for expense in expenses {
            guard let category = expense.category, let subcategory = expense.subcategory, !subcategory.isEmpty else {
                continue
            }
            bySubcategory[category, default: []].insert(subcategory)
        }
        return bySubcategory.mapValues { $0.sorted() }
    }

    /// El tipo de tarjeta ya no se adivina de la frase — se fija al dar de
    /// alta o editar la tarjeta (`Card.kind`). Si el texto mencionó una
    /// tarjeta real por alias, esa tarjeta manda: decir "con la tarjeta
    /// Banamex" sin decir "crédito" ya no pierde la tarjeta, que era el bug
    /// real. `paymentMethodHint` solo importa cuando no se resolvió ninguna
    /// tarjeta — para no inventar una, cae a efectivo (el usuario lo
    /// corrige a mano si hacía falta; `DraftCard` deja editar esto).
    static func resolvePaymentMethod(
        hint: PaymentMethodHint?,
        cardAlias: String?,
        cards: [Card]) -> PaymentMethod {
        if let card = resolveCard(aliasHint: cardAlias, in: cards) {
            return card.kind == .credit ? .credit(cardID: card.id) : .debit(cardID: card.id)
        }
        return hint == .transfer ? .transfer : .cash
    }

    static func resolveCard(aliasHint: String?, in cards: [Card]) -> Card? {
        guard let aliasHint else { return nil }
        let normalizedHint = aliasHint.lowercased()
        if let exact = cards.first(where: { $0.alias.lowercased() == normalizedHint }) {
            return exact
        }
        return cards.first { card in
            let normalizedAlias = card.alias.lowercased()
            return normalizedHint.contains(normalizedAlias) || normalizedAlias.contains(normalizedHint)
        }
    }
}
