import Foundation

struct TrialChecklistItem: Identifiable, Hashable {
    let id: Int
    let text: String
}

struct TrialChecklistSection: Identifiable, Hashable {
    let id: Int
    let title: String
    let items: [TrialChecklistItem]
}

/// In-app pre-flight, mirroring docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md.
enum TrialChecklist {
    static let sections: [TrialChecklistSection] = {
        let raw: [(String, [String])] = [
            ("Setup", [
                "Mac connected to project iPad via USB-C.",
                "External HDMI display connected to the iPad.",
                "Iron Gavel built and installed on the iPad.",
                "Target case folder fully downloaded in iCloud Drive on the iPad.",
                "Trial/exhibits.json exists and was regenerated within the last 24h.",
                "Open Case and select the case's Trial/ folder.",
            ]),
            ("Publish & Jury", [
                "Sidebar shows every exhibit grouped by party with correct status badges.",
                "Each exhibit preview renders without File missing.",
                "Publishing an admitted exhibit lights the jury display with the same content.",
                "Page navigation on the presenter mirrors to the jury display.",
                "Blank Screen blacks out the jury; toggling off restores the prior exhibit.",
                "Confidence monitor shows what the jury sees in real time.",
            ]),
            ("Annotation & Zoom", [
                "Highlight / redact / callout / freehand appear on both displays in real time.",
                "Undo and Clear behave on both displays.",
                "Save Copy writes a flattened PDF under Trial/Annotated/.",
                "Zoom to Region zooms the jury and Reset Zoom returns to full view.",
            ]),
            ("Video", [
                "A video exhibit plays on the presenter and mirrors to the jury in sync.",
                "Set In / Set Out / Play Clip plays only the marked segment.",
                "Paused-frame markup mirrors and Save Copy bakes it into a PDF.",
                "Volume / mute control affects the jury audio.",
            ]),
        ]
        var sectionId = 0
        var itemId = 0
        return raw.map { title, items in
            sectionId += 1
            let built = items.map { text -> TrialChecklistItem in
                itemId += 1
                return TrialChecklistItem(id: itemId, text: text)
            }
            return TrialChecklistSection(id: sectionId, title: title, items: built)
        }
    }()

    static var allItems: [TrialChecklistItem] { sections.flatMap(\.items) }
}
