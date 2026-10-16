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
