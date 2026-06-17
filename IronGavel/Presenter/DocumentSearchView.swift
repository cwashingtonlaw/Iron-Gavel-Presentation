import SwiftUI
import PDFKit

struct DocumentSearchView: View {
    @Environment(AppState.self) private var state
    let onJump: (_ exhibit: Exhibit, _ page: Int) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var hits: [DocumentSearchHit] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                results
            }
            .navigationTitle("Search Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search text in PDF exhibits…", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("docsearch.field")
                .onChange(of: query) { _, _ in scheduleSearch() }
            if isSearching { ProgressView() }
        }
        .padding(12)
    }

    @ViewBuilder
    private var results: some View {
        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            placeholder("Type at least 2 characters.")
        } else if hits.isEmpty && !isSearching {
            placeholder("No matches in this case's PDF exhibits.")
        } else {
            List(hits) { hit in
                Button {
                    if let exhibit = state.currentCase?.exhibits.first(where: { $0.id == hit.exhibitId }) {
                        onJump(exhibit, hit.page)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(hit.exhibitDescription).font(.headline).lineLimit(1)
                            Spacer()
                            Text("p. \(hit.page + 1)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(hit.snippet).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .accessibilityIdentifier("docsearch.hit.\(hit.exhibitId).\(hit.page)")
            }
            .listStyle(.plain)
        }
    }

    private func placeholder(_ text: String) -> some View {
        VStack { Spacer(); Text(text).foregroundStyle(.secondary); Spacer() }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query
        let exhibits = state.currentCase?.exhibits ?? []
        guard let folder = state.caseFolderURL else { hits = []; return }
        guard q.trimmingCharacters(in: .whitespaces).count >= 2 else { hits = []; return }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // debounce
            if Task.isCancelled { return }
            let found = await Task.detached(priority: .userInitiated) {
                DocumentSearch().search(query: q, in: exhibits, caseFolder: folder) { url in
                    PDFDocument(url: url)
                }
            }.value
            if Task.isCancelled { return }
            await MainActor.run {
                self.hits = found
                self.isSearching = false
            }
        }
    }
}
