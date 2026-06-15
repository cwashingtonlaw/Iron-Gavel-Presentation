import XCTest
@testable import IronGavel

final class ContractVersionTests: XCTestCase {
    func test_supported_version_is_one_point_zero() {
        XCTAssertEqual(ContractVersion.supported, "1.0")
    }

    func test_party_decodes_from_lowercase_json_values() throws {
        let json = #"["Defense","State","Joint","Court"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([Party].self, from: json)
        XCTAssertEqual(decoded, [.defense, .state, .joint, .court])
    }

    func test_exhibit_status_decodes_all_cases() throws {
        let json = #"["pending","offered","objected","admitted","excluded"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([ExhibitStatus].self, from: json)
        XCTAssertEqual(decoded, [.pending, .offered, .objected, .admitted, .excluded])
    }

    func test_media_type_decodes_all_cases() throws {
        let json = #"["pdf","image","video","unknown"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([MediaType].self, from: json)
        XCTAssertEqual(decoded, [.pdf, .image, .video, .unknown])
    }
}
