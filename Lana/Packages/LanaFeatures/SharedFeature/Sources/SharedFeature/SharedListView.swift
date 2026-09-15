import LanaCore
import LanaDesign
import SwiftUI

/// La pestaña Compartido: lista de listas compartidas, alta y detalle
/// (Fase 8). Sin lógica propia — refleja `SharedListModel`
/// (Docs/ARCHITECTURE.md).
public struct SharedListView: View {
    @Environment(\.lana) private var lana
    private let model: SharedListModel
    @State private var createModel: CreateSharedListModel?
    @State private var listPendingDelete: SharedList?

    public init(model: SharedListModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.lists.isEmpty, !model.isLoading {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "Sin listas compartidas",
                        message: "Crea una para llevar la cuenta de gastos con alguien más.",
                        actionTitle: "Crear lista",
                        action: { createModel = model.makeCreateModel() })
                } else {
                    ScrollView {
                        VStack(spacing: Space.sm.rawValue) {
                            ForEach(model.lists) { list in
                                NavigationLink(value: list.id) {
                                    SharedListRow(list: list)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Borrar", role: .destructive) {
                                        listPendingDelete = list
                                    }
                                }
                            }
                        }
                        .padding(Space.md.rawValue)
                    }
                }
            }
            .background(lana.bg)
            .navigationTitle("Compartido")
            .navigationDestination(for: SharedListID.self) { listID in
                if let list = model.lists.first(where: { $0.id == listID }) {
                    SharedListDetailView(model: model.makeDetailModel(for: list))
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createModel = model.makeCreateModel()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $createModel) { createModel in
                CreateSharedListView(model: createModel, onDone: {
                    self.createModel = nil
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

private struct SharedListRow: View {
    @Environment(\.lana) private var lana
    let list: SharedList

    var body: some View {
        LanaCard {
            HStack(spacing: Space.sm.rawValue) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(lana.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .lanaFont(.body)
                        .foregroundStyle(lana.ink)
                    Text(list.participants.map(\.displayName).joined(separator: ", "))
                        .lanaFont(.caption)
                        .foregroundStyle(lana.ink50)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(lana.ink50.opacity(0.6))
            }
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        SharedListView(model: SharedListModel(
            sharedListStore: InMemorySharedListStore(seed: [
                SharedList(
                    name: "Depa",
                    participants: [Participant(displayName: "Tú"), Participant(displayName: "Sam")],
                    defaultSplit: .equally(among: []))
            ]),
            expenseStore: InMemoryExpenseStore(),
            parser: InMemoryExpenseParsing()))
            .lanaTheme(theme)
    }
}
