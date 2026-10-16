import Foundation

public enum Report {
    /// How far before and after a click the screenshots are taken.
    public static let beforeLead = 0.15
    public static let afterDelay = 1.0

    public static func imageName(click index: Int, phase: String) -> String {
        String(format: "clicks/%03d-%@.png", index + 1, phase)
    }

    /// Video timestamps for the before/after frames of a click, clamped to the video's length.
    public static func frameTimes(for click: Click, videoOffset: Double, videoDuration: Double) -> (
        before: Double, after: Double
    ) {
        let t = click.time - videoOffset
        let clamp = { (v: Double) in min(max(v, 0), max(videoDuration - 0.05, 0)) }
        return (clamp(t - beforeLead), clamp(t + afterDelay))
    }

    /// Markdown with the transcript split into paragraphs at each click, each click followed by its screenshots.
    /// Segment texts carry their own spacing, as SpeechTranscriber runs do.
    public static func markdown(session: Session, segments: [Segment]) -> String {
        var out = """
            # ScreenInk recording \(session.startedAt.formatted(.iso8601))

            Narrated screen recording. The transcript is in spoken order; each **Click** marks where the user \
            clicked, with a screenshot just before (red ring = click position) and \(afterDelay)s after. \
            `start.png` and `end.png` show the screen when recording started and stopped.
            Full recording: `video.mov`, audio: `audio.m4a`, raw timings: `session.json`, `transcript.json`.

            **Start**

            ![start](start.png)


            """
        var text = ""
        func flush() {
            let paragraph = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty { out += paragraph + "\n\n" }
            text = ""
        }

        var pending = segments.sorted { $0.start < $1.start }[...]
        for (i, click) in session.clicks.enumerated().sorted(by: { $0.element.time < $1.element.time }) {
            while let s = pending.first, s.start < click.time {
                text += s.text
                pending = pending.dropFirst()
            }
            flush()
            out += "**Click \(i + 1)** at \(timestamp(click.time)), \(click.button) button\n\n"
            out += "![before](\(imageName(click: i, phase: "before"))) "
            out += "![after](\(imageName(click: i, phase: "after")))\n\n"
        }
        text += pending.map(\.text).joined()
        flush()
        return out + "**End**\n\n![end](end.png)\n"
    }

    public static func timestamp(_ seconds: Double) -> String {
        let s = max(seconds, 0)
        return String(format: "%02d:%04.1f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }
}
