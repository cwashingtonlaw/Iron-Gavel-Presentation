import SwiftUI

/// Identifiable wrapper so a case-folder URL can drive a `.sheet(item:)`.
private struct BackupTarget: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// Launch surface: list on-device cases, create a new one, or open an external folder.
struct CaseLibraryView: View {
    let onOpen: (URL) -> Void
    let onOpenExternal: () -> Void

    @State private var cases: [String] = []
    @State private var showNew = false
    @State private var newName = ""
    @State private var backupTarget: BackupTarget?
    @State private var showRestore = false
    @State private var toast: String?
    private let store = CaseStore()
    private let backup = CaseBackup()

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
                        .swipeActions(edge: .leading) {
                            Button {
                                backupTarget = BackupTarget(url: store.url(for: name))
                            } label: {
                                Label("Back Up", systemImage: "arrow.up.doc")
                            }
                            .tint(Theme.Palette.accent)
                            .accessibilityIdentifier("case.backup.\(name)")
                        }
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
                    Button { showRestore = true } label: {
                        Label("Restore Backup from Files…", systemImage: "arrow.down.doc")
                    }
                    .accessibilityIdentifier("case.restore")
                } footer: {
                    if let toast { Text(toast).foregroundStyle(Theme.Palette.accentDeep) }
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
            .sheet(item: $backupTarget) { target in
                ExportPicker(url: target.url) { ok in
                    backupTarget = nil
                    toast = ok ? "Backup exported." : nil
                }
            }
            .sheet(isPresented: $showRestore) {
                FolderPicker { folder in
                    showRestore = false
                    restore(from: folder)
                }
            }
        }
    }

    private func reload() { cases = store.list() }

    private func restore(from folder: URL) {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        do {
            let dest = try backup.restore(from: folder, to: store.root)
            reload()
            toast = "Restored “\(dest.lastPathComponent)”."
        } catch {
            toast = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        guard let folder = try? store.create(name: name, now: now) else { return }
        reload()
        onOpen(folder)
    }
}
