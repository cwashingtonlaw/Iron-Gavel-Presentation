import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Jury Display") {
                    Picker("Background", selection: $settings.juryBackground) {
                        Text("Black").tag(SettingsStore.JuryBackground.black)
                        Text("White").tag(SettingsStore.JuryBackground.white)
                    }
                    .accessibilityIdentifier("settings.juryBackground")
                    Toggle("Show exhibit caption banner", isOn: $settings.juryShowExhibitBanner)
                        .accessibilityIdentifier("settings.juryBanner")
                    Toggle("Show exhibit stickers on documents", isOn: $settings.showExhibitStickers)
                        .accessibilityIdentifier("settings.exhibitStickers")
                }

                Section("Annotation") {
                    Picker("Default color", selection: $settings.defaultAnnotationColor) {
                        ForEach(AnnotationColor.allCases, id: \.self) { color in
                            Text(color.rawValue.capitalized).tag(color)
                        }
                    }
                    .accessibilityIdentifier("settings.defaultColor")
                    VStack(alignment: .leading) {
                        Text("Highlight opacity: \(Int(settings.highlightOpacity * 100))%")
                        Slider(value: $settings.highlightOpacity, in: 0.2...0.6)
                            .accessibilityIdentifier("settings.highlightOpacity")
                    }
                    VStack(alignment: .leading) {
                        Text("Freehand pen width: \(Int(settings.freehandPenWidth))")
                        Slider(value: $settings.freehandPenWidth, in: 1...12)
                            .accessibilityIdentifier("settings.penWidth")
                    }
                }

                Section("Behavior") {
                    Toggle("Auto-blank jury when an exhibit is no longer admitted",
                           isOn: $settings.autoBlankOnDowngrade)
                        .accessibilityIdentifier("settings.autoBlank")
                    Toggle("Confirm destructive actions", isOn: $settings.confirmationPromptsEnabled)
                        .accessibilityIdentifier("settings.confirmations")
                    Toggle("Larger text", isOn: $settings.largeText)
                        .accessibilityIdentifier("settings.largeText")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose).accessibilityIdentifier("settings.done")
                }
            }
        }
    }
}
