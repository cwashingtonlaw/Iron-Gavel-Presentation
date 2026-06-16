import XCTest
@testable import IronGavel

final class CaseLoaderTests: XCTestCase {
    private func fixtureFolderURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let jsonURL = try XCTUnwrap(bundle.url(forResource: "exhibits", withExtension: "json"))
        return jsonURL.deletingLastPathComponent()
    }

    func test_loads_fixture_case_successfully() throws {
        let loader = CaseLoader()
        let kase = try loader.load(folderURL: try fixtureFolderURL())
        XCTAssertEqual(kase.contractVersion, "1.0")
        XCTAssertEqual(kase.exhibits.count, 2)
    }

    func test_missing_sidecar_throws() {
        let loader = CaseLoader()
        let bogus = URL(fileURLWithPath: "/tmp/iron-gavel-nonexistent-\(UUID().uuidString)")
        XCTAssertThrowsError(try loader.load(folderURL: bogus)) { err in
            guard case CaseLoadError.missingSidecar = err else {
                return XCTFail("expected .missingSidecar, got \(err)")
            }
        }
    }
}

extension CaseLoaderTests {
    private func resourceFolder(named name: String) throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: nil))
        return url
    }

    func test_unsupported_contract_version_throws() throws {
        let loader = CaseLoader()
        let folder = try resourceFolder(named: "BadVersion")
        XCTAssertThrowsError(try loader.load(folderURL: folder)) { err in
            guard case let CaseLoadError.unsupportedContractVersion(found, supported) = err else {
                return XCTFail("expected .unsupportedContractVersion, got \(err)")
            }
            XCTAssertEqual(found, "2.0")
            XCTAssertEqual(supported, "1.0")
        }
    }

    func test_bad_json_throws_decode_failed() throws {
        let loader = CaseLoader()
        let folder = try resourceFolder(named: "BadJSON")
        XCTAssertThrowsError(try loader.load(folderURL: folder)) { err in
            guard case CaseLoadError.decodeFailed = err else {
                return XCTFail("expected .decodeFailed, got \(err)")
            }
        }
    }

    func test_loads_from_trial_subfolder_when_root_absent() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("igtrial-\(UUID().uuidString)")
        let trial = tmp.appendingPathComponent("Trial")
        try FileManager.default.createDirectory(at: trial, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let json = #"{"contract_version":"1.0","case":{"caption":"X","docket":"Y","court":"Z"},"generated":"t","path_base":"p","exhibits":[]}"#
        try json.data(using: .utf8)!.write(to: trial.appendingPathComponent("exhibits.json"))

        let kase = try CaseLoader().load(folderURL: tmp)
        XCTAssertEqual(kase.exhibits.count, 0)
    }
}
