import XCTest
@testable import IronGavel

final class AnnotationEnumsTests: XCTestCase {
    func test_contract_version_supported_is_one_point_zero() {
        XCTAssertEqual(AnnotationContractVersion.supported, "1.0")
    }

    func test_tool_decodes_lowercase_strings() throws {
        let json = #"["highlight","redact","callout","freehand"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([AnnotationTool].self, from: json)
        XCTAssertEqual(decoded, [.highlight, .redact, .callout, .freehand])
    }

    func test_color_hex_round_trips() throws {
        for c in AnnotationColor.allCases {
            XCTAssertEqual(c.hex.count, 9)
            XCTAssertEqual(c.hex.first, "#")
            let back = AnnotationColor(hex: c.hex)
            XCTAssertEqual(back, c)
        }
    }
}
