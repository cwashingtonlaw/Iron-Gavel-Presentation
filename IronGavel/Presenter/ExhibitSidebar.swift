import SwiftUI

struct ExhibitSidebar: View {
    @Environment(AppState.self) private var state
    @State private var searchText = ""
    @State private var grouping: SidebarGrouping = .party

    var body: some View {
        @Bindable var state = state

        List(selection: Binding(
            get: { state.selectedExhibit?.id },
            set: { id in
                if let id, let kase = state.currentCase,
                   let exhibit = kase.exhibits.first(where: { $0.id == id }) {
                    state.select(exhibit)
                }
            }
        )) {
            if !keyExhibits.isEmpty {
                Section {
                    ForEach(keyExhibits) { exhibit in
                        row(for: exhibit).tag(exhibit.id)
                    }
                } header: {
                    Label("Key", systemImage: "star.fill")
                        .font(Theme.Typography.sectionLabel)
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.accentDeep)
                }
                .accessibilityIdentifier("sidebar.section.key")
            }

            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.exhibits) { exhibit in
                        row(for: exhibit).tag(exhibit.id)
                    }
                    .onMove { from, to in
                        CaseController(state: state).reorder(section: section.exhibits, from: from, to: to)
                    }
                } header: {
                    Text(section.title.uppercased())
                        .font(Theme.Typography.sectionLabel)
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.accentDeep)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search id, witness, Bates…")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Group by", selection: $grouping) {
                    ForEach(SidebarGrouping.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("sidebar.grouping")
            }
        }
        .accessibilityIdentifier("exhibit.sidebar")
    }

    @ViewBuilder
    private func row(for exhibit: Exhibit) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
            HStack(spacing: Theme.Spacing.s) {
                ExhibitNumberChip(number: exhibit.displayNumber)
                if exhibit.isKey {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityIdentifier("exhibit.keyglyph.\(exhibit.id)")
                }
                Spacer(minLength: Theme.Spacing.s)
                StatusBadge(status: exhibit.status)
            }
            Text(exhibit.description)
                .font(Theme.Typography.itemTitle)
                .lineLimit(2)
            if let witness = exhibit.witness, !witness.isEmpty {
                Label(witness, systemImage: "person")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.mutedText)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityIdentifier("exhibit.row.\(exhibit.id)")
        .swipeActions(edge: .leading) {
            Button {
                CaseController(state: state).toggleKey(exhibit.id)
            } label: {
                Label(exhibit.isKey ? "Unkey" : "Mark Key", systemImage: "star")
            }
            .tint(Theme.Palette.accent)
            .accessibilityIdentifier("exhibit.markkey.\(exhibit.id)")
        }
    }

    private var filtered: [Exhibit] {
        (state.currentCase?.exhibits ?? []).filter { ExhibitFilter.matches($0, query: searchText) }
    }

    private var keyExhibits: [Exhibit] { filtered.filter { $0.isKey } }

    private var sections: [ExhibitGrouping.Section] {
        ExhibitGrouping.sections(for: filtered, mode: grouping)
    }
}
