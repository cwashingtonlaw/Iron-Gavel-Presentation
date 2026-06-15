import Foundation
import Observation

@MainActor
@Observable
final class AnnotationStore {
    @ObservationIgnored var onChange: ((String) -> Void)?

    private var documents: [String: AnnotationDocument] = [:]
    private var versions: [String: [Int: Int]] = [:]

    func document(exhibitId: String) -> AnnotationDocument {
        documents[exhibitId] ?? AnnotationDocument.empty(exhibitId: exhibitId)
    }

    func annotations(exhibitId: String, page: Int) -> [Annotation] {
        documents[exhibitId]?.pages[String(page)] ?? []
    }

    func pageVersion(exhibitId: String, page: Int) -> Int {
        versions[exhibitId]?[page] ?? 0
    }

    func apply(_ document: AnnotationDocument) {
        documents[document.exhibitId] = document
        bumpAllVersions(exhibitId: document.exhibitId, in: document)
        onChange?(document.exhibitId)
    }

    func add(_ annotation: Annotation, exhibitId: String, page: Int) {
        var doc = documents[exhibitId] ?? AnnotationDocument.empty(exhibitId: exhibitId)
        let key = String(page)
        var list = doc.pages[key] ?? []

        if annotation.tool == .freehand {
            list.removeAll { $0.tool == .freehand }
        }
        list.append(annotation)

        doc.pages[key] = list
        doc.lastModified = ISO8601DateFormatter().string(from: Date())
        documents[exhibitId] = doc
        bumpVersion(exhibitId: exhibitId, page: page)
        onChange?(exhibitId)
    }

    func undo(exhibitId: String, page: Int) {
        guard var doc = documents[exhibitId] else { return }
        let key = String(page)
        guard var list = doc.pages[key], !list.isEmpty else { return }
        _ = list.removeLast()
        doc.pages[key] = list
        doc.lastModified = ISO8601DateFormatter().string(from: Date())
        documents[exhibitId] = doc
        bumpVersion(exhibitId: exhibitId, page: page)
        onChange?(exhibitId)
    }

    func clear(exhibitId: String, page: Int) {
        guard var doc = documents[exhibitId] else { return }
        doc.pages[String(page)] = []
        doc.lastModified = ISO8601DateFormatter().string(from: Date())
        documents[exhibitId] = doc
        bumpVersion(exhibitId: exhibitId, page: page)
        onChange?(exhibitId)
    }

    private func bumpVersion(exhibitId: String, page: Int) {
        var map = versions[exhibitId] ?? [:]
        map[page] = (map[page] ?? 0) + 1
        versions[exhibitId] = map
    }

    private func bumpAllVersions(exhibitId: String, in doc: AnnotationDocument) {
        var map = versions[exhibitId] ?? [:]
        for key in doc.pages.keys {
            if let page = Int(key) {
                map[page] = (map[page] ?? 0) + 1
            }
        }
        versions[exhibitId] = map
    }
}
