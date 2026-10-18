import Carbon.HIToolbox
import PromptCastCore
import Speech
import SwiftUI

/// Settings window content. Add new settings as rows in a section, or as a new section.
struct SettingsView: View {
    @AppStorage(Preferences.localeKey) private var locale = ""
    @AppStorage(Preferences.cancelTwiceKey) private var cancelTwice = Preferences.defaultCancelTwice
    @State private var locales: [String] = []

    var body: some View {
        Form {
            Section("Recording") {
                LabeledContent("Start / stop shortcut") {
                    ShortcutRecorder(
                        shortcut: Preferences.shortcut, isValid: \.isValid,
                        invalidHint: "Include ⌃, ⌥ or ⌘, or tap one modifier alone", save: Hotkey.use)
                }
                LabeledContent("Cancel key") {
                    ShortcutRecorder(
                        shortcut: Preferences.cancelKey, isValid: \.isValidCancelKey,
                        invalidHint: "Use Esc, an F key, or include ⌃, ⌥ or ⌘",
                        save: {
                            Preferences.cancelKey = $0
                            return nil
                        })
                }
                Picker("Cancel with", selection: $cancelTwice) {
                    Text("Double press").tag(true)
                    Text("Single press").tag(false)
                }
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

/// Click, then press a key combination or tap a single modifier key. Esc stops recording when it is not a valid
/// shortcut. `save` returns why a shortcut cannot be used, or nil.
private struct ShortcutRecorder: View {
    let isValid: (Shortcut) -> Bool
    let invalidHint: String
    let save: (Shortcut) -> String?
    @State private var shortcut: Shortcut
    @State private var monitor: Any?
    @State private var message: String?
    @State private var tap = ModifierTap()

    init(
        shortcut: Shortcut, isValid: @escaping (Shortcut) -> Bool, invalidHint: String,
        save: @escaping (Shortcut) -> String?
    ) {
        self.isValid = isValid
        self.invalidHint = invalidHint
        self.save = save
        _shortcut = State(initialValue: shortcut)
    }

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

    // The start/stop hotkey is off while recording, so pressing it here does not start a recording.
    private func start() {
        message = nil
        Hotkey.unregister()
        tap = ModifierTap()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            MainActor.assumeIsolated { record(event) }
            return nil
        }
    }

    private func record(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let flags = UInt64(event.modifierFlags.rawValue)
            if let keyCode = tap.flagsChanged(keyCode: Int(event.keyCode), flags: flags, time: event.timestamp),
                let candidate = Shortcut.modifierOnly(keyCode: keyCode)
            {
                use(candidate)
            }
            return
        }
        tap.interrupt()
        use(Shortcut(event: event))
    }

    private func use(_ candidate: Shortcut) {
        guard isValid(candidate) else {
            if candidate.keyCode == kVK_Escape { stop() } else { message = invalidHint }
            return
        }
        stop()
        message = save(candidate)
        if message == nil { shortcut = candidate }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        Hotkey.register(Preferences.shortcut)
    }
}
