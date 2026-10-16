import AppKit
import SwiftUI

/// Floating status pill at the bottom of the screen; clicking it while recording calls `onStop`.
/// Recorder excludes this app's windows from capture.
@MainActor
final class Overlay {
    enum Phase {
        case recording(since: Date, level: () -> Float)
        case processing
        case done
    }

    private let model = OverlayModel()
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 44), styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered, defer: false)

    init(onStop: @escaping () -> Void) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.sharingType = .none
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = FirstClickHostingView(rootView: OverlayView(model: model, onStop: onStop))
    }

    func show(_ phase: Phase) {
        model.phase = phase
        if case .recording = phase {
            panel.ignoresMouseEvents = false
        } else {
            panel.ignoresMouseEvents = true
        }
        if case .recording = phase,
            let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
        {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.minY + 16))
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

/// Delivers the first click to SwiftUI while another app is active.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
@Observable
private final class OverlayModel {
    var phase = Overlay.Phase.processing
}

private struct OverlayView: View {
    let model: OverlayModel
    let onStop: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .recording(let since, let level):
                TimelineView(.periodic(from: .now, by: 1.0 / 20)) { context in
                    let value = CGFloat(level())
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: hovering ? 2 : 5).fill(.red).frame(width: 10, height: 10)
                        HStack(spacing: 3) {
                            ForEach([0.5, 0.8, 1, 0.7, 0.4], id: \.self) { k in
                                Capsule().fill(.white).frame(width: 3, height: 4 + 18 * value * k)
                            }
                        }
                        .frame(height: 22)
                        .animation(.linear(duration: 0.05), value: value)
                        Text(
                            Duration.seconds(context.date.timeIntervalSince(since)).formatted(
                                .time(pattern: .minuteSecond))
                        )
                        .monospacedDigit()
                    }
                }
            case .processing:
                ProgressView().controlSize(.small).tint(.white)
                Text("Processing…")
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Report path copied")
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(.black.opacity(0.85), in: Capsule())
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .onTapGesture {
            if case .recording = model.phase { onStop() }
        }
        .help("Stop recording")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
