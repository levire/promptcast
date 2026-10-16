import Foundation
import PromptCastCore

/// Every persisted preference, so each key is spelled once. SwiftUI views bind with `@AppStorage(Preferences.…Key)`.
enum Preferences {
    static let localeKey = "locale"
    static let shortcutKey = "shortcut"

    /// BCP 47 transcription language, or empty for the system language.
    static var locale: String {
        UserDefaults.standard.string(forKey: localeKey) ?? ""
    }

    static var shortcut: Shortcut {
        get {
            UserDefaults.standard.data(forKey: shortcutKey)
                .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .standard
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: shortcutKey) }
    }
}
