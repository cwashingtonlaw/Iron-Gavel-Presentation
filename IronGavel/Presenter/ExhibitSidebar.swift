import SwiftUI

struct ExhibitSidebar: View {
    @Environment(AppState.self) private var state
    @State private var searchText = ""

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
            ForEach(Party.allCases, id: \.self) { party in
                let items = exhibits(for: party)
                if !items.isEmpty {
                    Section {
                        ForEach(items) { exhibit in
                            row(for: exhibit)
                                .tag(exhibit.id)
                        }
                    } header: {
                        Text(party.rawValue.uppercased())
                            .font(Theme.Typography.sectionLabel)
                            .tracking(1.0)
                            .foregroundStyle(Theme.Palette.accentDeep)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search id, witness, Bates…")
        .accessibilityIdentifier("exhibit.sidebar")
    }

    @ViewBuilder
    private func row(for exhibit: Exhibit) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
            HStack(spacing: Theme.Spacing.s) {
                ExhibitNumberChip(number: exhibit.displayNumber)
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
    }

    private func exhibits(for party: Party) -> [Exhibit] {
        (state.currentCase?.exhibits ?? []).filter {
            $0.party == party && ExhibitFilter.matches($0, query: searchText)
        }
    }
}
