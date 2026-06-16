import SwiftUI

/// Quick form to log an objection/ruling disposition for an exhibit during trial.
struct DispositionSheet: View {
    let exhibitId: String
    let onSave: (_ objection: String, _ ruling: String, _ note: String) -> Void
    let onCancel: () -> Void

    @State private var objection = ""
    @State private var ruling = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exhibit") { Text(exhibitId).font(.headline) }
                Section("Objection") {
                    TextField("e.g. Hearsay", text: $objection)
                        .accessibilityIdentifier("disposition.objection")
                }
                Section("Ruling") {
                    TextField("e.g. Overruled / Sustained", text: $ruling)
                        .accessibilityIdentifier("disposition.ruling")
                }
                Section("Note") {
                    TextField("optional", text: $note)
                        .accessibilityIdentifier("disposition.note")
                }
            }
            .navigationTitle("Log Disposition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(objection, ruling, note) }
                        .accessibilityIdentifier("disposition.save")
                }
            }
        }
    }
}
