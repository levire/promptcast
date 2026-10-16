import Foundation

/// Raw capture written to `session.json` when a recording stops. All times are seconds since the audio started.
public struct Session: Codable, Sendable, Equatable {
    public var startedAt: Date
    /// Seconds after audio start at which the first video frame was recorded.
    public var videoOffset: Double
    public var display: Display
    public var clicks: [Click]

    public init(startedAt: Date, videoOffset: Double, display: Display, clicks: [Click]) {
        self.startedAt = startedAt
        self.videoOffset = videoOffset
        self.display = display
        self.clicks = clicks
    }
}
