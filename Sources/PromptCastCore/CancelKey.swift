/// Represents a key that can cancel a recording, by its virtual key code.
public enum CancelKey: Int, CaseIterable, Sendable {
    case escape = 53
    case f1 = 122
    case f2 = 120
    case f3 = 99
    case f4 = 118
    case f5 = 96
    case f6 = 97
    case f7 = 98
    case f8 = 100
    case f9 = 101
    case f10 = 109
    case f11 = 103
    case f12 = 111

    public var label: String {
        self == .escape ? "Esc" : String(describing: self).uppercased()
    }
}
