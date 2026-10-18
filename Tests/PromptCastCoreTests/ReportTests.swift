import Foundation
import Testing

@testable import PromptCastCore

private let display = Display(x: 0, y: 0, width: 1000, height: 500, scale: 2)

private func click(_ time: Double, _ button: String = "left") -> Click {
    Click(time: time, x: 1, y: 1, button: button)
}

private func session(clicks: [Click], videoOffset: Double = 0, startedAt: Date = Date(timeIntervalSince1970: 0))
    -> Session
{
    Session(startedAt: startedAt, videoOffset: videoOffset, display: display, clicks: clicks)
}

/// Everything after the Start screenshot: the transcript, the clicks and the End section.
private func body(_ markdown: String) throws -> String {
    try #require(markdown.components(separatedBy: "![start](start.png)\n\n").last)
}

@Test func frameTimesSitBeforeAndAfterTheClickInVideoTime() {
    let t = Report.frameTimes(for: click(5), videoOffset: 0.5, videoDuration: 20)
    #expect(abs(t.before - 4.35) < 1e-9, "the before frame is 0.15 s ahead of the click, shifted by the video offset")
    #expect(abs(t.after - 5.5) < 1e-9, "the after frame is 1 s past the click, shifted by the video offset")
}

@Test func frameTimesClampToVideo() {
    let t = Report.frameTimes(for: click(0.1), videoOffset: 0.05, videoDuration: 0.5)
    #expect(t.before == 0, "a before frame ahead of the video start clamps to 0")
    #expect(abs(t.after - 0.45) < 1e-9, "an after frame past the end clamps to 0.05 s before the end")
}

@Test func frameTimesOfAVideoShorterThanTheMarginAreZero() {
    let t = Report.frameTimes(for: click(5), videoOffset: 0, videoDuration: 0.04)
    #expect(t.before == 0, "a video shorter than 0.05 s has only frame 0")
    #expect(t.after == 0, "a video shorter than 0.05 s has only frame 0")
}

@Test func markdownSplitsTranscriptAtClicksListedByTimeNumberedInRecordedOrder() throws {
    let s = session(clicks: [click(2, "left"), click(1, "right")])
    let segments = [
        Segment(start: 3, end: 3.5, text: " broken."), Segment(start: 1.5, end: 1.8, text: " then"),
        Segment(start: 0, end: 0.5, text: "Open"), Segment(start: 1, end: 1.2, text: " exactly"),
        Segment(start: 0.5, end: 0.9, text: " this,"),
    ]
    #expect(
        try body(Report.markdown(session: s, segments: segments)) == """
            Open this,

            **Click 2** at 00:01.0, right button

            ![before](clicks/002-before.png) ![after](clicks/002-after.png)

            exactly then

            **Click 1** at 00:02.0, left button

            ![before](clicks/001-before.png) ![after](clicks/001-after.png)

            broken.

            **End**

            ![end](end.png)

            """,
        "speech is sorted by start; a segment starting at a click's time belongs after that click")
}

@Test func markdownAddsNoParagraphBetweenClicksWithoutSpeech() throws {
    let s = session(clicks: [click(1), click(2)])
    let segments = [Segment(start: 0, end: 0.5, text: "Before"), Segment(start: 3, end: 3.5, text: "After")]
    let md = try body(Report.markdown(session: s, segments: segments))
    #expect(
        md.contains(
            "![before](clicks/001-before.png) ![after](clicks/001-after.png)\n\n**Click 2** at 00:02.0, left button\n"),
        "two clicks without speech between them follow each other directly")
}

@Test func markdownPrintsClickTimeInAudioTimeDespiteVideoOffset() throws {
    let s = session(clicks: [click(61.5)], videoOffset: 0.5)
    let md = try body(Report.markdown(session: s, segments: []))
    #expect(md.hasPrefix("**Click 1** at 01:01.5, left button\n"), "the click time is not shifted by the video offset")
}

@Test func markdownOpensWithTitleExplanationAndStartScreenshot() {
    let s = session(clicks: [], startedAt: Date(timeIntervalSince1970: 1_000_000_000))
    let md = Report.markdown(session: s, segments: [])
    #expect(
        md.hasPrefix("# PromptCast recording 2001-09-09T01:46:40Z\n\nNarrated screen recording."),
        "the title carries the ISO date of the start")
    #expect(md.contains("with a screenshot just before (red ring = click position) and 1.0s after. "), "after delay")
    #expect(md.contains("**Start**\n\n![start](start.png)\n"), "the Start screenshot follows the explanation")
}

@Test func markdownWithoutClicksIsOneParagraph() throws {
    let segments = [Segment(start: 0, end: 0.5, text: " Hello"), Segment(start: 0.5, end: 1, text: " world.")]
    #expect(
        try body(Report.markdown(session: session(clicks: []), segments: segments)) == """
            Hello world.

            **End**

            ![end](end.png)

            """,
        "the whole transcript sits between the Start screenshot and End")
}

@Test func timestampCarriesRoundedSecondsIntoTheMinute() {
    #expect(Report.timestamp(59.96) == "01:00.0", "59.96 s rounds to a full minute, not to 00:60.0")
    #expect(Report.timestamp(3599.99) == "60:00.0", "rounding carries into the minutes at every minute")
}

@Test func timestampShowsMinutesSecondsAndTenths() {
    #expect(Report.timestamp(61) == "01:01.0", "61 s is one minute and one second")
    #expect(Report.timestamp(75.3) == "01:15.3", "seconds past the first few and tenths follow the minute")
}

@Test func timestampOfNegativeTimeIsZero() {
    #expect(Report.timestamp(-3) == "00:00.0", "negative times read as zero")
}
