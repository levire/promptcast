import AppKit
import Carbon.HIToolbox

// `ScreenInk --package <dir>` rebuilds a recording's report without recording, for iterating on packaging.
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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum State {
        case idle
        case recording(Recorder)
        case busy
    }

    static let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: "ScreenInk")
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var state = State.idle
    private var lastReport: URL?
    private let overlay = Overlay()

    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.title = "◎"
        let menu = NSMenu()
        menu.addItem(withTitle: "Start / Stop  (⌃⌥R)", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(withTitle: "Open Last Report", action: #selector(openLast), keyEquivalent: "")
        menu.addItem(withTitle: "Open Recordings Folder", action: #selector(openRoot), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? nil : self }
        item.menu = menu
        Hotkey.register(keyCode: kVK_ANSI_R, modifiers: controlKey | optionKey) { [weak self] in self?.toggle() }
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
            } catch {
                fail(error)
            }
        case .recording(let recorder):
            state = .busy
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

    private func fail(_ error: Error) {
        log.error("\(error.localizedDescription, privacy: .public)")
        state = .idle
        item.button?.title = "◎"
        overlay.hide()
        let alert = NSAlert(error: error)
        NSApp.activate()
        alert.runModal()
    }

    @objc func openLast() {
        if let lastReport { NSWorkspace.shared.activateFileViewerSelecting([lastReport]) }
    }

    @objc func openRoot() {
        try? FileManager.default.createDirectory(at: Self.root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.root)
    }
}

/// System-wide hotkey via Carbon, which needs no Accessibility permission.
@MainActor
enum Hotkey {
    private static var action: (() -> Void)?
    private static var ref: EventHotKeyRef?

    static func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                MainActor.assumeIsolated { Hotkey.action?() }
                return noErr
            }, 1, &spec, nil, nil)
        RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: 0x5349_4E4B, id: 1),
            GetApplicationEventTarget(), 0,
            &ref)
    }
}
