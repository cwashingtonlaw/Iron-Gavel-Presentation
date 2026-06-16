import SwiftUI

/// Launch surface: list on-device cases, create a new one, or open an external folder.
struct CaseLibraryView: View {
    let onOpen: (URL) -> Void
    let onOpenExternal: () -> Void

    @State private var cases: [String] = []
    @State private var showNew = false
    @State private var newName = ""
    private let store = CaseStore()

    var body: some View {
        NavigationStack {
            List {
                Section("Cases on this iPad") {
                    if cases.isEmpty {
                        Text("No cases yet. Tap + to create one.").foregroundStyle(.secondary)
                    }
                    ForEach(cases, id: \.self) { name in
                        Button(name) { onOpen(store.url(for: name)) }
                            .accessibilityIdentifier("case.row.\(name)")
                    }
                    .onDelete { offsets in
                        for i in offsets { try? store.delete(name: cases[i]) }
                        reload()
                    }
                }
                Section {
                    Button { onOpenExternal() } label: {
                        Label("Open from Files…", systemImage: "folder")
                    }
                    .accessibilityIdentifier("case.openExternal")
                }
            }
            .navigationTitle("Iron Gavel")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { newName = ""; showNew = true } label: { Image(systemName: "plus") }
                        .accessibilityIdentifier("case.new")
                }
            }
            .alert("New Case", isPresented: $showNew) {
                TextField("Case name", text: $newName).accessibilityIdentifier("case.newName")
                Button("Create", action: create)
                Button("Cancel", role: .cancel) {}
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() { cases = store.list() }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        guard let folder = try? store.create(name: name, now: now) else { return }
        reload()
        onOpen(folder)
    }
}
