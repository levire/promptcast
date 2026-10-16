import AVFoundation
import PromptCastCore
import Speech
import UniformTypeIdentifiers

/// Turns a recording folder (`session.json`, `video.mov`, `audio.m4a`) into `report.md` with click screenshots.
enum Packager {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static func run(dir: URL) async throws -> URL {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(Session.self, from: Data(contentsOf: dir.appending(path: "session.json")))

        async let transcript = transcribeOrNote(dir.appending(path: "audio.m4a"))
        try await extractScreenshots(session: session, video: dir.appending(path: "video.mov"), into: dir)
        let segments = await transcript

        try encoder.encode(segments).write(to: dir.appending(path: "transcript.json"))
        let report = dir.appending(path: "report.md")
        try Report.markdown(session: session, segments: segments).write(to: report, atomically: true, encoding: .utf8)
        return report
    }

    /// A failed transcription still yields a report, with the error in place of the transcript.
    private static func transcribeOrNote(_ audio: URL) async -> [Segment] {
        do {
            return try await transcribe(audio)
        } catch {
            return [Segment(start: 0, end: 0, text: "[Transcription failed: \(error.localizedDescription)]")]
        }
    }

    /// On-device transcription with per-word timings, in the Settings language or else the system locale.
    static func transcribe(_ audio: URL) async throws -> [Segment] {
        let wanted = Preferences.locale.isEmpty ? Locale.current : Locale(identifier: Preferences.locale)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) else {
            throw PromptCastError(
                "Transcription does not support \(wanted.identifier). Choose another language in PromptCast Settings.")
        }
        let transcriber = SpeechTranscriber(
            locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
        if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await install.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let collect = Task {
            var segments: [Segment] = []
            for try await result in transcriber.results {
                for run in result.text.runs {
                    let range = run.audioTimeRange
                    let start = range?.start.seconds ?? segments.last?.end ?? 0
                    let end = range?.end.seconds ?? start
                    segments.append(Segment(start: start, end: end, text: String(result.text[run.range].characters)))
                }
            }
            return segments
        }
        if let last = try await analyzer.analyzeSequence(from: AVAudioFile(forReading: audio)) {
            try await analyzer.finalizeAndFinish(through: last)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collect.value
    }

    private static func extractScreenshots(session: Session, video: URL, into dir: URL) async throws {
        try FileManager.default.createDirectory(at: dir.appending(path: "clicks"), withIntermediateDirectories: true)
        let asset = AVURLAsset(url: video)
        let duration = try await asset.load(.duration).seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let last = CMTime(seconds: max(duration - 0.05, 0), preferredTimescale: 600)
        try writePNG(try await generator.image(at: .zero).image, to: dir.appending(path: "start.png"))
        try writePNG(try await generator.image(at: last).image, to: dir.appending(path: "end.png"))

        for (i, click) in session.clicks.enumerated() {
            let times = Report.frameTimes(for: click, videoOffset: session.videoOffset, videoDuration: duration)
            let before = try await generator.image(at: CMTime(seconds: times.before, preferredTimescale: 600)).image
            let after = try await generator.image(at: CMTime(seconds: times.after, preferredTimescale: 600)).image
            let ring = session.display.pixel(x: click.x, y: click.y)
            try writePNG(
                ring.map { mark(before, at: $0, display: session.display) } ?? before,
                to: dir.appending(path: Report.imageName(click: i, phase: "before")))
            try writePNG(after, to: dir.appending(path: Report.imageName(click: i, phase: "after")))
        }
    }

    /// Draws a red ring at a top-left-origin pixel point given in display pixels.
    private static func mark(_ image: CGImage, at point: (x: Double, y: Double), display: Display) -> CGImage {
        let w = Double(image.width)
        let h = Double(image.height)
        let k = w / (display.width * display.scale)
        guard
            let ctx = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let r = 22 * display.scale * k
        ctx.setStrokeColor(red: 1, green: 0.1, blue: 0.1, alpha: 0.9)
        ctx.setLineWidth(4 * display.scale * k)
        ctx.strokeEllipse(in: CGRect(x: point.x * k - r, y: h - point.y * k - r, width: 2 * r, height: 2 * r))
        return ctx.makeImage() ?? image
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw PromptCastError.cannotWrite(url)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw PromptCastError.cannotWrite(url) }
    }
}
