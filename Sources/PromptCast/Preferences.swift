import Foundation
import PromptCastCore

/// Every persisted preference, so each key is spelled once. SwiftUI views bind with `@AppStorage(Preferences.…Key)`.
enum Preferences {
    static let localeKey = "locale"
    static let shortcutKey = "shortcut"
    static let cancelKeyKey = "cancelKey"
    static let cancelTwiceKey = "cancelTwice"
    static let defaultCancelTwice = true

    /// BCP 47 transcription language, or empty for the system language.
    static var locale: String {
        UserDefaults.standard.string(forKey: localeKey) ?? ""
    }

    static var cancelKey: Shortcut {
        get { decoded(cancelKeyKey) ?? .escape }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: cancelKeyKey) }
    }

    /// Whether the cancel key must be pressed twice quickly.
    static var cancelTwice: Bool {
        UserDefaults.standard.object(forKey: cancelTwiceKey) as? Bool ?? defaultCancelTwice
    }

    static var shortcut: Shortcut {
        get { decoded(shortcutKey) ?? .standard }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: shortcutKey) }
    }

    private static func decoded(_ key: String) -> Shortcut? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
    }
}
