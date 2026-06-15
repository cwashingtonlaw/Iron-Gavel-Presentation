import Foundation
import SwiftUI

protocol ExhibitRenderer {
    associatedtype Body: View
    func makeView(fileURL: URL, isPresenter: Bool, page: Binding<Int>) -> Body
}
