/// A transcribed word or phrase, timed in seconds since the audio started.
public struct Segment: Codable, Sendable, Equatable {
    public var start: Double
    public var end: Double
    public var text: String

    public init(start: Double, end: Double, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}
