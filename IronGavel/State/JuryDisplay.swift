import Foundation

enum JuryDisplay: Equatable {
    case empty
    case blank
    case exhibit(Exhibit, page: Int, annotationsVersion: Int)

    var currentExhibit: Exhibit? {
        if case let .exhibit(e, _, _) = self { return e }
        return nil
    }

    var currentPage: Int? {
        if case let .exhibit(_, page, _) = self { return page }
        return nil
    }

    var annotationsVersion: Int? {
        if case let .exhibit(_, _, v) = self { return v }
        return nil
    }
}
