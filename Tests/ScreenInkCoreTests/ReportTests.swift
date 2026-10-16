import Foundation
import Testing

@testable import ScreenInkCore

private let display = Display(x: 0, y: 0, width: 1000, height: 500, scale: 2)

@Test func pixelFlipsYAndScales() throws {
    let p = try #require(display.pixel(x: 100, y: 400))
    #expect(p.x == 200 && p.y == 200)
    #expect(display.pixel(x: 1000, y: 10) == nil)
}

@Test func pixelHandlesSecondaryDisplayOffset() throws {
    let left = Display(x: -800, y: 100, width: 800, height: 600, scale: 1)
    let p = try #require(left.pixel(x: -700, y: 650))
    #expect(p.x == 100 && p.y == 50)
}

@Test func frameTimesClampToVideo() {
    let t = Report.frameTimes(for: Click(time: 0.1, x: 0, y: 0, button: "left"), videoOffset: 0.05, videoDuration: 0.5)
    #expect(t.before == 0)
    #expect(t.after == 0.45)
}

@Test func markdownSplitsTranscriptAtClicks() throws {
    let session = Session(
        startedAt: Date(timeIntervalSince1970: 0), videoOffset: 0, display: display,
        clicks: [Click(time: 2, x: 1, y: 1, button: "left"), Click(time: 1, x: 1, y: 1, button: "right")])
    let segments = [
        Segment(start: 0, end: 0.5, text: "Open"), Segment(start: 0.5, end: 0.9, text: " this,"),
        Segment(start: 1.5, end: 1.8, text: " then"), Segment(start: 3, end: 3.5, text: " broken."),
    ]
    let md = Report.markdown(session: session, segments: segments)
    let body = try #require(md.components(separatedBy: "![start](start.png)\n\n").last)
    #expect(
        body == """
            Open this,

            **Click 2** at 00:01.0, right button

            ![before](clicks/002-before.png) ![after](clicks/002-after.png)

            then

            **Click 1** at 00:02.0, left button

            ![before](clicks/001-before.png) ![after](clicks/001-after.png)

            broken.

            **End**

            ![end](end.png)

            """)
}
