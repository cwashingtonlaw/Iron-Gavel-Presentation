import SwiftUI

/// Interactive in-app trial-readiness pre-flight.
struct ChecklistView: View {
    let onClose: () -> Void
    @State private var checked: Set<Int> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(TrialChecklist.sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            Button {
                                toggle(item.id)
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                                    Image(systemName: checked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(checked.contains(item.id) ? Color.green : .secondary)
                                    Text(item.text)
                                        .foregroundStyle(.primary)
                                        .strikethrough(checked.contains(item.id))
                                }
                            }
                            .accessibilityIdentifier("checklist.item.\(item.id)")
                        }
                    }
                }
            }
            .navigationTitle("Trial Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose).accessibilityIdentifier("checklist.done")
                }
            }
        }
    }

    private func toggle(_ id: Int) {
        if checked.contains(id) { checked.remove(id) } else { checked.insert(id) }
    }
}
