import Carbon.HIToolbox
import ScreenInkCore
import Speech
import SwiftUI

/// Settings window content. Add new settings as rows in a section, or as a new section.
struct SettingsView: View {
    @AppStorage(Preferences.localeKey) private var locale = ""
    @State private var locales: [String] = []

    var body: some View {
        Form {
            Section("Recording") {
                LabeledContent("Start / stop shortcut") { ShortcutRecorder() }
            }
            Section("Transcription") {
                Picker("Language", selection: $locale) {
                    Text("System default").tag("")
                    ForEach(locales, id: \.self) { id in
                        Text(Locale.current.localizedString(forIdentifier: id) ?? id).tag(id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
        .task {
            locales = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
                .sorted {
                    (Locale.current.localizedString(forIdentifier: $0) ?? $0)
                        < (Locale.current.localizedString(forIdentifier: $1) ?? $1)
                }
        }
    }
}

/// Click, then press a key combination or tap a single modifier key. Esc cancels.
private struct ShortcutRecorder: View {
    @State private var shortcut = Preferences.shortcut
    @State private var monitor: Any?
    @State private var message: String?
    @State private var tap = ModifierTap()

    var body: some View {
        HStack {
            if let message { Text(message).foregroundStyle(.secondary).font(.callout) }
            Button(monitor == nil ? shortcut.label : "Press shortcut…") {
                monitor == nil ? start() : stop()
            }
            .monospaced()
        }
        .onDisappear { if monitor != nil { stop() } }
    }

    private func start() {
        message = nil
        Hotkey.unregister()
        tap = ModifierTap()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            MainActor.assumeIsolated { handle(event) }
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let flags = UInt64(event.modifierFlags.rawValue)
            if let keyCode = tap.flagsChanged(keyCode: Int(event.keyCode), flags: flags, time: event.timestamp),
                let candidate = Shortcut.modifierOnly(keyCode: keyCode)
            {
                save(candidate)
            }
            return
        }
        tap.interrupt()
        if event.keyCode == kVK_Escape {
            stop()
            return
        }
        let candidate = Shortcut(
            keyCode: Int(event.keyCode), modifiers: Self.carbonModifiers(event.modifierFlags), key: Self.keyName(event))
        guard candidate.isValid else {
            message = "Include ⌃, ⌥ or ⌘, or tap one modifier alone"
            return
        }
        save(candidate)
    }

    private func save(_ candidate: Shortcut) {
        stop()
        message = Hotkey.use(candidate)
        if message == nil { shortcut = candidate }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        Hotkey.register(Preferences.shortcut)
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        [
            (NSEvent.ModifierFlags.control, Shortcut.control), (.option, Shortcut.option), (.shift, Shortcut.shift),
            (.command, Shortcut.command),
        ]
        .filter { flags.contains($0.0) }.reduce(0) { $0 | $1.1 }
    }

    private static func keyName(_ event: NSEvent) -> String {
        let names = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_LeftArrow: "←",
            kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_F1: "F1", kVK_F2: "F2",
            kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        return names[Int(event.keyCode)] ?? event.charactersIgnoringModifiers?.uppercased() ?? "?"
    }
}
