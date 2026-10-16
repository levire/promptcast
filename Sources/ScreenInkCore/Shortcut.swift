/// A global hotkey: a virtual key code plus Carbon modifier flags, with the key's display name.
public struct Shortcut: Codable, Sendable, Equatable {
    public static let command = 256
    public static let shift = 512
    public static let option = 2048
    public static let control = 4096

    /// ⌃⌥R (`kVK_ANSI_R` is 15).
    public static let standard = Shortcut(keyCode: 15, modifiers: control | option, key: "R")

    public var keyCode: Int
    public var modifiers: Int
    public var key: String

    public init(keyCode: Int, modifiers: Int, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    public var label: String {
        [(Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"), (Self.command, "⌘")]
            .filter { modifiers & $0.0 != 0 }.map(\.1).joined() + key
    }

    /// A key combination needs ⌃, ⌥ or ⌘ so it cannot swallow ordinary typing.
    public var isValid: Bool {
        isModifierOnly || modifiers & (Self.control | Self.option | Self.command) != 0
    }
}

extension Shortcut {
    /// Display names of modifier keys usable on their own, by virtual key code.
    static let modifierKeys: [Int: String] = [
        55: "Left ⌘", 54: "Right ⌘", 58: "Left ⌥", 61: "Right ⌥", 59: "Left ⌃", 62: "Right ⌃",
        56: "Left ⇧", 60: "Right ⇧", 63: "fn",
    ]

    /// A single modifier key, triggered by tapping it alone.
    public static func modifierOnly(keyCode: Int) -> Shortcut? {
        modifierKeys[keyCode].map { Shortcut(keyCode: keyCode, modifiers: 0, key: $0) }
    }

    public var isModifierOnly: Bool {
        modifiers == 0 && Self.modifierKeys[keyCode] != nil
    }
}
