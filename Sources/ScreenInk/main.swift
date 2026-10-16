import AppKit
import Carbon.HIToolbox
import ScreenInkCore
import SwiftUI

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
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum State {
        case idle
        case recording(Recorder)
        case busy
    }

    static let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: "ScreenInk")
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var state = State.idle
    private var lastReport: URL?
    private lazy var overlay = Overlay { [weak self] in self?.toggle() }
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.title = "◎"
        let menu = NSMenu()
        menu.addItem(withTitle: "Start / Stop", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(withTitle: "Open Last Report", action: #selector(openLast), keyEquivalent: "")
        menu.addItem(withTitle: "Open Recordings Folder", action: #selector(openRoot), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? nil : self }
        menu.delegate = self
        item.menu = menu
        Hotkey.action = { [weak self] in self?.toggle() }
        Hotkey.register(Hotkey.saved)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.first?.title = "Start / Stop  (\(Hotkey.saved.label))"
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
                try? FileManager.default.removeItem(at: dir)
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

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "ScreenInk Settings"
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

/// System-wide shortcut. Key combinations use Carbon hotkeys, which need no permission. A modifier key on its own
/// uses a listen-only event tap, which needs Input Monitoring permission.
@MainActor
enum Hotkey {
    static var action: (() -> Void)?
    private static var ref: EventHotKeyRef?
    private static var handlerInstalled = false
    private static var tap: CFMachPort?
    private static var tapSource: CFRunLoopSource?
    private static var tapState = ModifierTap()
    private static var tapKeyCode = 0

    static var saved: Shortcut {
        UserDefaults.standard.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
            ?? .standard
    }

    /// Registers and saves `shortcut`. On failure keeps the previous one and returns why.
    static func use(_ shortcut: Shortcut) -> String? {
        unregister()
        if let problem = register(shortcut) {
            register(saved)
            return problem
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut")
        return nil
    }

    /// Returns why the shortcut could not be registered, or nil.
    @discardableResult
    static func register(_ shortcut: Shortcut) -> String? {
        let problem = shortcut.isModifierOnly ? registerTap(shortcut) : registerCarbon(shortcut)
        if let problem { log.error("\(problem, privacy: .public)") }
        return problem
    }

    static func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
    }

    private static func registerCarbon(_ shortcut: Shortcut) -> String? {
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, _ in
                    MainActor.assumeIsolated { Hotkey.action?() }
                    return noErr
                }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode), UInt32(shortcut.modifiers), EventHotKeyID(signature: 0x5349_4E4B, id: 1),
            GetApplicationEventTarget(), 0, &ref)
        return status == noErr ? nil : "\(shortcut.label) is used by another app"
    }

    private static func registerTap(_ shortcut: Shortcut) -> String? {
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        // macOS applies a new Input Monitoring grant only after the app relaunches.
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask,
                callback: { _, type, event, _ in
                    MainActor.assumeIsolated { Hotkey.handle(type, event) }
                    return Unmanaged.passUnretained(event)
                }, userInfo: nil)
        else {
            CGRequestListenEventAccess()
            return "Allow ScreenInk in Privacy & Security > Input Monitoring, then quit and reopen ScreenInk"
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        tapSource = source
        tapKeyCode = shortcut.keyCode
        tapState = ModifierTap()
        return nil
    }

    private static func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .flagsChanged:
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let tapped = tapState.flagsChanged(
                keyCode: keyCode, flags: event.flags.rawValue, time: ProcessInfo.processInfo.systemUptime)
            if tapped == tapKeyCode { action?() }
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        default:
            tapState.interrupt()
        }
    }
}
