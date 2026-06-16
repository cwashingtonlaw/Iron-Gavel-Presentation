import XCTest
@testable import IronGavel

final class ThemeChecklistTests: XCTestCase {
    func test_status_color_is_total_over_all_statuses() {
        let colors = ExhibitStatus.allCases.map { Theme.statusColor($0) }
        XCTAssertEqual(colors.count, ExhibitStatus.allCases.count)
    }

    func test_checklist_has_sections_each_nonempty() {
        XCTAssertFalse(TrialChecklist.sections.isEmpty)
        for section in TrialChecklist.sections {
            XCTAssertFalse(section.items.isEmpty, "section \(section.title) has items")
        }
    }

    func test_checklist_item_ids_are_unique() {
        let ids = TrialChecklist.allItems.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "item ids are unique")
        XCTAssertGreaterThan(TrialChecklist.allItems.count, 10)
    }

    func test_checklist_section_ids_are_unique() {
        let ids = TrialChecklist.sections.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
