import SwiftUI

struct PopupSettingsTab: View {
    let onTestPopup: () -> Void

    private typealias Key = AppSettings.Key
    private static let defaults = OverlayAppearance()

    @AppStorage(Key.overlayDimOpacity) private var dimOpacity = defaults.dimOpacity
    @AppStorage(Key.overlayCardSize) private var cardSize = defaults.cardSize
    @AppStorage(Key.overlaySound) private var sound = defaults.soundName

    private let soundNames = SystemSound.names

    var body: some View {
        Form {
            Slider(value: $dimOpacity, in: 0.2...0.95) {
                Text("Background dimming")
            }
            Picker("Card size", selection: $cardSize) {
                ForEach(OverlayCardSize.allCases) { size in
                    Text(size.rawValue.capitalized).tag(size)
                }
            }
            Picker("Sound", selection: $sound) {
                Text("None").tag("")
                ForEach(soundNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .onChange(of: sound) { _, name in SystemSound.play(name) }
            Button("Test popup", action: onTestPopup)
        }
        .formStyle(.grouped)
    }
}
