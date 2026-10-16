import Testing

@testable import PromptCastCore

@Test func pixelFlipsYAndScales() throws {
    let display = Display(x: 0, y: 0, width: 1000, height: 500, scale: 2)
    let p = try #require(display.pixel(x: 100, y: 400))
    #expect(p.x == 200 && p.y == 200)
    #expect(display.pixel(x: 1000, y: 10) == nil)
}

@Test func pixelHandlesSecondaryDisplayOffset() throws {
    let left = Display(x: -800, y: 100, width: 800, height: 600, scale: 1)
    let p = try #require(left.pixel(x: -700, y: 650))
    #expect(p.x == 100 && p.y == 50)
}
