import AppKit

/// Represents a listen-only event tap on the main run loop, so events still reach the focused app. Needs Input
/// Monitoring permission. The tap stops when the instance is released.
@MainActor
final class EventTap {
    private let handler: (CGEventType, CGEvent) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// Returns nil and asks the user for Input Monitoring permission when the tap cannot be created.
    init?(events: [CGEventType], handler: @escaping (CGEventType, CGEvent) -> Void) {
        self.handler = handler
        let mask = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask,
                callback: { _, type, event, userInfo in
                    if let userInfo {
                        MainActor.assumeIsolated {
                            Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue().receive(type, event)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            CGRequestListenEventAccess()
            return nil
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        self.source = source
    }

    isolated deinit {
        if let tap { CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        default:
            handler(type, event)
        }
    }
}
