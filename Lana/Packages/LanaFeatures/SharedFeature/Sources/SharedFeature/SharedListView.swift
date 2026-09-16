import LanaCore
import LanaDesign
import SwiftUI

/// La pestaña Gente (rediseño, sección 06): quién te debe, a quién le debes, y
/// cómo saldarlo. Se llama Gente porque es de personas, no de listas.
public struct SharedListView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: SharedListModel
    @State private var createModel: CreateSharedListModel?
    @State private var listPendingDelete: SharedList?
    @State private var settling: SettlementTarget?
    /// La navegación se maneja con un path propio y no con
    /// `NavigationLink(value:)`: la tarjeta de una lista trae sus propios
    /// botones ("Liquidar") y un link se los tragaría.
    @State private var path: [SharedListID] = []

    public init(model: SharedListModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.lists.isEmpty, !model.isLoading {
                        emptyState
                    } else {
                        balanceSection
                            .padding(.bottom, Space.p30.rawValue)
                        listCards
                        newListRow
                            .padding(.top, Space.p14.rawValue)
                    }
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.sm.rawValue)
                .tabBarClearance()
            }
            .background(lana.bg)
            .navigationTitle("Gente")
            .lanaInlineNavigationTitle()
            .navigationDestination(for: SharedListID.self) { listID in
                if let list = model.lists.first(where: { $0.id == listID }) {
                    SharedListDetailView(model: model.makeDetailModel(for: list))
                }
            }
            .sheet(item: $createModel) { createModel in
                CreateSharedListView(model: createModel, onDone: {
                    self.createModel = nil
                    Task { await model.onAppear() }
                })
            }
            .sheet(item: $settling) { target in
                SettleUpView(
                    model: model.makeDetailModel(for: target.list),
                    debt: target.debt,
                    onDone: {
                        settling = nil
                        Task { await model.onAppear() }
                    })
            }
            .confirmationDialog(
                "¿Borrar \(listPendingDelete?.name ?? "esta lista")? Se borra también su historial.",
                isPresented: isDeletingBinding,
                titleVisibility: .visible) {
                    Button("Borrar", role: .destructive) {
                        if let list = listPendingDelete {
                            Task { await model.delete(list) }
                        }
                        listPendingDelete = nil
                    }
            }
        }
        .task { await model.onAppear() }
        .refreshable { await model.onAppear() }
    }

    // MARK: - Saldo propio

    /// "Te deben" en `positive`; "Debes" en tinta normal, nunca en rojo — deber
    /// dinero es un dato, no una falta.
    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            if let balance = model.netBalance.first {
                Text(balance.amount > 0 ? "Te deben" : "Debes")
                    .lanaFont(.footnote)
                    .foregroundStyle(lana.ink50)
                Text(Money(amount: abs(balance.amount), currency: balance.currency).formatted())
                    .lanaFont(.totalAmount)
                    .foregroundStyle(balance.amount > 0 ? lana.positive : lana.ink)
                    .contentTransition(.numericText())
            } else {
                Text("Todo saldado")
                    .lanaFont(.blockAmount)
                    .foregroundStyle(lana.ink70)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Listas

    private var listCards: some View {
        VStack(spacing: Space.p14.rawValue) {
            ForEach(model.lists) { list in
                SharedListCard(
                    list: list,
                    expenseCount: model.expenseCountByList[list.id] ?? 0,
                    debts: model.debtsInvolvingViewer(in: list),
                    viewerID: model.viewerIdentities[list.id],
                    name: { model.displayName(for: $0, in: list) },
                    onOpen: { openList(list) },
                    onSettle: { debt in settling = SettlementTarget(list: list, debt: debt) })
                    .contextMenu {
                        Button("Borrar", role: .destructive) { listPendingDelete = list }
                    }
            }
        }
    }

    private func openList(_ list: SharedList) {
        path.append(list.id)
    }

    private var newListRow: some View {
        Button {
            createModel = model.makeCreateModel()
        } label: {
            HStack(spacing: Space.p6.rawValue) {
                Text("+")
                    .lanaFont(.pushTitle)
                    .foregroundStyle(lana.accent)
                Text("Nueva lista compartida")
                    .lanaFont(.bodyEmphasis)
                    .foregroundStyle(lana.ink50)
                Spacer()
            }
            .padding(Space.md.rawValue)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card.rawValue, style: .continuous)
                    .strokeBorder(lana.dashedBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "person.2",
            title: "Aún no compartes gastos",
            message: "Crea una lista para repartir la renta, un viaje o el súper.",
            actionTitle: "Crear una lista",
            action: { createModel = model.makeCreateModel() })
            .padding(.top, Space.xxl.rawValue)
    }

    private var isDeletingBinding: Binding<Bool> {
        Binding(
            get: { listPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    listPendingDelete = nil
                }
            })
    }
}

/// La lista a la que pertenece una deuda — `Debt` no dice de cuál lista es.
private struct SettlementTarget: Identifiable {
    let list: SharedList
    let debt: Debt

    var id: String {
        "\(list.id.rawValue)-\(debt.from.rawValue)-\(debt.to.rawValue)"
    }
}

/// Una lista con sus avatares, cuántos gastos lleva y, abajo, quién le debe a
/// quién con su botón de liquidar.
private struct SharedListCard: View {
    @Environment(\.lana) private var lana
    let list: SharedList
    let expenseCount: Int
    let debts: [Debt]
    let viewerID: ParticipantID?
    let name: (ParticipantID) -> String
    let onOpen: () -> Void
    let onSettle: (Debt) -> Void

    var body: some View {
        LanaCard(padding: .p18, radius: .cardLarge) {
            VStack(alignment: .leading, spacing: Space.md.rawValue) {
                Button(action: onOpen) {
                    HStack(spacing: Space.p10.rawValue) {
                        avatars
                        Text(list.name)
                            .lanaFont(.pushTitle)
                            .foregroundStyle(lana.ink)
                        Spacer(minLength: Space.sm.rawValue)
                        Text(expenseCount == 1 ? "1 gasto" : "\(expenseCount) gastos")
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.ink42)
                        RowChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if debts.isEmpty {
                    Text("Todo saldado")
                        .lanaFont(.callout)
                        .foregroundStyle(lana.ink42)
                } else {
                    ForEach(debts, id: \.self) { debt in
                        debtRow(debt)
                    }
                }
            }
        }
    }

    private var avatars: some View {
        HStack(spacing: LanaMetrics.avatarOverlap) {
            ForEach(list.participants.prefix(3)) { participant in
                InitialAvatar(
                    name: name(participant.id),
                    diameter: LanaMetrics.avatarStacked,
                    isRaised: true)
                    .overlay(Circle().strokeBorder(lana.surface, lineWidth: LanaMetrics.outline))
            }
        }
        .accessibilityHidden(true)
    }

    private func debtRow(_ debt: Debt) -> some View {
        HStack(spacing: Space.p10.rawValue) {
            Text(debtDescription(debt))
                .lanaFont(.callout)
                .foregroundStyle(lana.ink70)
            Spacer(minLength: Space.sm.rawValue)
            Text(debt.amount.formatted())
                .lanaFont(.rowAmount)
                .fontWeight(.semibold)
                .foregroundStyle(debt.to == viewerID ? lana.positive : lana.ink)
            Button("Liquidar") { onSettle(debt) }
                .buttonStyle(.lana(size: .compact))
        }
        .padding(.vertical, Space.p12.rawValue)
        .padding(.horizontal, Space.p14.rawValue)
        .background(lana.bg, in: RoundedRectangle(cornerRadius: Radius.block.rawValue, style: .continuous))
    }

    /// "Renata te debe" / "Le debes a Renata" — siempre desde tu lado.
    private func debtDescription(_ debt: Debt) -> String {
        if debt.to == viewerID {
            return "\(name(debt.from)) te debe"
        }
        if debt.from == viewerID {
            return "Le debes a \(name(debt.to))"
        }
        return "\(name(debt.from)) le debe a \(name(debt.to))"
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        SharedListView(model: SharedListModel(
            sharedListStore: InMemorySharedListStore(seed: [
                SharedList(
                    name: "Baby",
                    participants: [Participant(displayName: "Dorian"), Participant(displayName: "Renata")],
                    defaultSplit: .equally(among: []))
            ]),
            expenseStore: InMemoryExpenseStore(),
            parser: InMemoryExpenseParsing()))
            .lanaTheme(theme)
    }
}
