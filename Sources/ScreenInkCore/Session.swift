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

/// The recorded display, in Cocoa global coordinates (points, origin bottom-left of the primary screen).
public struct Display: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var scale: Double

    public init(x: Double, y: Double, width: Double, height: Double, scale: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.scale = scale
    }

    /// Converts a global Cocoa point to top-left-origin pixel coordinates in the recorded image, or nil if off this display.
    public func pixel(x px: Double, y py: Double) -> (x: Double, y: Double)? {
        guard px >= x, px < x + width, py >= y, py < y + height else { return nil }
        return ((px - x) * scale, (y + height - py) * scale)
    }
}

public struct Click: Codable, Sendable, Equatable {
    public var time: Double
    public var x: Double
    public var y: Double
    public var button: String

    public init(time: Double, x: Double, y: Double, button: String) {
        self.time = time
        self.x = x
        self.y = y
        self.button = button
    }
}

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
