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
    @State private var folder: String
    @State private var notes: String

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
        _folder = State(initialValue: exhibit.folder ?? "")
        _notes = State(initialValue: exhibit.notes ?? "")
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
                    TextField("Folder (witness or topic)", text: $folder)
                        .accessibilityIdentifier("editor.folder")
                }
                Section {
                    TextField("Presenter notes (only you see these)", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("editor.notes")
                } header: {
                    Text("Presenter Notes")
                } footer: {
                    Text("Private to you during examination — never shown to the jury.")
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
        let trimmedFolder = folder.trimmingCharacters(in: .whitespaces)
        return Exhibit(id: exhibit.id, party: party, description: descriptionText, file: exhibit.file,
                witness: witness.isEmpty ? nil : witness,
                bates: bates.isEmpty ? nil : bates,
                status: status, mediaType: exhibit.mediaType,
                objection: exhibit.objection, ruling: exhibit.ruling,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                exhibitNumber: number.trimmingCharacters(in: .whitespaces).isEmpty ? nil
                    : number.trimmingCharacters(in: .whitespaces),
                isKey: exhibit.isKey,
                folder: trimmedFolder.isEmpty ? nil : trimmedFolder)
    }
}
