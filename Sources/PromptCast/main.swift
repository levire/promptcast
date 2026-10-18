import AppKit
import Carbon.HIToolbox
import PromptCastCore
import SwiftUI

// `PromptCast --package <dir>` rebuilds a recording's report without recording, for iterating on packaging.
let args = CommandLine.arguments
if args.count == 3, args[1] == "--package" {
    do {
        print(try await Packager.run(dir: URL(filePath: args[2])).path)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum State {
        case idle
        case recording(Recorder)
        case busy
    }

    static let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: "PromptCast")
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var state = State.idle
    private var lastReport: URL?
    private lazy var overlay = Overlay(
        onStop: { [weak self] in self?.toggle() }, onCancel: { [weak self] in self?.cancel() })
    private var cancelItem: NSMenuItem?
    private var cancelTap: EventTap?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.title = "◎"
        let menu = NSMenu()
        menu.addItem(withTitle: "Start / Stop", action: #selector(toggle), keyEquivalent: "")
        cancelItem = menu.addItem(
            withTitle: "Cancel Recording", action: #selector(cancel), keyEquivalent: "")
        menu.addItem(withTitle: "Open Last Report", action: #selector(openLast), keyEquivalent: "")
        menu.addItem(withTitle: "Open Recordings Folder", action: #selector(openRoot), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? nil : self }
        menu.delegate = self
        item.menu = menu
        Hotkey.action = { [weak self] in self?.toggle() }
        Hotkey.register(Preferences.shortcut)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.first?.title = "Start / Stop  (\(Preferences.shortcut.label))"
        if case .recording = state { cancelItem?.isHidden = false } else { cancelItem?.isHidden = true }
        let key = Preferences.cancelKey.label
        cancelItem?.title = "Cancel Recording  (\(Preferences.cancelTwice ? "\(key) \(key)" : key))"
    }

    @objc func toggle() {
        Task { await toggleAsync() }
    }

    private func toggleAsync() async {
        switch state {
        case .busy:
            return
        case .idle:
            state = .busy
            let dir = Self.root.appending(path: Date().formatted(.iso8601).replacingOccurrences(of: ":", with: "-"))
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let recorder = Recorder(dir: dir)
                try await recorder.start()
                state = .recording(recorder)
                item.button?.title = "● REC"
                overlay.show(.recording(since: Date(), level: { recorder.level }))
                watchCancelKey()
            } catch {
                try? FileManager.default.removeItem(at: dir)
                fail(error)
            }
        case .recording(let recorder):
            state = .busy
            cancelTap = nil
            item.button?.title = "…"
            overlay.show(.processing)
            do {
                try await recorder.stop()
                let report = try await Packager.run(dir: recorder.dir)
                lastReport = report
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(report.path, forType: .string)
                item.button?.title = "✓ copied"
                overlay.show(.done)
                state = .idle
                try? await Task.sleep(for: .seconds(3))
                if case .idle = state {
                    item.button?.title = "◎"
                    overlay.hide()
                }
            } catch {
                fail(error)
            }
        }
    }

    /// Stops the current recording and deletes its folder without writing a report.
    @objc func cancel() {
        guard case .recording(let recorder) = state else { return }
        state = .busy
        cancelTap = nil
        Task {
            do {
                try await recorder.stop()
                try FileManager.default.removeItem(at: recorder.dir)
                log.info("Recording cancelled")
            } catch {
                log.error("Cancelling failed: \(error.localizedDescription, privacy: .public)")
            }
            state = .idle
            item.button?.title = "◎"
            overlay.hide()
        }
    }

    private func watchCancelKey() {
        let key = Preferences.cancelKey
        var trigger = CancelTrigger(twice: Preferences.cancelTwice)
        cancelTap = EventTap(events: [.keyDown]) { [weak self] _, event in
            guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
                let pressed = NSEvent(cgEvent: event).map(Shortcut.init(event:)),
                pressed.keyCode == key.keyCode, pressed.modifiers == key.modifiers
            else { return }
            switch trigger.press(at: ProcessInfo.processInfo.systemUptime) {
            case .cancel:
                self?.cancel()
            case .pressAgain:
                self?.overlay.flash("Press \(key.label) again to cancel", for: CancelTrigger.maxInterval)
            }
        }
        if cancelTap == nil { log.error("The cancel key needs Input Monitoring permission, then a relaunch") }
    }

    private func fail(_ error: Error) {
        log.error("\(error.localizedDescription, privacy: .public)")
        state = .idle
        item.button?.title = "◎"
        overlay.hide()
        let alert = NSAlert()
        if let error = error as? PromptCastError {
            alert.messageText = error.errorDescription ?? "PromptCast failed."
        } else {
            alert.messageText = "PromptCast failed. Try again."
            alert.informativeText =
                "If it keeps failing, open Console and filter for dev.promptcast.\n\n\(error.localizedDescription)"
        }
        NSApp.activate()
        alert.runModal()
    }

    @objc func openLast() {
        if let lastReport { NSWorkspace.shared.activateFileViewerSelecting([lastReport]) }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "PromptCast Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func openRoot() {
        try? FileManager.default.createDirectory(at: Self.root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.root)
    }
}
