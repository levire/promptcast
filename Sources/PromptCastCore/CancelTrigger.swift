/// Decides what a press of the cancel key does. In double-press mode only a second press within `maxInterval` of the
/// first one cancels.
public struct CancelTrigger: Sendable {
    public enum Outcome: Sendable, Equatable {
        case cancel
        case pressAgain
    }

    public static let maxInterval = 1.0

    private let twice: Bool
    private var lastPress: Double?

    public init(twice: Bool) {
        self.twice = twice
    }

    /// Returns what a press at `time`, in seconds, does.
    public mutating func press(at time: Double) -> Outcome {
        if !twice { return .cancel }
        if let lastPress, time - lastPress <= Self.maxInterval { return .cancel }
        lastPress = time
        return .pressAgain
    }
}
