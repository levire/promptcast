import AppKit
import Carbon.HIToolbox
import ScreenInkCore

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

    /// Registers and saves `shortcut`. On failure keeps the previous one and returns why.
    static func use(_ shortcut: Shortcut) -> String? {
        unregister()
        if let problem = register(shortcut) {
            register(Preferences.shortcut)
            return problem
        }
        Preferences.shortcut = shortcut
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
