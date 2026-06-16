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
                Section {
                    if cases.isEmpty {
                        Text("No cases yet. Tap ＋ to create one.")
                            .font(Theme.Typography.meta)
                            .foregroundStyle(Theme.Palette.mutedText)
                    }
                    ForEach(cases, id: \.self) { name in
                        Button { onOpen(store.url(for: name)) } label: {
                            Label {
                                Text(name).font(Theme.Typography.caseTitle).foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "folder.fill").foregroundStyle(Theme.Palette.accent)
                            }
                        }
                        .accessibilityIdentifier("case.row.\(name)")
                    }
                    .onDelete { offsets in
                        for i in offsets { try? store.delete(name: cases[i]) }
                        reload()
                    }
                } header: {
                    Text("CASES ON THIS IPAD")
                        .font(Theme.Typography.sectionLabel).tracking(1.0)
                        .foregroundStyle(Theme.Palette.accentDeep)
                }
                Section {
                    Button { onOpenExternal() } label: {
                        Label("Open from Files…", systemImage: "folder")
                    }
                    .accessibilityIdentifier("case.openExternal")
                }
            }
            .navigationTitle("Iron Gavel")
            .tint(Theme.Palette.accent)
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
