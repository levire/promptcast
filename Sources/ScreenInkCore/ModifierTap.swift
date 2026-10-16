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
