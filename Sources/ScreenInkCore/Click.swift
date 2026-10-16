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
