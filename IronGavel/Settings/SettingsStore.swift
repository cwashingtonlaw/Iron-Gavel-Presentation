import Foundation
import Observation

/// Persisted user preferences. UserDefaults-backed (injectable for tests) and
/// @Observable so views react. Property observers write through on change; init
/// reads without writing (didSet does not fire during initialization).
@MainActor
@Observable
final class SettingsStore {
    enum JuryBackground: String, CaseIterable, Hashable {
        case black, white
    }

    @ObservationIgnored private let defaults: UserDefaults

    var defaultAnnotationColor: AnnotationColor {
        didSet { defaults.set(defaultAnnotationColor.rawValue, forKey: K.color) }
    }
    var highlightOpacity: Double {
        didSet { defaults.set(highlightOpacity, forKey: K.opacity) }
    }
    var freehandPenWidth: Double {
        didSet { defaults.set(freehandPenWidth, forKey: K.pen) }
    }
    var juryBackground: JuryBackground {
        didSet { defaults.set(juryBackground.rawValue, forKey: K.juryBg) }
    }
    var juryShowExhibitBanner: Bool {
        didSet { defaults.set(juryShowExhibitBanner, forKey: K.juryBanner) }
    }
    var showExhibitStickers: Bool {
        didSet { defaults.set(showExhibitStickers, forKey: K.stickers) }
    }
    var confirmationPromptsEnabled: Bool {
        didSet { defaults.set(confirmationPromptsEnabled, forKey: K.confirm) }
    }
    var largeText: Bool {
        didSet { defaults.set(largeText, forKey: K.largeText) }
    }
    var autoBlankOnDowngrade: Bool {
        didSet { defaults.set(autoBlankOnDowngrade, forKey: K.autoBlank) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultAnnotationColor = AnnotationColor(rawValue: defaults.string(forKey: K.color) ?? "") ?? .yellow
        self.highlightOpacity = defaults.object(forKey: K.opacity) as? Double ?? 0.4
        self.freehandPenWidth = defaults.object(forKey: K.pen) as? Double ?? 4
        self.juryBackground = JuryBackground(rawValue: defaults.string(forKey: K.juryBg) ?? "") ?? .black
        self.juryShowExhibitBanner = defaults.object(forKey: K.juryBanner) as? Bool ?? false
        self.showExhibitStickers = defaults.object(forKey: K.stickers) as? Bool ?? true
        self.confirmationPromptsEnabled = defaults.object(forKey: K.confirm) as? Bool ?? true
        self.largeText = defaults.object(forKey: K.largeText) as? Bool ?? false
        self.autoBlankOnDowngrade = defaults.object(forKey: K.autoBlank) as? Bool ?? true
    }

    private enum K {
        static let color = "iron-gavel.settings.defaultColor"
        static let opacity = "iron-gavel.settings.highlightOpacity"
        static let pen = "iron-gavel.settings.freehandPenWidth"
        static let juryBg = "iron-gavel.settings.juryBackground"
        static let juryBanner = "iron-gavel.settings.juryBanner"
        static let stickers = "iron-gavel.settings.showExhibitStickers"
        static let confirm = "iron-gavel.settings.confirmations"
        static let largeText = "iron-gavel.settings.largeText"
        static let autoBlank = "iron-gavel.settings.autoBlank"
    }
}
