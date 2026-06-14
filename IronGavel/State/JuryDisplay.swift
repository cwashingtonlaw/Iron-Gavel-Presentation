import Foundation

enum JuryDisplay: Equatable {
    case empty
    case blank
    case exhibit(Exhibit, page: Int)

    var currentExhibit: Exhibit? {
        if case let .exhibit(e, _) = self { return e }
        return nil
    }

    var currentPage: Int? {
        if case let .exhibit(_, page) = self { return page }
        return nil
    }
}
