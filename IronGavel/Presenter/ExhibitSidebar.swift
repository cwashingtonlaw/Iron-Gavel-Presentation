import SwiftUI

struct ExhibitSidebar: View {
    @Environment(AppState.self) private var state
    @State private var searchText = ""
    @State private var grouping: SidebarGrouping = .party
    @State private var sort: ExhibitSort = .custom

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
                    // Drag-reorder only makes sense in Custom sort; the others are derived.
                    .onMove(perform: sort == .custom ? { from, to in
                        CaseController(state: state).reorder(section: section.exhibits, from: from, to: to)
                    } : nil)
                } header: {
                    Text(section.title.uppercased())
                        .font(Theme.Typography.sectionLabel)
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.accentDeep)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) { sortBar }
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

    private var sortBar: some View {
        @Bindable var state = state
        return Picker("Sort", selection: $sort) {
            ForEach(ExhibitSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
        .accessibilityIdentifier("sidebar.sort")
    }

    @ViewBuilder
    private func row(for exhibit: Exhibit) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            thumbnail(for: exhibit)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs + 1) {
                Text(exhibit.description)
                    .font(Theme.Typography.itemTitle)
                    .lineLimit(2)
                if let witness = exhibit.witness, !witness.isEmpty {
                    Label(witness, systemImage: "person")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.mutedText)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                ExhibitNumberChip(number: exhibit.displayNumber)
                HStack(spacing: Theme.Spacing.xs) {
                    if exhibit.isKey {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.Palette.accent)
                            .accessibilityIdentifier("exhibit.keyglyph.\(exhibit.id)")
                    }
                    StatusBadge(status: exhibit.status)
                }
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
        ExhibitGrouping.sections(for: filtered, mode: grouping, sort: sort)
    }

    @ViewBuilder
    private func thumbnail(for exhibit: Exhibit) -> some View {
        Group {
            if let folder = state.caseFolderURL,
               let img = ThumbnailProvider.shared.thumbnail(
                    for: folder.appendingPathComponent(exhibit.file), mediaType: exhibit.mediaType) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: mediaGlyph(exhibit.mediaType))
                    .font(.title3)
                    .foregroundStyle(Theme.Palette.mutedText)
            }
        }
        .frame(width: 42, height: 54)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.Palette.hairline, lineWidth: 0.75))
        .accessibilityHidden(true)
    }

    private func mediaGlyph(_ type: MediaType) -> String {
        switch type {
        case .pdf:     return "doc.text"
        case .image:   return "photo"
        case .video:   return "play.rectangle"
        case .audio:   return "waveform"
        case .unknown: return "doc"
        }
    }
}
