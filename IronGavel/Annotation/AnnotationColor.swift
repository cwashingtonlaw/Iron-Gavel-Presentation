import SwiftUI

enum AnnotationColor: String, Codable, CaseIterable, Hashable {
    case yellow
    case orange
    case red
    case blue
    case green

    var hex: String {
        switch self {
        case .yellow: return "#FFD60AFF"
        case .orange: return "#FF9F0AFF"
        case .red:    return "#FF453AFF"
        case .blue:   return "#0A84FFFF"
        case .green:  return "#30D158FF"
        }
    }

    init?(hex: String) {
        let match = AnnotationColor.allCases.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
        guard let match else { return nil }
        self = match
    }

    var uiColor: Color {
        switch self {
        case .yellow: return Color(red: 1.00, green: 0.84, blue: 0.04)
        case .orange: return Color(red: 1.00, green: 0.62, blue: 0.04)
        case .red:    return Color(red: 1.00, green: 0.27, blue: 0.23)
        case .blue:   return Color(red: 0.04, green: 0.52, blue: 1.00)
        case .green:  return Color(red: 0.19, green: 0.82, blue: 0.35)
        }
    }
}
