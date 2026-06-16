import SwiftUI

/// Edit one exhibit's metadata and status in-app. The status field here is the live
/// status the publish gate honors.
struct ExhibitEditorSheet: View {
    let exhibit: Exhibit
    let onSave: (Exhibit) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var number: String
    @State private var party: Party
    @State private var status: ExhibitStatus
    @State private var descriptionText: String
    @State private var witness: String
    @State private var bates: String

    init(exhibit: Exhibit, onSave: @escaping (Exhibit) -> Void,
         onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.exhibit = exhibit
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _number = State(initialValue: exhibit.exhibitNumber ?? "")
        _party = State(initialValue: exhibit.party)
        _status = State(initialValue: exhibit.status)
        _descriptionText = State(initialValue: exhibit.description)
        _witness = State(initialValue: exhibit.witness ?? "")
        _bates = State(initialValue: exhibit.bates ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identification") {
                    TextField("Exhibit number (e.g. D-1)", text: $number)
                        .accessibilityIdentifier("editor.number")
                    Picker("Party", selection: $party) {
                        ForEach(Party.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(ExhibitStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .accessibilityIdentifier("editor.status")
                }
                Section("Details") {
                    TextField("Description", text: $descriptionText)
                    TextField("Witness", text: $witness)
                    TextField("Bates", text: $bates)
                }
                Section {
                    Button("Delete Exhibit", role: .destructive, action: onDelete)
                        .accessibilityIdentifier("editor.delete")
                }
            }
            .navigationTitle("Edit Exhibit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(updated()) }.accessibilityIdentifier("editor.save")
                }
            }
        }
    }

    private func updated() -> Exhibit {
        Exhibit(id: exhibit.id, party: party, description: descriptionText, file: exhibit.file,
                witness: witness.isEmpty ? nil : witness,
                bates: bates.isEmpty ? nil : bates,
                status: status, mediaType: exhibit.mediaType,
                objection: exhibit.objection, ruling: exhibit.ruling, notes: exhibit.notes,
                exhibitNumber: number.trimmingCharacters(in: .whitespaces).isEmpty ? nil
                    : number.trimmingCharacters(in: .whitespaces))
    }
}
