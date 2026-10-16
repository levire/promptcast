import AVFoundation
import AppKit
import ScreenCaptureKit
import ScreenInkCore
import os

let log = Logger(subsystem: "dev.screenink", category: "app")

/// Records the display under the mouse to `video.mov`, the microphone to `audio.m4a`, and mouse clicks into `session.json`.
@MainActor
final class Recorder: NSObject, SCRecordingOutputDelegate {
    let dir: URL
    private var stream: SCStream?
    private var recording: SCRecordingOutput?
    private var audio: AVAudioRecorder?
    private var monitor: Any?
    private var startedAt = Date()
    private var audioStart: TimeInterval = 0
    private var videoStart: TimeInterval?
    private var display = Display(x: 0, y: 0, width: 0, height: 0, scale: 1)
    private var clicks: [Click] = []
    private var finished: CheckedContinuation<Void, Error>?

    init(dir: URL) {
        self.dir = dir
    }

    func start() async throws {
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw ScreenInkError("Microphone access denied. Enable it in System Settings > Privacy & Security.")
        }
        // macOS applies a new Screen Recording grant only after the app relaunches.
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenInkError(
                "Turn on ScreenInk in System Settings > Privacy & Security > Screen & System Audio Recording, "
                    + "then quit ScreenInk from the menu bar and open it again.")
        }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main,
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { throw ScreenInkError("No display found.") }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenInkError(
                "Display not shareable. Grant Screen Recording in System Settings > Privacy & Security.")
        }

        let frame = screen.frame
        let scale = screen.backingScaleFactor
        display = Display(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height, scale: scale)

        let config = SCStreamConfiguration()
        config.width = Int(frame.width * scale)
        config.height = Int(frame.height * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = true
        // Excluding this app keeps the overlay out of the video and screenshots. Off-screen windows are
        // included in the query so the app is listed before the overlay first appears.
        let ownApp = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: scDisplay, excludingApplications: ownApp, exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let output = SCRecordingOutputConfiguration()
        output.outputURL = dir.appending(path: "video.mov")
        output.outputFileType = .mov
        let recording = SCRecordingOutput(configuration: output, delegate: self)
        try stream.addRecordingOutput(recording)

        let audio = try AVAudioRecorder(
            url: dir.appending(path: "audio.m4a"),
            settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1])
        try await stream.startCapture()
        audio.isMeteringEnabled = true
        audio.record()
        startedAt = Date()
        audioStart = ProcessInfo.processInfo.systemUptime
        self.stream = stream
        self.recording = recording
        self.audio = audio
        log.info("Recording started in \(self.dir.path, privacy: .public)")

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) {
            [weak self] event in
            // Global monitor events have no window, so locationInWindow is in screen coordinates.
            let click = Click(
                time: event.timestamp - (self?.audioStart ?? 0), x: event.locationInWindow.x,
                y: event.locationInWindow.y,
                button: event.type == .leftMouseDown ? "left" : event.type == .rightMouseDown ? "right" : "other")
            MainActor.assumeIsolated { self?.clicks.append(click) }
        }
    }

    /// Microphone loudness in 0...1, for the overlay.
    var level: Float {
        guard let audio else { return 0 }
        audio.updateMeters()
        return max(0, min(1, (audio.averagePower(forChannel: 0) + 50) / 50))
    }

    func stop() async throws {
        if let monitor { NSEvent.removeMonitor(monitor) }
        audio?.stop()
        if let stream, let recording {
            // Removing the output finalizes video.mov; stopCapture alone does not reliably report completion.
            try await withCheckedThrowingContinuation { continuation in
                finished = continuation
                do {
                    try stream.removeRecordingOutput(recording)
                } catch {
                    finish(error)
                }
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    if self.finished != nil { log.error("No recording-finished callback after 5s, continuing") }
                    self.finish(nil)
                }
            }
            try? await stream.stopCapture()
        }
        log.info("Recording stopped, \(self.clicks.count) clicks")
        let session = Session(
            startedAt: startedAt, videoOffset: (videoStart ?? audioStart) - audioStart, display: display, clicks: clicks
        )
        try Packager.encoder.encode(session).write(to: dir.appending(path: "session.json"))
    }

    private func finish(_ error: Error?) {
        guard let finished else { return }
        self.finished = nil
        if let error { finished.resume(throwing: error) } else { finished.resume() }
    }

    // ponytail: start callback time approximates the first frame's time (tens of ms); use the first sample PTS if screenshots drift.
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        let now = ProcessInfo.processInfo.systemUptime
        Task { @MainActor in self.videoStart = now }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        log.error("Recording failed: \(error.localizedDescription, privacy: .public)")
        Task { @MainActor in self.finish(error) }
    }
}

struct ScreenInkError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
