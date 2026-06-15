import SwiftUI

struct ExhibitSidebar: View {
    @Environment(AppState.self) private var state

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
                    Section(party.rawValue) {
                        ForEach(items) { exhibit in
                            row(for: exhibit)
                                .tag(exhibit.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("exhibit.sidebar")
    }

    @ViewBuilder
    private func row(for exhibit: Exhibit) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(exhibit.id).font(.system(.body, design: .monospaced))
            VStack(alignment: .leading, spacing: 2) {
                Text(exhibit.description).lineLimit(2)
                if let witness = exhibit.witness, !witness.isEmpty {
                    Text(witness).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusBadge(status: exhibit.status)
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("exhibit.row.\(exhibit.id)")
    }

    private func exhibits(for party: Party) -> [Exhibit] {
        state.currentCase?.exhibits.filter { $0.party == party } ?? []
    }
}
