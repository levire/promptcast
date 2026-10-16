import Testing

@testable import PromptCastCore

private let secondary = Display(x: -800, y: 100, width: 800, height: 600, scale: 2)

@Test func pixelScalesTheHorizontalOffset() throws {
    let display = Display(x: 0, y: 0, width: 1000, height: 500, scale: 2)
    let p = try #require(display.pixel(x: 100, y: 350))
    #expect(p.x == 200, "x is the distance from the left edge times the scale")
}

@Test func pixelFlipsAndScalesTheVerticalOffset() throws {
    let display = Display(x: 0, y: 0, width: 1000, height: 500, scale: 2)
    let p = try #require(display.pixel(x: 100, y: 350))
    #expect(p.y == 300, "y is the distance from the top edge times the scale")
}

@Test func pixelOffsetsBySecondaryDisplayOrigin() throws {
    let p = try #require(secondary.pixel(x: -700, y: 650))
    #expect(p.x == 200, "x is measured from the display's left edge")
    #expect(p.y == 100, "y is measured from the display's top edge")
}

@Test func pixelIncludesTheOriginCorner() throws {
    let p = try #require(secondary.pixel(x: -800, y: 100), "the bottom-left corner is on the display")
    #expect(p.x == 0, "the left edge is pixel column 0")
    #expect(p.y == 1200, "the bottom edge is the last pixel row")
}

@Test func pixelRejectsPointsLeftOfTheDisplay() {
    #expect(secondary.pixel(x: -800.5, y: 300) == nil, "a point left of the display is off it")
}

@Test func pixelRejectsPointsOnTheRightEdge() {
    #expect(secondary.pixel(x: 0, y: 300) == nil, "the right edge belongs to the next display")
}

@Test func pixelRejectsPointsBelowTheDisplay() {
    #expect(secondary.pixel(x: -400, y: 99.5) == nil, "a point below the display is off it")
}

@Test func pixelRejectsPointsOnTheTopEdge() {
    #expect(secondary.pixel(x: -400, y: 700) == nil, "the top edge belongs to the display above")
}
