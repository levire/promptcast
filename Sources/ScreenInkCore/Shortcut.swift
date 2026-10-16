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

/// Detects a solo tap of one modifier key: pressed and released within `maxHold`, with nothing else in between.
public struct ModifierTap: Sendable {
    public static let maxHold = 0.5

    /// Device-dependent bits of the event modifier flags, which tell left and right keys apart.
    static let masks: [Int: UInt64] = [
        55: 0x8, 54: 0x10, 58: 0x20, 61: 0x40, 59: 0x1, 62: 0x2000, 56: 0x2, 60: 0x4, 63: 0x80_0000,
    ]

    private var pending: (keyCode: Int, time: Double)?

    public init() {}

    /// Feeds a flags-changed event. Returns the key code when it completes a solo tap.
    public mutating func flagsChanged(keyCode: Int, flags: UInt64, time: Double) -> Int? {
        guard let mask = Self.masks[keyCode] else {
            pending = nil
            return nil
        }
        if flags & mask != 0 {
            let othersHeld = Self.masks.contains { $0.key != keyCode && flags & $0.value != 0 }
            pending = othersHeld ? nil : (keyCode, time)
            return nil
        }
        defer { pending = nil }
        guard let pending, pending.keyCode == keyCode, time - pending.time <= Self.maxHold else { return nil }
        return keyCode
    }

    /// Any key press or click while a modifier is held cancels the tap.
    public mutating func interrupt() {
        pending = nil
    }
}
